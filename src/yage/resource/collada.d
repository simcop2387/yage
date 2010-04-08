 /**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.collada;

import tango.io.device.File;
import tango.io.FilePath;
import tango.text.Unicode : toLower;
import tango.text.Util;
import tango.text.xml.Document;
import tango.text.xml.DocTester;
import tango.util.Convert;
import yage.core.color;
import yage.core.format;
import yage.core.math.matrix;
import yage.core.math.vector;
import yage.core.object2;
import yage.resource.geometry;
import yage.resource.image;
import yage.resource.material;
import yage.resource.manager;
import yage.resource.texture;
import yage.system.log;

/**
 * Collada loads and parses collada 3d model files and can convert their contents to 
 * the data structures used by Yage. 
 * This does not yet support the full Collada specification, but has been somewhat tested
 * against Collada files from Blender and Milkshape 3D.
 * 
 * If any error occurs during parsing, an XmlException will be thrown.
 * ResourceException will be thrown on errors loading external resources.
 * 
 * See_Also:  http://khronos.org/collada
 * Example:
 * --------
 * Collada c = new Collada("someFile.dae"); 
 * Material m = c.getMaterialById("material1");
 * Geometry g = c.getMergedGeometry();
 * --------
 */
class Collada
{
	private char[] resourcePath; // Absolute path to the collada file, or empty string if created from memory.			
	private Document!(char) doc;		
	private Geometry[char[]] geometries; // indexed by id
	private Material[char[]] materials;
	private Image[char[]] images;
	private GPUTexture[char[]] textures;
	
	/**
	 * Params:
	 *     filename = path to the collada file to load */
	this(char[] filename)
	{	char[] absPath = ResourceManager.resolvePath(filename);
		char[] xml = cast(char[])File.get(absPath);
		try {
			doc = new Document!(char)();			
			doc.parse(xml);
			resourcePath = FilePath(absPath).path();
		} catch (Exception e) // TODO: Errors often don't occur until actually using the document.
		{	throw new XMLException("Could not parse collada file '%s'.", absPath);
		}
	}
	
	/**
	 * Create and parse a new Collada file.
	 * Either filename or xml must be specified, but not both.
	 * Params:
	 *     xml = Contents of a collada file.
	 *     path = Look for resources relative to this path. */
	this(char[] xml, char[] path)
	{	assert(xml.length);
		try {
			doc = new Document!(char)();			
			doc.parse(xml);
			resourcePath = FilePath(path).path();
		} catch (Exception e) // TODO: Errors often don't occur until actually using the document.
		{	throw new XMLException("Could not parse xml document.");
		}
	}
	
	/**
	 * Get all geometry from the file merged into a single Yage Geometry instance.
	 * This is usually the desired behavior when loading a collada file as a model. */
	Geometry getMergedGeometry()
	{
		Geometry[] geometries;
		Matrix[] geometryTransforms;
		
		// Loop through the scenes and load all the geometry nodes they reference.
		scope Node[] visual_scenes = Node(doc.elements).getChild("library_visual_scenes").getChildren("visual_scene");
		
		foreach (visual_scene; visual_scenes) // loop through scenes
		{
			scope Node[] nodes = visual_scene.getChildren("node");
			foreach (node; nodes) // loop through nodes in a scene
			{
				Node instance_geometry;
				try {
					instance_geometry = node.getChild("instance_geometry");
				} catch (XmlException e) {
					continue; // skip nodes that don't have geometry (lights, cameras, etc.)
				}
				
				char[] geometryId = instance_geometry.getAttribute("url"); // TODO: Multiple instance geometry?
				Geometry geometry = getGeometryById(geometryId);
				
				// Get transformation matrix for this instance of the geometry.
				Matrix matrix;
				foreach (transform; node.getChildren())
				{	if (transform.name=="translate")
						matrix.setPosition(Vec3f(Xml.parseNumberList!(float)(transform.value)));
					else if (transform.name=="rotate")
					{	float[] values = Xml.parseNumberList!(float)(transform.value);
						assert(values.length==4);
						Vec3f(values[3]*tango.math.Math.PI/180, values[0], values[1], values[2]); // load from axis-angle							
					} 
					else if (transform.name=="scale")						
						matrix.setScalePreservingRotation(Vec3f(Xml.parseNumberList!(float)(transform.value)));
				}
				geometryTransforms ~= matrix;
				
				// TODO: Sometimes intance_geometry has xml children specifying a material (or other things as well?)
				geometries~= geometry;
		}	}
		
		// Transform geometry instances by their transformation matrix
		foreach (i, geometry; geometries)
		{	Matrix m = geometryTransforms[i];
			foreach(inout Vec3f vertex; cast(Vec3f[])geometry.getAttribute(Geometry.VERTICES))
				vertex = vertex.transform(m); 
				// TODO: Transform normals by position only
		}
		
		
		// Get a maping of all types to their vertex buffer info.
		VertexBuffer[char[]] types;
		foreach (geometry; geometries)
			foreach(char[] type, vb; geometry.getVertexBuffers())
				types[type] = vb;
		
		// Perform the merge (if there's more than one)
		Geometry result = geometries[0];
		if (geometries.length > 1)
			result = Geometry.merge(geometries);			
		delete geometries;
		
		return result;
	}
	
