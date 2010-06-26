 /**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.collada;

import tango.io.device.File;
import tango.io.FilePath;
import tango.math.IEEE;
import tango.text.Unicode : toLower;
import tango.text.Util;
import tango.text.xml.Document;
import tango.text.xml.DocTester;
import tango.util.Convert;

import yage.core.array;
import yage.core.color;
import yage.core.format;
import yage.core.math.matrix;
import yage.core.math.vector;
import yage.core.misc : dup;
import yage.core.object2;
import yage.core.timer;
import yage.resource.geometry;
import yage.resource.image;
import yage.resource.material;
import yage.resource.manager;
import yage.resource.model;
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
	private Texture[char[]] textures;
	
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
	 * 
	 * Params:
	 *     id = 
	 *     calledByGetMerged = 
	 *     vertexRemap = Vertex indices are changed during loading.  This is a map of their new indices back to their old ones.
	 * Returns:
	 */
	Geometry getGeometryById(char[] id)
	{	scope int[] unused;
		return getGeometryById(id, false, unused);
	}	
	Geometry getGeometryById(char[] id, bool calledByGetMerged, out int[] vertexRemap) /// ditto
	{	id = Xml.makeId(id);
		
		// Check cache
		if (id in geometries)
			return geometries[id];
		
		Geometry[] meshes;
					
		Node geometryNode = Xml.getNodeById(doc, id);
		scope Node[] meshNodes = geometryNode.getChildren("mesh");
		foreach (mesh; meshNodes)
		{	
			char[][] types = [cast(char[])"polylist", "triangles", "polygons"];
			foreach (type; types) // loop through the different names of the polygon indices
				foreach (Node polyList; mesh.getChildren(type))
				{			
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
						char[] offset = inputNode.hasAttribute("offset") ? inputNode.getAttribute("offset") : inputNode.getAttribute("idx");				
						try {
							inputs[i].offset = Xml.parseNumber!(int)(offset);
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
						inputs[i].data = getDataFromSourceId!(float)(sourceId, inputs[i].components);
					}
					int[] indices;
					foreach (p; polyList.getChildren("p"))
						indices ~= Xml.parseNumberList!(int)(p.value);
					int[] vcounts;
					if (polyList.hasChild("vcount"))
						vcounts = Xml.parseNumberList!(int)(polyList.getChild("vcount").value);
					
					// Convert inputs, indices, and vcounts into Geometry
					int[] localVertexRemap;
					Geometry result = new Geometry();
					{
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
							{	int index = indices[i + input.offset]*c; // This creates duplicate vertices on shared triangle edges; Geometry.optimize takes care of it later
								int j = i/indicesPerVertex*c;
								data[j..j+c] = input.data[index..index+c];
							}
							char[] name = translate[input.name];
							
							// Flip the y texture coordinate for OpenGL.
							if (name.length >= 16 && name[0..16]== "gl_MultiTexCoord")
								for (int i=1; i<= data.length; i+=c)
									data[i] = -data[i]; // flip y texture coordinate
							
							// Store data in result's vertex attributes							
							if (c==2)
								result.setAttribute(name, cast(Vec2f[])data);
							else if (c==3)
								result.setAttribute(name, cast(Vec3f[])data);
							else if (c==4)
								result.setAttribute(name, cast(Vec4f[])data);
							else
								assert(0);
							
							// Create vertexRemap, which is later used to remap joint indices.
							if (name==Geometry.VERTICES)   
							{	localVertexRemap.length = result.getVertexBuffer(Geometry.VERTICES).length;
								for (int i=0; i<indices.length; i+=indicesPerVertex)							
									localVertexRemap[i/indicesPerVertex] = indices[i]; // TODO: Is this correct?								
							}
						}
						
						// Ensure all vertex buffers are the same length
						{	int count = result.getVertexBuffer(Geometry.VERTICES).length;
							foreach (name, vb; result.getVertexBuffers())
								if (vb.length != count)
									throw new XMLException("Geometry attribute %s has data for %d vertices, but %d vertices exist", name, vb.length, count);
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
							bool tesselationError;
							foreach (vcount; vcounts)
							{	if (3<=vcount && vcount<=4 && !tesselationError) // TODO: Some collada files have more polygons.  Do I need a tesselator?
								{	Log.error("This model has polygons with more than four vertices, but tesselation isn't yet supported.");
									tesselationError = true;
								}
								triangles~= Vec3i(j, j+1, j+2); // always at least one triangle;
								if (vcount>=4)
									triangles[i] = Vec3i(j, j+2, j+3);
								i+=vcount-2;
								j+=vcount;
							}
						}
						
						// Material
						Material material;
						if (polyList.hasAttribute("material"))
							material = getMaterialById(polyList.getAttribute("material"));
						else
							material = Material.getDefaultMaterial();
		
						result.meshes = [new Mesh(material, triangles)];
					}
					meshes ~= result; // garbage
					vertexRemap ~= localVertexRemap;
				}
		}
		
		// Merge meshes into a single geometry
		Geometry result = meshes.length ? meshes[0] : null;
		if (meshes.length > 1)
			result = Geometry.merge(meshes);
		
		if (!calledByGetMerged)
		{	result.optimize();
		
			//If phong shading is used, generate binormals.
			foreach (mesh; result.meshes)
				if (mesh.material.getPass().autoShader == MaterialPass.AutoShader.PHONG)
				{	result.setAttribute(Geometry.TEXCOORDS1, result.createTangentVectors());
					break;
				}
		}
		
		delete meshes;  // garbage from old mesh sub-data
		geometries[id] = result; // cache for next request
		return result;
	}
	
	/**
	 * Get a yage material from the Collada file by its id.
	 * This uses ResourceManager.material internally, so subsequent calls will return an already loaded Material.
	 * 
	 * These are Yage-specific notes for loading Collada materials:
	 * <ul>
	 * <li>profile_COMMON is read, any other profiles are ignored.</li>
	 * <li>Trancparency opaque attributes of RGB_ONE are mapped to  MaterialPass.Blend.ADD, RGB_ZERO is mapped
	 *     to MaterialPass.Blend.MULTIPLY.  Otherwise, AVERAGE or NONE are used depending on whether any 
	 *     transparency is specified or if the material has an alpha channel.</li>
	 * <li>If the first child of profile_COMMON is &lt;phong&gt;, then A shader will be created to enable phong shading.
	 *     If it's &lt;lambert&gt;, then flat shading from the fixed function pipeline will be used.  Otherwise
	 *     fixed-function gourard shading will be used.</li>
	 * <li>The unofficial &lt;phong&gt;&lt;bump&gt; texture is used for a normal texture, if present.  
	 *     A specular map will be used from the alpha channel, if present.  
	 *     See http://www.feelingsoftware.com/uploads/documents/ColladaMax.pdf, section 6.</li>
	 * <ul>*/
	Material getMaterialById(char[] id)
	{	id = Xml.makeId(id);
		if (id in materials)
			return materials[id];
		
		Material result = new Material();
		result.techniques ~= new MaterialTechnique();
		result.techniques[0].passes ~= new MaterialPass();
		MaterialPass pass = result.techniques[0].passes[0];
		
		Node technique;  // Unfortunately ColladaMaya sometimes references nonexistant materials.  Not sure what to do about that.
		Node materialNode = Xml.getNodeById(doc, id, "id", "material");
		if (materialNode.hasChild("instance_effect"))
		{	Node instanceEffect = materialNode.getChild("instance_effect"); // TODO: instance_effect can have child nodes that specify parameters
			Node effectNode = Xml.getNodeById(doc, instanceEffect.getAttribute("url"));
			Node profileCommon = effectNode.getChild("profile_COMMON"); // TODO: profile_GLSL
			technique = profileCommon.getChild("technique");
		} else if (materialNode.hasChild("shader")) // Collada 1.3
			technique = materialNode.getChild("shader").getChild("technique");
		else // no material
			return Material.getDefaultMaterial();		
		
		Node shadingType = technique.getChild(); // in profile_COMMON, it can be newparam, image, blinn, constant, lambert, phong, or extra.
												// blinn, lambert, and phong all have the same parameters.
		if (shadingType.name() == "phong")
			pass.autoShader = MaterialPass.AutoShader.PHONG;
		else if (shadingType.name == "lambert")
			pass.flat = true;
		// else use blinn (gourard) shading from the fixed function pipeline
		
		
		// Helper function for loading material data.
		void getColorOrTexture(Node n, inout Color color, inout Texture texture)
		{	char[] name = n.name();
			switch (name)
			{	case "param":
					n = Xml.getNodeById(doc, n.getAttribute("ref"), "sid").getChild("float3");	
					// deliberate fall-through
				case "color":
					Color temp = Color(Xml.parseNumberList!(float)(n.value));
					color = Color(cast(int)temp.r, cast(int)temp.g, cast(int)temp.b, ((color.a*cast(int)temp.a)/255));
					break;
				case "texture":
					texture = getTextureById(n.getAttribute("texture"));
					break;
				default:
					Log.warn("Collada material parameter '%s' not supported", name);
		}	}
		
		// Loop through and get each material property
		scope Node[] params = shadingType.getChildren();
		foreach (Node param; params)
		{				
			if (!param.getChildren().length)
				continue;
			
			Node child = param.getChild();				
			Texture texture;
			switch(param.name())
			{
				case "ambient":
					getColorOrTexture(child, pass.ambient, texture);
					break;
				case "diffuse":
					getColorOrTexture(child, pass.diffuse, texture);
					if (texture)
						pass.setDiffuseTexture(TextureInstance(texture));
					break;
				case "bump": // Bump map extension used by Okino, http://www.okino.com/conv/exp_collada_extensions.htm
					getColorOrTexture(child, pass.diffuse, texture);
					if (texture)
						pass.setNormalSpecularTexture(TextureInstance(texture));
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
					if (transparency==0)
						Log.warn("Material '%s' in Collada file '%s' has transparency of 0 and won't be rendered.", id, resourcePath);
					break;
				default:
					break;
			}
		}
		
		// Look to see if there's a technique/extra/technique/bump for a bump--fcollada (and maybe also Blender?) puts the bump map here.
		if (technique.hasChild("extra"))
		{	Node extra = technique.getChild("extra");
			if (extra.hasChild("technique"))
			{	Node extraTechnique = extra.getChild("technique");
				if (extraTechnique.hasChild("bump"))
				{	Texture texture;
					getColorOrTexture(extraTechnique.getChild("bump").getChild("texture"), pass.diffuse, texture);
					if (texture)
						pass.setNormalSpecularTexture(TextureInstance(texture)); 
		}	}	}
		
		// Enable blending if there's alpha.
		if (pass.blend==MaterialPass.Blend.NONE)
			if (pass.diffuse.a < 255 || (pass.textures.length && pass.textures[0].texture.getImage().getChannels()==4))
				pass.blend = MaterialPass.Blend.AVERAGE;
		
		// Create a fallback technique that uses no shaders.
		if (result.getPass().autoShader == MaterialPass.AutoShader.PHONG)
		{
			MaterialTechnique t = new MaterialTechnique();
			MaterialPass p = dup(result.getPass());
			p.autoShader = MaterialPass.AutoShader.NONE;
			if (p.textures.length > 1)
				p.textures.length = 1;
			t.passes ~= p;
			result.techniques ~= t;
		}
		
		return result;
	}
		
	/**
	 * Get all geometry from the file merged into a single Yage Model..
	 * This is usually the desired behavior when loading a collada file as a model. 
	 * 
	 * Unlike getGeometryById, this takes into account the file's asset/up_axis. */
	Model getMergedGeometry()
	{
		Model[] geometries;
		Matrix[] geometryTransforms; // A transformation matrix for each geometry found.
		
		// Get the up direction (unfinished)
		Matrix upTransform = getBaseTransform();
		
		foreach (visual_scene; getScenes()) // loop through scenes
		{
			// Go through the scene nodes and collect anything that can be used as a model.
			void traverseSceneNodes(Node node, Matrix matrix)
			{
				// Get transformation matrix for this instance of the geometry.
				matrix = matrix.transformAffine(getSceneNodeTransform(node));
					
				Node skin;
				char[] geometryId, controllerId, skeletonId;
				if (node.hasChild("instance_geometry")) // Collada 1.4+
					geometryId = node.getChild("instance_geometry").getAttribute("url");
				else if (node.hasChild("instance")) // Collada 1.3
					geometryId = node.getChild("instance").getAttribute("url");
				else if (node.hasChild("instance_controller")) // A controller for skeletal animation, which we will follow to get it's geometry
				{	Node instanceController = node.getChild("instance_controller");
					Node controller = Xml.getNodeById(doc, instanceController.getAttribute("url"), "id", "controller");
					controllerId = controller.getAttribute("id");
					skin = controller.getChild("skin");
					geometryId = skin.getAttribute("source"); // geometry
					
					//Matrix bindShapeMatrix = Matrix(Xml.parseNumberList!(float)(skin.getChild("bind_shape_matrix").value()));
					//matrix = matrix.transformAffine(bindShapeMatrix); // Or perhaps I should rotat the skeleton by this?
					
					// Skeleton
					if (instanceController.hasChild("skeleton"))
						skeletonId = instanceController.getChild("skeleton").value();					
				}
				
				if (geometryId.length)
				{   int[] vertexRemap;			
					Model model = new Model(getGeometryById(geometryId, true, vertexRemap));
					if (skeletonId.length)
					{	model.joints = getJointsById(skeletonId);
						if (controllerId.length)
							model.jointInfluences = getJointInfluencesByControllerId(controllerId, model, vertexRemap);
					}
					
					// Save the absolute transformation of this Geometry
					if (model)  // TODO: Sometimes intance_geometry has xml children specifying a material (or other things as well?)
					{	geometries~= model;
						geometryTransforms ~= matrix.rotate(upTransform);
					}
				}					
				
				foreach (child; node.getChildren("node")) // loop through nodes in a scene
					traverseSceneNodes(child, matrix);
			}
			
			traverseSceneNodes(visual_scene, Matrix.IDENTITY);
		}
		
		// Transform geometry instances by their transformation matrix
		foreach (i, geometry; geometries)
		{	Matrix m = geometryTransforms[i];
			if (m.isIdentity())
				continue;
		
			foreach(inout Vec3f vertex; cast(Vec3f[])geometry.getAttribute(Geometry.VERTICES))
				vertex = vertex.transform(m); 
			
			// Transform normals and tangents by rotation only
			foreach(inout Vec3f normal; cast(Vec3f[])geometry.getAttribute(Geometry.NORMALS))
				normal = normal.rotate(m);
		}
		
		// Perform the merge (if there's more than one to merge)
		Model result = geometries[0];
		if (geometries.length > 1)
			result = Model.merge(geometries);			
		delete geometries;
		
		result.optimize();
		
		//If phong shading is used, generate tangent vectors in texture coordinates 1.
		foreach (mesh; result.getMeshes())
			if (mesh.material.getPass().autoShader == MaterialPass.AutoShader.PHONG)
			{	result.setAttribute(Geometry.TEXCOORDS1, result.createTangentVectors());
				break;
			}
		
		return result;
	}

	///
	Joint[] getJointsById(char[] id)
	{     
		// Get the up direction (unfinished)
		Matrix upTransform = getBaseTransform();
		
		Joint[] result; // TODO: ArrayBuilder!(Joint)
		
		Joint traverseSkeleton(Node node)
		{	Joint joint = new Joint();
			joint.relative = getSceneNodeTransform(node);
			if (node.hasAttribute("sid")) // sometimes max exports don't.
				joint.sid = node.getAttribute("sid").dup; // dup should reduce memory fragmentation and allow collada text to later be freed.
			joint.name = node.getAttribute("name").dup;
			joint.number = result.length;
			result ~= joint;
			
			foreach (child; node.getChildren("node"))
				joint.addChild(traverseSkeleton(child));
			return joint;
		}
		Node joint0Node = Xml.getNodeById(doc, id, "id", "node");
		traverseSkeleton(joint0Node);
		
		// Get the absolute transformation of the base joint
		if (result.length)
		{	auto joint0 = result[0];		

			Matrix getSceneNodeAbsoluteTransform(Node node) // recursively traverse the scene graph upward to get the final absolute transform.
			{	Matrix result = getSceneNodeTransform(node);
				Node parentNode = node.getParent();
				if (parentNode.name() == "node")
					return getSceneNodeAbsoluteTransform(parentNode).transformAffine(result);
				else
					return upTransform.transformAffine(result);
				return result;
			}
			
			joint0.relative = getSceneNodeAbsoluteTransform(joint0Node); // by nature, transforming the first will rotate all.
		}
		return result;
	}
	
	/**
	 * Params:
	 *     id = 
	 *     model = A model with the joints and vertex arrays previously populated. 
	 * Returns: An array the same length as the model's vertices, with each sub array a list of the joints that influence that vertex. */
	JointInfluence[][] getJointInfluencesByControllerId(char[] id, Model model, int[] vertexRemap)
	{	
		assert(!vertexRemap.length || vertexRemap.length == model.getVertexBuffer(Geometry.VERTICES).length);
		
		JointInfluence[][] result;
		
		Node controller = Xml.getNodeById(doc, id, "id", "controller");
		
		// Get vertex weights from library_controllers/controller/skin
		if (controller.hasChild("skin"))
		{
			Node skin = controller.getChild("skin");
			Joint[int] jointMap; // Map from joint indices number to array to actual Joint
			Matrix[] inverseBindMatrices;
			
					// Load data from the joints node
			Node jointsNode = skin.getChild("joints");							
			foreach (input; jointsNode.getChildren("input"))
			{	char[] semantic = input.getAttribute("semantic");
				if (semantic == "JOINT")
				{
					// Create a map of joint names to joints.  
					ushort unused;
					scope char[][] jointNames = getDataFromSourceId!(char[])(input.getAttribute("source"), unused);
					scope Joint[char[]] sidToJoint;
					foreach (joint; model.joints) // TODO: Maybe it would be good to have one of these in Model, so a gun can be attached to an arm joint.
						sidToJoint[joint.sid] = joint;
					foreach (i, name; jointNames)
						jointMap[i] = sidToJoint[name];
					
				}
				else if (semantic == "INV_BIND_MATRIX") 
				{	ushort unused;
					float[] matrixValues = getDataFromSourceId!(float)(input.getAttribute("source"), unused);
					inverseBindMatrices = cast(Matrix[])matrixValues;
				}
			}
			
			// Load data from the vertex_weights node
			Node vertexWeightsNode = skin.getChild("vertex_weights");
			scope int[] vcounts = Xml.parseNumberList!(int)(vertexWeightsNode.getChild("vcount").value); // how many vertices per joint weight
			scope int[] v = Xml.parseNumberList!(int)(vertexWeightsNode.getChild("v").value); // contains alternating jointMap and weight indices into the joints and weights arrays
			scope float[] weights;
			foreach (input; vertexWeightsNode.getChildren("input"))
				if (input.getAttribute("semantic")=="WEIGHT")
				{	ushort unused;
					weights = getDataFromSourceId!(float)(input.getAttribute("source"), unused);
				}
			
			// Read data into result
			int index;
			foreach (count; vcounts)
			{
				// Load all influences for a vertex
				JointInfluence[] influences; // TODO: Read offsets, right now 0 and 1 offsets are assumed!
				float totalInfluence = 0;
				for (int i=index; i<index+count*2; i+=2) // loop through relevant indices in v
				{
					JointInfluence influence;
					int jointIndex = v[i];
					int weightIndex = v[i+1];					
					influence.joint = jointMap[jointIndex].number;
					influence.influence = weights[weightIndex];
					influences ~= influence;
					totalInfluence += influence.influence;
				}
				
				// Normalize influences
				float scaleInfluence = 1/totalInfluence;
				foreach (inout influence; influences)
					influence.influence *= scaleInfluence;
				
				result~= influences;
				index+= count*2;				
			}			
		}
		
		if (!vertexRemap.length)
			return result;
		
		JointInfluence[][] result2;
		result2.length = vertexRemap.length;
		foreach (to, from; vertexRemap)
			result2[to] = result[from];
	
		assert(result2.length == model.getVertexBuffer(Geometry.VERTICES).length);		
		
		return result2;
	}
	
	/**
	 * Get a yage Texture from the Collada file by its id.
	 * This uses ResourceManager.texture internally, so subsequent calls will return an already loaded Texture.
	 * 
	 * These are Yage-specific notes for loading Collada textures:
	 * <li>An image's <hint precision="_"> value determines whether texture compression is used.
	 *     LOW (or not specified at all): 8 byte channels, texture compression
	 *     MID: 8 byte channels, no compression
	 *     HIGH: 16 bit float (not supported yet)
	 *     MAX: 32 bit float (not supported yet)</li> */
	Texture getTextureById(char[] id)
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
		Texture.Format format = Texture.Format.AUTO;
		if (precision=="MID")
			format = Texture.Format.AUTO_UNCOMPRESSED;
		Texture result = ResourceManager.texture(imagePath, format);
		
		textures[id] = result;
		return result;			
	}

	// All geometry will be rotated by this Matrix.  
	protected Matrix getBaseTransform()
	{	return Matrix.IDENTITY;
		char[] upAxis = Node(doc.elements).getChild("asset").getChild("up_axis").value();
		if (upAxis == "X_UP") // Y is already up
			return Vec3f(0, -3.141527/2, 0).toMatrix();
		if (upAxis == "Z_UP")
			return Vec3f(-3.141527/2, 0, 0).toMatrix();
		return Matrix.IDENTITY;
	}
	
	// See: https://collada.org/mediawiki/index.php/Using_accessors
	protected T[] getDataFromSourceId(T)(char[] id, out ushort components)
	{	
		Node source = Xml.getNodeById(doc, id);		
		Node sourceAccessor;
		if (source.hasChild("technique_common"))
			sourceAccessor = source.getChild("technique_common").getChild("accessor"); // TODO: Read stride, offset, etc.
		else // collada 1.3
			sourceAccessor = source.getChild("technique").getChild("accessor"); // TODO: Read stride, offset, etc.
		scope Node[] params = sourceAccessor.getChildren("param");
		components = params.length;
		char[] sourceFloatArrayId = sourceAccessor.getAttribute("source");
		Node sourceFloatArray = Xml.getNodeById(doc, sourceFloatArrayId);
		return Xml.parseNumberList!(T)(sourceFloatArray.value);
	}
	
	// Get all Scene nodes, trying several different names.
	Node[] getScenes()
	{
		Node[] scenes;
		Node root = Node(doc.elements);
		if (root.hasChild("library_visual_scenes"))
		    scenes = root.getChild("library_visual_scenes").getChildren("visual_scene");
		else // collada 1.3
			scenes = root.getChildren("scene");
		return scenes;
	}
	
	// Get the relative transformation matrix of a visual_scene node.
	Matrix getSceneNodeTransform(Node sceneNode)
	{	
		Matrix result;
		foreach (transform; sceneNode.getChildren())
		{	if (transform.name=="translate")
				result = result.move(Vec3f(Xml.parseNumberList!(float)(transform.value)));
			else if (transform.name=="rotate")
			{	float[] values = Xml.parseNumberList!(float)(transform.value);
				if (values.length!=4)
					throw new XmlException("Expected four values for rotation.");
				if (values[3] != 0) // if some rotation
					result = result.rotate(Vec3f(values[3]*tango.math.Math.PI/180, values[0], values[1], values[2])); // load from axis-angle							
			} 
			else if (transform.name=="scale")						
				result = result.scale(Vec3f(Xml.parseNumberList!(float)(transform.value)));
			else if (transform.name=="matrix") // collada 1.3
				result = Matrix(Xml.parseNumberList!(float)(transform.value));
		}
		return result;
	}
	
	// Wraps Tagno's Node to make it easier and with Exception checks
	protected static struct Node
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
		
		// Get the value of an attribute by its name, or throw XMLException if not found
		char[] getAttribute(char[] name)
		{	auto attr = node.attributes().name(null, name);
			if (attr)
				return attr.value();
			throw new XMLException("Attribute '%s' doesn't exist on node '%s'", name, node.name());
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

		Node getParent()
		{	auto result = node.parent();
			if (result)
				return Node(result);
			throw new XMLException("Node '%s' doesn't have a parent.", node.name());
		}
		
		bool hasAttribute(char[] name)
		{	return cast(bool)(node.attributes().name(null, name));			
		}	
		
		bool hasChild(char[] name="")
		{	return (node.query.child(name).nodes.length > 0);
		}
		
		bool hasParent()
		{	return cast(bool)node.parent();
		}
		
	}
	
	// Xml parsing helper.
	// Wrap tango xml so any errors throw XMLException
	protected static struct Xml
	{	
		// Get all nodes in the document that have the matching id.
		static Node getNodeById(Document!(char) doc, char[] id, char[] attributeName="id", char[] type="")
		{	assert(doc);
			id = makeId(id);
			auto result = doc.query.descendant.filter((Document!(char).Node n) {
				auto attr = n.attributes.name(null, attributeName);
				bool result = attr && attr.value == id;
				if (result && type.length) // check type
					result = n.name==type;				
				return result;
			});
			if (result.nodes.length)
				return Node(result.nodes[0]);
			if (type.length)
				throw new XMLException("The document does not have an element of type %s with %s='%s'", type, attributeName, id);
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
			int i;
			try {
				foreach(piece; pieces)			
					if (piece.length)
					{	result[i] = to!(T)(piece);
						static if (is(T : real))
							assert(!isNaN(result[i])); // can this happen, or is an exception thrown?
						i++;
					}
			} catch (ConversionException e)
			{	throw new XmlException(e.toString());
			}
			return result[0..i];
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