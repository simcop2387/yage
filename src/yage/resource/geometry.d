 /**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.geometry;

import tango.math.Math;
import yage.core.interfaces;
import yage.core.vector;
import yage.resource.mesh;
import yage.resource.vertexbuffer;


/**
 * Stores vertex data and meshes for any 3D geometry. */
class Geometry
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
	
	
	public VertexBuffer!(Vec3f) getVertices()
	{	return cast(VertexBuffer!(Vec3f))attributes[VERTICES];
	}
	public void setVertices(Vec3f[] vertices)
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
	 * Get / set the array of meshes for this Geometry.
	 * Meshes define a material and an array of triangles to connect vertices. */
	public Mesh[] getMeshes()
	{	return meshes;		
	}
	public void setMeshes(Mesh[] meshes) /// ditto
	{	this.meshes = meshes;		
	}
	
	/**
	 * These functions allow modifying the vertex attributes of the geometry. 
	 * Example:
	 * --------
	 * if (!geom.hasAttribute(Geometry.VERTICES))
	 *     geom.setAttribute(Geometry.VERTICES, new VertexBuffer(!Vec3f));
	 * --------
	 */
	public IVertexBuffer[char[]] getAttributes()
	{	return attributes;
	}
	public IVertexBuffer getAttribute(char[] name) /// ditto
	{	return attributes[name];		
	}
	public void setAttribute(char[] name, IVertexBuffer vb) /// ditto
	{	if (name in attributes) // prevent creation of a new VBO.
		{	// vb.setId(attributes[name].getId());
		
		}
		attributes[name] = vb;
	}
	public void setAttributeData(T)(char[] name, T[] data) /// ditto
	{	VertexBuffer!(T) vb = new VertexBuffer!(T);
		vb.setData(data);
		setAttribute(name, vb);
	}
	public bool hasAttribute(char[] name) /// ditto
	{	return cast(bool)(name in attributes);		
	}
	public void clearAttribute(char[] name) /// ditto
	{	attributes.remove(name);		
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
}