	///
	Geometry getGeometryById(char[] id)
	{	id = Xml.makeId(id);
		
		// Check cache
		if (id in geometries)
			return geometries[id];
		
		Geometry[] meshes;
					
		Node geometryNode = Xml.getNodeById(doc, id);
		scope Node[] meshNodes = geometryNode.getChildren("mesh");
		foreach (mesh; meshNodes)
		{					
			// polyList for this mesh references material, vertices, normals, and tex coordinates by id
			Node polyList;
			if (mesh.hasChild("polylist"))
				polyList = mesh.getChild("polylist");
			else
				polyList = mesh.getChild("triangles");
			
			// Inputs are the cordinates that the triangles index into.
			struct Input
			{	float[] data;
				ushort components = 3;
				ushort offset;
				char[] name;					
			}				
			
			// Build inputs from xml
			scope Node[] inputNodes = polyList.getChildren("input");
			scope Input[] inputs = new Input[inputNodes.length];				
			foreach (i, inputNode; inputNodes)
			{					
				inputs[i].name = inputNode.getAttribute("semantic");
				try {
					inputs[i].offset = Xml.parseNumber!(int)(inputNode.getAttribute("offset"));
				} catch (ConversionException e)
				{	throw new XmlException(e.toString());
				}
				
				if (inputs[i].name=="VERTEX") // VERTEX type requires another level of indirection to get to proper node.
				{	char[] verticesId = inputNode.getAttribute("source");				
					Node verticesNode = Xml.getNodeById(doc, verticesId);
					inputNode = verticesNode.getChild("input");
				}
				
				// Get values
				char[] sourceId = inputNode.getAttribute("source"); 
				inputs[i].data = getDataFromSourceId(sourceId, inputs[i].components);					
			}				
			int[] indices = Xml.parseNumberList!(int)(polyList.getChild("p").value);
			int[] vcounts;
			if (polyList.hasChild("vcount"))
				vcounts = Xml.parseNumberList!(int)(polyList.getChild("vcount").value);
			
			// Convert inputs, indices, and vcounts into Geometry
			Geometry getPolygons(Input[] inputs, int[] indices, int[] vcounts)
			{
				Geometry result = new Geometry();
				
				// Get the number of indices per vertex
				int indicesPerVertex = 0;
				foreach (input; inputs)
					if (input.offset > indicesPerVertex)
						indicesPerVertex = input.offset;
				indicesPerVertex++;
				
				char[][char[]] translate = [
					cast(char[])"VERTEX": cast(char[])Geometry.VERTICES,
					"NORMAL": Geometry.NORMALS,
					"TEXCOORD": Geometry.TEXCOORDS0, 
					"TEXCOORD0": Geometry.TEXCOORDS0 // TODO: append set attribute for multi-texturing
				];
				
				// TODO: Exception if no vertices
				// TODO: Exception if indices isn't the correct length.
				
				// In collada's list of polygon indices, one point of a triangle may index into the vertex 
				// and normal arrays at different positions for the same point.
				// So we create new vertex/normal/etc. arrays to allow for all indices to match.
				foreach (input; inputs)
				{
					int c = input.components;
					float[] data = new float[indices.length*c/indicesPerVertex];
					for (int i=0; i<indices.length; i+=indicesPerVertex)
					{	int index = indices[i + input.offset]*c; // TODO: This creates duplicate vertices on shared triangle edges
						int j = i/indicesPerVertex*c;
						data[j..j+c] = input.data[index..index+c];
					}
					
					char[] name = translate[input.name];
					if (c==2) // TODO: bone indices will be of type int
						result.setAttribute(name, cast(Vec2f[])data);
					else if (c==3)
						result.setAttribute(name, cast(Vec3f[])data);
					else if (c==4)
						result.setAttribute(name, cast(Vec4f[])data);
					else
						assert(0);
					
					// Flip the y texture coordinate:  TODO: is this only needed for models from milkshape?
					foreach (inout texCoord; cast(Vec2f[])result.getAttribute(Geometry.TEXCOORDS0))
						texCoord.y = -texCoord.y;
						
				}
				
				// Build triangles
				Vec3i[] triangles;
				if (!vcounts.length)
				{	triangles = new Vec3i[result.getVertexBuffer(Geometry.VERTICES).length()/3];
					foreach (i, inout triangle; triangles)
						triangle = Vec3i(i*3, i*3+1, i*3+2);
				} 
				else // If n-sided polygons instead of all triangles
				{
					// Calculate size of triangles
					int size, i, j;
					foreach (vcount; vcounts)
						size+=vcount-2;
					triangles = new Vec3i[size];
					
					// Get each triangle
					foreach (vcount; vcounts)
					{	assert(3<=vcount && vcount<=4); // TODO: Some collada files have more polygons.  Do I need a tesselator?
						triangles~= Vec3i(j, j+1, j+2); // always at least one triangle;
						if (vcount>=4)
							triangles[i] = Vec3i(j, j+2, j+3);
						i+=vcount-2;
						j+=vcount;
					}
				}
				
				// Material
				Material material = getMaterialById(polyList.getAttribute("material"));
			
				
				Mesh mesh = new Mesh(null, triangles);
				mesh.material = material;
				result.meshes = [mesh];
				
				return result;
			}				
			meshes ~= getPolygons(inputs, indices, vcounts); // garbage
		}
		
		// Merge meshes into a single geometry
		Geometry result = meshes[0];
		if (meshes.length > 1)
			result = Geometry.merge(meshes); 			
		
		delete meshes;  // garbage from old mesh sub-data
		geometries[id] = result; // cache for next request			
		return result;
	}
	
