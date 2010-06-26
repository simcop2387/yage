/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.geometry;

import tango.math.Math;
import yage.core.array;
import yage.core.format;
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
	ubyte components; /// Number of floats for each vertex
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
 * Each Geometry has arrays of vertex data and one or more Meshes; each Mesh has its own material
 * and an array of triangle indices that correspond to vertices in the Geometry vertex array. */
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
	
	bool drawNormals = false;
	bool drawTangents = false;
	
	/**
	 * Create tangent vectors required for MaterialPass.AutoShader.PHONG when a normal map is used.
	 * From: Lengyel, Eric. "Computing Tangent Space Basis Vectors for an Arbitrary Mesh". 
	 * Terathon Software 3D Graphics Library, 2001. http://www.terathon.com/code/tangent.html */
	public Vec3f[] createTangentVectors()
	{		
		// TODO: Multiple meshes
		
		Vec3f[] vertices = cast(Vec3f[])getAttribute(Geometry.VERTICES);
		Vec3f[] normals = cast(Vec3f[])getAttribute(Geometry.NORMALS);
		float[] texCoords = cast(float[])getAttribute(Geometry.TEXCOORDS0);
		int texCoordCount = getVertexBuffer(Geometry.TEXCOORDS0).components;		
		assert(texCoords.length/texCoordCount == vertices.length);
	
		
		Vec3f[] tan1 = new Vec3f[vertices.length];
		Vec3f[] tan2 = new Vec3f[vertices.length];
		
		Vec3f[] tangents = new Vec3f[vertices.length];
		
		foreach (mesh; meshes)
			foreach (tri; mesh.getTriangles())
			{
				
				Vec3f v1 = vertices[tri.x];
				Vec3f v2 = vertices[tri.y];
				Vec3f v3 = vertices[tri.z];
				
				Vec2f w1 = Vec2f(texCoords[tri.x*texCoordCount..tri.x*texCoordCount+1]);
				Vec2f w2 = Vec2f(texCoords[tri.y*texCoordCount..tri.y*texCoordCount+1]);
				Vec2f w3 = Vec2f(texCoords[tri.z*texCoordCount..tri.z*texCoordCount+1]);
				
				float x1 = v2.x - v1.x;
				float x2 = v3.x - v1.x;
				float y1 = v2.y - v1.y;
				float y2 = v3.y - v1.y;
				float z1 = v2.z - v1.z;
				float z2 = v3.z - v1.z;
				
				float s1 = w2.x - w1.x;
				float s2 = w3.x - w1.x;
				float t1 = w2.y - w1.y;
				float t2 = w3.y - w1.y;
						
				float r = 1f / (s1 * t2 - s2 * t1);
				Vec3f sdir = Vec3f(
					(t2 * x1 - t1 * x2) * r, 
					(t2 * y1 - t1 * y2) * r,
					(t2 * z1 - t1 * z2) * r);
				Vec3f tdir = Vec3f(
					(s1 * x2 - s2 * x1) * r, 
					(s1 * y2 - s2 * y1) * r,
					(s1 * z2 - s2 * z1) * r);
				
				tan1[tri.x] += sdir;
				tan1[tri.y] += sdir;
				tan1[tri.z] += sdir;
				
				tan2[tri.x] += tdir;
				tan2[tri.y] += tdir;
				tan2[tri.z] += tdir;			
			}
		
		foreach (i, vert; vertices)
		{
			Vec3f n = normals[i];
			Vec3f t = tan1[i];
			
			tangents[i] = (t-n * n.dot(t)).normalize();
			
			//tangents[i].w = n.cross(t).dot(tan2[i]) < 0 ? -1 : 1;
			
		}
		delete tan1;
		delete tan2;
		
		return tangents;
	}
	
	
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
	 * Merge duplicate vertices and Meshes.
	 * This should be done before creating binormals in order to work well. 
	 * Returns:  a map from the old vertex indices to the new ones. */
	int[] optimize()
	{
		debug { // assertions
			int length =  getVertexBuffer(Geometry.VERTICES).length;
			foreach (name, attribute; attributes)
				assert(attribute.length == length, format("%s is only of length %s, but vertices are of length %s", name, attribute.length, length));
		}
		
		// Merge duplicate vertices
		VertexBuffer vb = attributes[Geometry.VERTICES];
		float[] vertices = cast(float[])vb.data;
		int c = vb.components;
		ArrayBuilder!(int) duplicates;
		duplicates.reserve = 256;
		
		// Make a map of vertices x component to their index for fast lookups
		int[][Vec2f] vertexMap;
		for (int i=0; i<vb.length; i++)
		{	Vec2f vertex = Vec2f(vertices[i*c..i*c+2]);
			vertexMap[vertex] ~= i;
		}
				
		scope attributes2 = attributes.values; // makes looping over attributes much faster!
		
		// Get the indices of vertices that are the same as index.
		int[] getDuplicateVertices(int index)
		{	
			Vec2f* vertex = cast(Vec2f*)&vertices[index*c];
				
			duplicates.length = 0;
			foreach (i; vertexMap[*vertex])
			{	bool match = true;
				foreach (attribute; attributes2)
				{	float[] data = cast(float[])attribute.data;	
					int c2 = attribute.components;
					float[] original = data[index*c2..index*c2+c2]; // data to compare against.
					if (data[i*c2..i*c2+c2] != original)
					{	match = false;
						break;											
					}
				}
				if (match)
					duplicates ~= i;
			}
			return duplicates.data;
		}	
		
		// This is the slow part
		// Build a map of how to merge vertices
		int[] remap = new int[vb.length];
		scope int[int] remapReverse;
		int offset = 0;
		for (int i=0; i<vertices.length/c; i++)
		{	bool remapped = false;
			foreach (d; getDuplicateVertices(i))
				//if (!(d in remap))
				if (remap[d] == 0)
				{	remap[d] = offset;
					remapReverse[offset] = d;
					remapped = true;					
				}
			if (remapped)
				offset++;
		}
		
		// Move data
		foreach (name, inout attribute; attributes)
		{
			int c2 = attribute.components;
			float[] oldData = cast(float[])attribute.data;
			float[] data = new float[remapReverse.length*c2];			
			foreach (to, from; remapReverse) // Too bad doing this in-place fails for some models			
			{	//Log.trace("%s %s %s %s", data.length, to*c2+c2, oldData.length, from*c2+c2);
				data[to*c2..to*c2+c2] = oldData[from*c2..from*c2+c2];	
			}
			
			attribute.data = data;
			delete oldData;
		}
		
		// Update triangle indices
		foreach (mesh; meshes)
		{	Vec3i[] triangles = mesh.getTriangles();
			foreach (i, inout tri; triangles) // Shouldn't doing this in-place fail?
			{	triangles[i].x = remap[tri.x];
				triangles[i].y = remap[tri.y];
				triangles[i].z = remap[tri.z];
			}			
			mesh.setTriangles(triangles);
		}
		
		return remap;
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
		Vec2f[] texCoords;
		Vec3i[] triangles;
		
		// Build vertices
		for (int y=-heightSegments; y<=heightSegments; y+=2)
			for (int x=-widthSegments; x<=widthSegments; x+=2)			
			{	vertices ~= Vec3f(x/w, y/h, 0);
				normals ~= Vec3f(0, 0, 1);
				texCoords ~= Vec2f(x/(w*2)+.5, 1-y/(h*2)-.5);
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
		

		result.setAttribute(Geometry.TEXCOORDS1, result.createTangentVectors());
		
		return result;
	}

}


/**
 * A Mesh groups a Material with a set of triangle indices.
 * The Geometry class groups a Mesh with vertex buffers referenced by the traingle indices */
class Mesh
{
	static const char[] TRIANGLES = "GL_TRIANGLES"; /// Constants used to specify various built-in polgyon attribute type names.
	static const char[] LINES = "GL_LINES"; /// ditto
	static const char[] POINTS = "GL_POINTS"; /// ditto
	
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