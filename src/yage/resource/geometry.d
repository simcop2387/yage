/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.geometry;

import tango.math.Math;
import yage.core.math.vector;
import yage.resource.manager;
import yage.resource.material;
import yage.system.system;
import yage.system.log;

/*
 * A VertexBuffer wraps around a Geometry attribute, adding a dirty flag and other info. 
 * This is only needed inside the engine. */
class VertexBuffer
{
	bool dirty = true;
	void[] data;
	TypeInfo type;
	ubyte components;
	bool cache = true; /// If true the Vertex Buffer will be cached in video memory.  // TODO: Setting this back to false keeps it in video memory but unused.

	/// 
	void setData(T)(T[] data)
	{	dirty = true;
		this.data = data;
		type = typeid(T);
		if (data.length)
			components = data[0].components;
	}

	/// Get the number of vertices for this data.
	int length()
	{	return data.length/type.tsize();		
	}	
	
	void* ptr()
	{	return data.ptr;
	}
}

/**
 * Stores vertex data and meshes for any 3D geometry. */
class Geometry
{	
	/**
	 * Constants representing fixed-function VertexBuffer types, for use with get/set attributes.
	 *     VERTICES: An array of vertices specifying x,y,z coordinates.
	 *     NORMALS: Optional normal vectors for each vertex used in lighting calculations.
	 *     TEXCOORDS: Optional texture coordinates for each vertex, one for each multi-texture unit.
	 *     COLORS0: An optional color value for each vertex.
	 *     COLORS1: An optional secondary color value for each vertex.
	 *     FOGCOORDS: Currently unused.
	 */
	static const char[] VERTICES   = "gl_Vertex";
	static const char[] NORMALS    = "gl_Normal"; /// ditto
	static const char[] TEXCOORDS0 = "gl_MultiTexCoord0"; /// ditto
	static const char[] TEXCOORDS1 = "gl_MultiTexCoord1"; /// ditto
	static const char[] TEXCOORDS2 = "gl_MultiTexCoord2"; /// ditto
	static const char[] TEXCOORDS3 = "gl_MultiTexCoord3"; /// ditto
	static const char[] TEXCOORDS4 = "gl_MultiTexCoord4"; /// ditto
	static const char[] TEXCOORDS5 = "gl_MultiTexCoord5"; /// ditto
	static const char[] TEXCOORDS6 = "gl_MultiTexCoord6"; /// ditto
	static const char[] TEXCOORDS7 = "gl_MultiTexCoord7"; /// ditto
	static const char[] COLORS0    = "gl_Color"; /// ditto
	static const char[] COLORS1    = "gl_SecondaryColor"; /// ditto
	static const char[] FOGCOORDS  = "gl_FogCood"; /// ditto
	

	/*protected*/ VertexBuffer[char[]] attributes;
	/*protected*/ Mesh[] meshes;
	
	
	/**
	 * These functions allow modifying the vertex attributes of the geometry. 
	 * Vertex attributes are arrays that specify data for each vertex, such as a position, texture coodinate, or custom value.
	 * Params:
	 *     name = Specifies the vertex attribute to get/set.  It can be one of the named constants defined above or a custom name.
	 *         Custom attributes are passed to the vertex shader into an attribute variable of the same name.
	 *         Custom names must not use the "gl_" prefix; it is reserved.
	 *     values = Vertex data values to set.
	 *     components = on getAttribute, this out parameter specifies how many values per vertex.
	 * Notes:
	 *     getAttribute will return an empty array if the attribute doesn't exist.
	 * Example:
	 * --------
	 * Vec3f[] vertices;
	 * ... 
	 * if (!geom.getAttribute(Geometry.VERTICES))
	 *     geom.setAttribute(Geometry.VERTICES, vertices);
	 * --------
	 */
	public void[] getAttribute(char[] name)
	{	int components;
		return getAttribute(name, components);
	}
	public void[] getAttribute(char[] name, out int components) /// ditto
	{	auto result = name in attributes;
		if (result)
		{	components = (*result).components;
			return (*result).data;
		}
		return null;
	}
	public void setAttribute(T)(char[] name, T[] values) /// ditto
	{	
		// Prevent creation of a new VBO if one exists
		VertexBuffer vb = getVertexBuffer(name);
		if (vb && vb.components == T.components)
		{	vb.setData(values);
		} else
		{	vb = new VertexBuffer();
			vb.setData(values);
			attributes[name] = vb;
			assert(attributes[name].data.length > 0);
		}
	}
	
	///
	public void removeAttribute(char[] name)
	{	attributes.remove(name);		
	}
	
	/**
	 * Get the vertex buffers used for rendering.  Vertex buffers wrap attributes. */
	public VertexBuffer[char[]] getVertexBuffers()
	{	return attributes;
	}
	
	/**
	 * Get a single VertexBuffer by name rendering. */
	public VertexBuffer getVertexBuffer(char[] name) 
	{	auto result = name in attributes;
		if (result)
			return *result;
		return null;
	}
	
	/**
	 * Get / set the array of meshes for this Geometry.
	 * Meshes define a material and an array of triangles to connect vertices. 
	 * TODO: are these accessors needed? */
	public Mesh[] getMeshes()
	{	return meshes;		
	}
	public void setMeshes(Mesh[] meshes) /// ditto
	{	this.meshes = meshes;		
	}
	