	/// TODO: This isn't used
	Image getImageById(char[] id)
	{	id = Xml.makeId(id);		
		if (id in images)
			return images[id];
		
		Node imageNode = Xml.getNodeById(doc, id);
		if (imageNode.hasChild("create_2d")) // change from Collada 1.4 to 1.5
			imageNode = imageNode.getChild("create_2d");
		char[] imagePath = imageNode.getChild("init_from").value;
		auto result = new Image(ResourceManager.resolvePath(imagePath, resourcePath));
		images[id] = result;
		return result;
	}
	
	/**
	 * Get a yage GPUTexture from the Collada file by its id.
	 * This uses ResourceManager.texture internally, so subsequent calls will return an already loaded GPUTexture.
	 * 
	 * These are Yage-specific notes for loading Collada textures:
	 * <li>TODO: An image's <hint precision="_"> value determines whether texture compression is used.
	 *     LOW (or not specified at all): 8 byte channels, texture compression
	 *     MID: 8 byte channels, no compression
	 *     HIGH: 16 bit float (not supported yet)
	 *     MAX: 32 bit float (not supported yet)</li> */
	GPUTexture getTextureById(char[] id)
	{	id = Xml.makeId(id);		
		if (id in textures)
			return textures[id];
		
		char[] imageNewParamSid = Xml.getNodeById(doc, id, "sid").getChild("sampler2D").getChild("source").value;			
		char[] imageNodeId = Xml.getNodeById(doc, imageNewParamSid, "sid").getChild("surface").getChild("init_from").value;
		Node imageNode = Xml.getNodeById(doc, imageNodeId);
		
		char[] precision = "LOW";
		if (imageNode.hasChild("create_2d")) // change from Collada 1.4 to 1.5, one level deeper
		{	imageNode = imageNode.getChild("create_2d");
			if (imageNode.hasChild("hint"))
			{	Node hint = imageNode.getChild("hint");
				if (hint.hasAttribute("precision"))
					precision = hint.getAttribute("precision");
		}	}
	
		Node initFrom = imageNode.getChild("init_from");
		if (initFrom.hasChild("ref")) // new in Collada 1.5
			initFrom = initFrom.getChild("ref");
		
		char[] imagePath = initFrom.value;
		imagePath = ResourceManager.resolvePath(imagePath, resourcePath);		
		
		// Load texture
		GPUTexture.Format format = GPUTexture.Format.AUTO;
		if (precision=="MID")
			format = GPUTexture.Format.AUTO_UNCOMPRESSED;
		GPUTexture result = ResourceManager.texture(imagePath, format);
		
		textures[id] = result;
		return result;			
	}
	
