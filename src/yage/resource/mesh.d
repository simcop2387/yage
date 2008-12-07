/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.mesh;

import std.stdio;
import std.string;
import yage.core.vector;

import yage.resource.manager;
import yage.resource.material;
import yage.resource.resource;
import yage.resource.vertexbuffer;
import yage.system.probe;

/**
 * Models are divided into one or more meshes.
 * Each mesh has its own material and an array of triangle indices that index into its models vertex array. */
class Mesh : Resource
{	protected Vec3i[]		triangles;
	protected VertexBuffer	vbo_triangles;
	protected Material		material;

	///
	this()
	{	
	}

	/// Create as an exact duplicate of another Mesh.
	this(Mesh mesh)
	{	triangles = mesh.triangles.dup;
		material = mesh.material;
	}

	/// Create with a material and triangles.
	this(Material matl, Vec3i[] triangles)
	{	setMaterial(matl);
		setTriangles(triangles);
	}
	
	/// Call finalize on destruction.
	~this()
	{	finalize();
	}	
	
	/// Overridden to clean up the triangles vertex buffer.
	override void finalize()
	{	if (vbo_triangles.getId()) // Segfault here!
			vbo_triangles.finalize();
	}

	/**
	 * Get/set the triangles of this mesh.  Each triangle contains
	 * three vertex indicies from the vertex arrays in the containing Model.
	 * When setting, an OpenGL VBO is created automatially if supported by hardware. */
	Vec3i[] getTriangles()
	{	return triangles;
	}
	void setTriangles(Vec3i[] triangles) /// ditto
	{	this.triangles = triangles;
		vbo_triangles.create(VertexBuffer.Type.GL_ELEMENT_ARRAY_BUFFER_ARB, cast(float[])triangles);
	}
	
	/**
	 * Get the OpenGL Vertex Buffer Object id of the triangles array, or 0 if it doesn't exist. */
	uint getTrianglesVBO()
	{	return vbo_triangles.getId();
	}

	/// Get/set the Material assigned to this Mesh.
	Material getMaterial()
	{	return material;
	}
	void setMaterial(Material matl) /// ditto
	{	this.material = matl;
	}
	void setMaterial(char[] filename) /// ditto
	{	this.material = ResourceManager.material(filename);
	}


	/// Return a string representation of this Mesh and its data.
	char[] toString()
	{	char[] result;
		result ~= "Mesh\n";
		result ~= "Material: '"~material.getSource()~"'";
		result ~= .toString(triangles.length)~" triangles\n";
		//foreach (Vec3i t; triangles)
		//	result ~= t.toString();

		return result;
	}
}