	/// Calculate the radius of a sphere, centered at the model's origin, that can contain this Model.
	float getRadius()
	{	float result=0;
		if (VERTICES in attributes)
		{	foreach(vertex; cast(Vec3f[])getAttribute(VERTICES))
			{	float length2 = vertex.length2();
				if (length2 > result)
					result = length2;
		}	}	
		return sqrt(result);
	}

	/**
	 * Merge all geometries into a single Geometry.
	 * Returns: The new Geometry will have copies of all vertex attributes and triangles, but share
	 * the same material references as the input geometries. */
	static Geometry merge(Geometry[] geometries)
	{
		// Get a maping of all types to their vertex buffer info.
		VertexBuffer[char[]] types;
		foreach (geometry; geometries)
			foreach(char[] type, vb; geometry.getVertexBuffers())
				types[type] = vb;
		
		Geometry result = new Geometry();
		
		foreach (geometry; geometries)
		{	auto vb = result.getVertexBuffer(Geometry.VERTICES);
			int offset = vb ? vb.length() : 0;
			int length = geometry.getVertexBuffer(Geometry.VERTICES).length();
			
			// Loop through each vertex attribute type
			foreach(type, vbInfo; types)
			{
				auto newValue = geometry.getAttribute(type);
				if (!newValue.length) // if this attribute doesn't have the value, we just add zeros
					newValue = new float[length*vbInfo.components]; 
							
				// Make a new vertex buffer and get info from vbinfo.
				VertexBuffer vb = new VertexBuffer();
				vb.type = vbInfo.type;
				vb.components = vbInfo.components;
				vb.data = result.getAttribute(type) ~ newValue;
				result.attributes[type] = vb;
			}
			
			// Meshes
			foreach (mesh; geometry.meshes)
			{	// vertices are now all merged into the same aray, so we need to upate the triangle indices.
				Vec3i[] triangles = new Vec3i[mesh.getTriangles().length];
				foreach (i, triangle; mesh.getTriangles()) 
					triangles[i] = triangle + Vec3i(offset); 
				result.meshes ~= new Mesh(mesh.material, triangles);
			}
		}
		return result;		
	}

	/// Get a plane to play with.
	static Geometry createPlane(int widthSegments=1, int heightSegments=1)
	{		
		auto result = new Geometry();
		float w = cast(float)widthSegments;
		float h = cast(float)heightSegments;
		Vec3f[] vertices;
		Vec3f[] normals;
		Vec3f[] texCoords;
		Vec3i[] triangles;
		
		// Build vertices
		for (int y=-heightSegments; y<=heightSegments; y+=2)
			for (int x=-widthSegments; x<=widthSegments; x+=2)			
			{	vertices ~= Vec3f(x/w, y/h, 0);
				normals ~= Vec3f(0, 0, 1);
				texCoords ~= Vec3f(x/(w*2)+.5, 1-y/(h*2)-.5, 0); // TODO: Why 3 texture coordinates?
			}
		result.setAttribute(Geometry.VERTICES, vertices);
		result.setAttribute(Geometry.NORMALS, normals);
		result.setAttribute(Geometry.TEXCOORDS0, texCoords);
		
		// Build triangles and material
		for (int y=0; y<heightSegments; y++)
			for (int x=0; x<widthSegments; x++)			
			{	int thisX =  y*(widthSegments+1)+x;
				int aboveX = (y+1)*(widthSegments+1)+x;
				triangles ~= Vec3i(thisX, thisX+1, aboveX);
				triangles ~= Vec3i(aboveX, thisX+1, aboveX+1);
			}
		
		Material material = new Material();
		auto pass = new MaterialPass();
		pass.emissive = "gray"; // So it always shows up at least some
		material.setPass(pass);				
		result.setMeshes([new Mesh(material, triangles)]);
		
		return result;
	}

	Vec2f[] createTangentVectors()
	{
		Vec2f[] texCoords = cast(Vec2f[])getAttribute(Geometry.TEXCOORDS0);
		assert(texCoords.length);
		
		Vec2f[] result;
		// TODO
		return result;		
	}
}


/**
 * A Mesh groups a Material with a set of triangle indices.
 * The Geometry class groups a Mesh with vertex buffers referenced by the traingle indices */
class Mesh
{
	static const char[] TRIANGLES = "gl_Triangles"; /// Constants used to specify various built-in polgyon attribute type names.
	
	protected VertexBuffer triangles;
	public Material material;

	/// Construct an empty mesh.
	this()
	{	triangles = new VertexBuffer();
	}

	/// Create with a material and triangles.
	this(Material matl, Vec3i[] triangles)
	{	this();
		this.material = matl;
		this.triangles.setData(triangles);
	}
	
	~this()
	{	delete triangles;
	}
	
	/**
	 * Get the material, or set the material from another material or a file. */
	Material getMaterial()
	{	return material;
	}
	void setMaterial(Material material) /// ditto
	{	this.material = material;
	}
	void setMaterial(char[] filename, char[] id) /// ditto
	{	this.material = ResourceManager.material(filename, id);
	}

	/**
	 * Get/set the triangles */
	Vec3i[] getTriangles()
	{	return cast(Vec3i[])triangles.data;
	}	
	void setTriangles(Vec3i[] triangles) /// ditto
	{	this.triangles.setData(triangles);
	}
	
	/**
	 * Get the trangles vertex buffer used for rendering. */
	VertexBuffer getTrianglesVertexBuffer()
	{	return triangles;
	}
}