	/**
	 * Get a yage material from the Collada file by its id.
	 * This uses ResourceManager.material internally, so subsequent calls will return an already loaded Material.
	 * 
	 * These are Yage-specific notes for loading Collada materials:
	 * <li>profile_COMMON is read, any other profiles are ignored.</li>
	 * <li>Trancparency opaque attributes of RGB_ONE are mapped to  MaterialPass.Blend.ADD, RGB_ZERO is mapped
	 *     to MaterialPass.Blend.MULTIPLY.  Otherwise, AVERAGE or NONE are used depending on whether any 
	 *     transparency is specified or if the material has an alpha channel.</li> */
	Material getMaterialById(char[] id)
	{	id = Xml.makeId(id);
		if (id in materials)
			return materials[id];
		
		Material result = new Material();
		result.techniques ~= new MaterialTechnique();
		result.techniques[0].passes ~= new MaterialPass();
		MaterialPass pass = result.techniques[0].passes[0];
		
		Node instanceEffect = Xml.getNodeById(doc, id).getChild("instance_effect"); // TODO: instance_effect can have child nodes that specify parameters
		Node effectNode = Xml.getNodeById(doc, instanceEffect.getAttribute("url"));
		Node profileCommon = effectNode.getChild("profile_COMMON"); // TODO: profile_GLSL
		Node technique = profileCommon.getChild("technique");
		
		Node shadingType = technique.getChild(); // in profile_COMMON, it can be newparam, image, blinn, constant, lambert, phong, or exra.
												// blinn, lambert, and phong all have the same parameters.
		
		// Loop through and get each material property
		scope Node[] params = shadingType.getChildren();
		foreach (Node param; params)
		{				
			void getColorOrTexture(Node n, inout Color color, inout GPUTexture texture)
			{	char[] name = n.name();
				switch (name)
				{	case "param":
						n = Xml.getNodeById(doc, n.getAttribute("ref"), "sid").getChild("float3");	
						// deliberate fall-through
					case "color":
						Color temp = Color(Xml.parseNumberList!(float)(n.value));
						color = Color(cast(int)temp.r, cast(int)temp.b, cast(int)temp.g, ((color.a*cast(int)temp.a)/255));
						break;
					case "texture":
						texture = getTextureById(n.getAttribute("texture")); // TODO getImageByTexture
						break;
			}	}
			
			Node child = param.getChild();				
			GPUTexture texture;
			switch(param.name())
			{
				case "ambient":
					getColorOrTexture(child, pass.ambient, texture);
					break;
				case "diffuse":
					getColorOrTexture(child, pass.diffuse, texture);
					Texture texture2 = Texture(texture);
					pass.setDiffuseTexture(texture2); // may be null
					break;
				case "specular":
					getColorOrTexture(child, pass.specular, texture);
					break;
				case "emission":
					getColorOrTexture(child, pass.emissive, texture);
					break;
				case "shininess":
					pass.shininess = Xml.parseNumber!(float)(child.value);
					break;
				case "transparent":
					if (param.hasAttribute("opaque")) // These aren't mapped exactly
					{	if (param.getAttribute("opaque") == "RGB_ONE")
							pass.blend = MaterialPass.Blend.ADD;
						else if (param.getAttribute("opaque") == "RGB_ZERO")
							pass.blend = MaterialPass.Blend.MULTIPLY;
					}
					break;
				case "transparency":
					float transparency = Xml.parseNumber!(float)(child.value);
					pass.diffuse.a = cast(ubyte)(transparency * pass.diffuse.a);
					break;
				default:
					break;
				// TODO: Get normal from extra tag, see: http://www.okino.com/conv/exp_collada_extensions.htm
			}
			
			// Enable blending if there's alpha.
			if (pass.blend==MaterialPass.Blend.NONE)
				if (pass.diffuse.a < 1f || (pass.textures.length && pass.textures[0].texture.getImage().getChannels()==4))
					pass.blend = MaterialPass.Blend.AVERAGE;
		}
		
		return result;
	}
	
