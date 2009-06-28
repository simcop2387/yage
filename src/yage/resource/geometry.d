 /**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.geometry;

import tango.io.Stdout;
import tango.math.Math;
import yage.core.closure;
import yage.core.object2;;
import yage.core.math.vector;
import yage.core.object2;
import yage.resource.manager;
import yage.resource.material;
import yage.resource.resource;
import yage.resource.lazyresource;
import yage.system.system;

import yage.system.graphics.resource;

/**
 * This is a common interface shared by all VertexBuffers.  It allows them to be passed around
 * interchangeably and to exist as siblings in arrays. */
interface IVertexBuffer : IFinalizable
{
	void[] getData(); ///
	void setData(void[]); ///

	bool getDirty(); ///
	void setDirty(bool); ///

	uint getId(); ///
	
	int getSizeInBytes(); ///
	
	byte getComponents(); ///
	
	int length(); ///

	void* ptr(); ///

	float itemLength2(int);
	//char[] toString();
}


/**
 * A VertexBuffer stores the parameters of an OpenGL Vertex Buffer Object
 * TODO: Would it make sense to implement several array operations
 * and then have an update function to synchronize? */
class VertexBuffer(T) : Resource, IVertexBuffer
{
	protected T[] data;
	protected uint id;
	protected bool dirty = true;

	this()
	{	id = GraphicsResource.getVBO();
	}	
	
	/**
	 * Release the VBO and mark it for collection. */
	~this()
	{	finalize();
	}
	void finalize() /// ditto
	{	if (id)
		{	GraphicsResource.freeVBO(id);
			id = 0;
			dirty = true;
		}
	}

	/**
	 * Get/set the vertex data of this buffer.
	 * It must be cast to an array of type T[] */
	void[] getData()
	{	return data;
	}
	void setData(void[] data) /// ditto
	{	dirty = true;
		this.data = cast(T[])data;
	}
	
	/**
	 * Get/set the dirty flag.
	 * If VBO's are used and the dirty flag is set, the VBO will be updated with the vertex data. */
	bool getDirty()
	{	return dirty;
	}
	void setDirty(bool dirty) /// ditto
	{	this.dirty = dirty;
	}

	/**
	 * Get/set the OpenGL id of the vertex buffer, or 0 if it hasn't yet been allocated. */
	uint getId()
	{	return id;
	}
	
	/**
	 * Get the size of the vertex data in bytes. */
	int getSizeInBytes()
	{	return length * T.sizeof;
	}
	
	/**
	 * Returns: The number of components in each array element. */
	byte getComponents()
	{	return T.components;
	}

	/// Implement array operations
	int length()
	{	return data.length;
	}

	/**
	 * Returns: A c-style pointer to the vertex data array. */
	void* ptr()
	{	return data.ptr;
	}

	// Hackish: used by Geometry for radius calculation
	float itemLength2(int index)
	{	return data[index].length2();
	}	

	/*
	char[] toString()
	{	char[] result = "VertexBuffer {\ndata = [";
		foreach (token; data)
			result ~= token.toString();
		return result ~ "]\n}\n";
	}*/
}

/**
 * Stores vertex data and meshes for any 3D geometry. */
class Geometry : Resource
{	
	/**
	 * Constants representing fixed-function VertexBuffer types, for use with get/set attributes.
	 * Types:
	 *     VERTICES An array of vertices specifying x,y,z coordinates.
	 *     NORMALS Optional normal vectors for each vertex used in lighting calculations.
	 *     TEXCOORDS[0..7] Optional texture coordinates for each vertex, for each multi-textured level.
	 *     COLORS0 An optional color value for each vertex.
	 *     COLORS1 An optional secondary color value for each vertex.
	 *     FOGCOORDS
	 */
	static const char[] VERTICES   = "gl_Vertex"; /// ditto
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
	