	// See: https://collada.org/mediawiki/index.php/Using_accessors
	private float[] getDataFromSourceId(char[] id, out ushort components)
	{	Node sourceAccesor = Xml.getNodeById(doc, id).getChild("technique_common").getChild("accessor"); // TODO: Read stride, offset, etc.
		scope Node[] params = sourceAccesor.getChildren("param");
		components = params.length;
		char[] sourceFloatArrayId = sourceAccesor.getAttribute("source");
		char[] sourceFloatArray = Xml.getNodeById(doc, sourceFloatArrayId).value;
		return Xml.parseNumberList!(float)(sourceFloatArray);
	}
	
	// Wraps Tagno's Node to make it easier and with Exception checks
	private static struct Node
	{
		Document!(char).Node node;
		
		// Create a Node from a Tango Node
		static Node opCall(Document!(char).Node rhs)
		{	assert(rhs);
			Node result;
			result.node = rhs;
			return result;
		}			
		static Node[] opCall(Document!(char).Node[] rhs) // ditto
		{	Node[] result = new Node[rhs.length];
			foreach (i, n; result)
			{	assert(rhs[i]);
				result[i].node = rhs[i];				
			}
			return result;
		}
		
		// Expose node properties.
		char[] name()
		{	return node.name;
		}
		char[] value() // ditto
		{	return node.value;
		}
		
		// Get the child named name (or first child if no name), or throw XMLException if not found.
		Node getChild(char[] name=null)
		{	auto result = node.query.child(name).nodes;
			if (result.length)
				return Node(result[0]);
			throw new XMLException("Node '%s' doesn't have a child of type '%s'", node.name(), name);
		}
		
		// Get children that match name, or return an empty array
		Node[] getChildren(char[] name=null)
		{	return Node(node.query.child(name).nodes);
		}
		
		// Get the value of an attribute by its name, or throw XMLException if not found
		char[] getAttribute(char[] name)
		{	auto attr = node.attributes().name(null, name);
			if (attr)
				return attr.value();
			throw new XMLException("Attribute '%s' doesn't exist on node '%s'", name, node.name());
		}
		
		bool hasAttribute(char[] name)
		{	return cast(bool)(node.attributes().name(null, name));			
		}	
		
		bool hasChild(char[] name="")
		{	return (node.query.child(name).nodes.length > 0);
		}
		
	}
	
	// Xml parsing helper.
	// Wrap tango xml so any errors throw XMLException
	private static struct Xml
	{	
		// Get all nodes in the document that have the matching id.
		static Node getNodeById(Document!(char) doc, char[] id, char[] attributeName="id")
		{	assert(doc);
			id = makeId(id);
			auto result = doc.query.descendant.filter((Document!(char).Node n) {
				auto attr = n.attributes.name(null, attributeName);
				return attr && attr.value == id;
			});
			if (result.nodes.length)
				return Node(result.nodes[0]);
			throw new XMLException("The document does not have an element with %s='%s'", attributeName, id);
		}
		
		static char[] makeId(char[] id)
		{	assert(id.length);
			if (id[0]=='#' && id.length>1) // id's are sometimes prefixed with #
				id = id[1..$];
			return id;
		}
		
		static T parseNumber(T)(char[] number)
		{	try {
				return to!(T)(number);
			} catch (ConversionException e)
			{	throw new XmlException(e.toString());
			}
		}
		
		// Convert a space separated string of numbers to an array of type T.
		static T[] parseNumberList(T)(char[] list) // TODO: lookaside buffer?
		{	scope char[][] pieces = delimit(trim(list), " \r\n\t");
			T[] result = new T[pieces.length];
			try {
				foreach(i, piece; pieces)			
					result[i] = to!(T)(piece);
			} catch (ConversionException e)
			{	throw new XmlException(e.toString());
			}
			return result;
		}
	
	}
	
	/// Any Collada loading errors will throw this exception.
	static class XMLException : ResourceException
	{	///
		this(...)
		{	super(swritef(_arguments, _argptr));
		}		
	}	
}