	protected IVertexBuffer[char[]] attributes;
	protected Mesh[] meshes;
	
	
	public IVertexBuffer getVertices()
	{	return attributes[VERTICES];
	}
	public void setVertices(T)(T[] vertices)
	{	setAttributeData(VERTICES, vertices);
	}
	public VertexBuffer!(Vec3f) getNormals()
	{	return cast(VertexBuffer!(Vec3f))attributes[NORMALS];
	}
	public void setNormals(Vec3f[] normals)
	{	setAttributeData(NORMALS, normals);
	}
	public IVertexBuffer getTexCoords0()
	{	return attributes[TEXCOORDS0];
	}
	public void setTexCoords0(Vec2f[] tex_coords1)
	{	setAttributeData(TEXCOORDS0, tex_coords1);
	}
	public void setTexCoords0(Vec3f[] tex_coords1)
	{	setAttributeData(TEXCOORDS0, tex_coords1);
	}

	/**
	 * These functions allow modifying the vertex attributes of the geometry. 
	 * Example:
	 * --------
	 * if (!geom.hasAttribute(Geometry.VERTICES))
	 *     geom.setAttribute(Geometry.VERTICES, new VertexBuffer!(Vec3f)());
	 * --------
	 */
	public IVertexBuffer[char[]] getAttributes()
	{	return attributes;
	}
	public IVertexBuffer getAttribute(char[] name) /// ditto
	{	return attributes[name];
	}
	public void setAttribute(char[] name, IVertexBuffer vb) /// ditto
	{	attributes[name] = vb;
	}
	public void setAttributeData(T)(char[] name, T[] data) /// ditto
	{	
		// Prevent creation of a new VBO
		if (hasAttribute(name) && attributes[name].getComponents() == T.components)
		{	attributes[name].setData(data);
		} else
		{	VertexBuffer!(T) vb = new VertexBuffer!(T);
			vb.setData(data);
			setAttribute(name, vb);
		}
	}
	public bool hasAttribute(char[] name) /// ditto
	{	return cast(bool)(name in attributes);		
	}
	public void clearAttribute(char[] name) /// ditto
	{	attributes.remove(name);		
	}
	
	/**
	 * Get / set the array of meshes for this Geometry.
	 * Meshes define a material and an array of triangles to connect vertices. */
	public Mesh[] getMeshes()
	{	return meshes;		
	}
	public void setMeshes(Mesh[] meshes) /// ditto
	{	this.meshes = meshes;		
	}
	
	/// Get radius of a sphere, in modelspace coordinates, centered at the model's origin, that can contain this Model.
	float getRadius()
	{	float result=12;
		if (VERTICES in attributes)
		{	auto vertices = attributes[VERTICES];
			if (vertices.length())
			{	for (int i=0; i<vertices.length(); i++)
				{	float length2 = vertices.itemLength2(i);
					if (length2 > result)
						result = length2;
				}
		}	}
		return sqrt(result);
	}

	/*
	char[] toString()
	{	char[] result = "Geometry {\nattributes={\n";
		foreach (name, attrib; attributes)
			result ~= "\n" ~ name ~ "=" ~ attrib.toString();
		return result ~ "}\n}\n";
	}*/
}


/**
 * A mesh consists of a material and an array of triangle indices that index into vertex buffers. */
class Mesh : Resource
{
	static const char[] TRIANGLES = "gl_Triangles"; /// Constants used to specify various built-in polgyon attribute type names.
	
	protected VertexBuffer!(Vec3i) triangles;
	protected Material material;

	///
	this()
	{	triangles = new VertexBuffer!(Vec3i);
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
	void setMaterial(char[] filename) /// ditto
	{	this.material = ResourceManager.material(filename);
	}

	/**
	 * Get/set the triangles */
	VertexBuffer!(Vec3i) getTriangles()
	{	return triangles;
	}
	void setTriangles(VertexBuffer!(Vec3i) triangles) /// ditto
	{	this.triangles = triangles;
	}
	void setTriangles(Vec3i[] triangles) /// ditto
	{	this.triangles.setData(triangles);
	}

}