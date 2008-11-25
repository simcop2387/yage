/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.mesh;

import std.stdio;
import std.string;
import yage.core.vector;

import yage.resource.material;
import yage.resource.manager;
import yage.resource.resource;
import yage.resource.lazyresource;
import yage.system.probe;

/**
 * Models are divided into one or more meshes.
 * Each mesh has its own material and an array of triangle indices.
 * The triangle indicices index into an array of vertices in a parent Model. */
class Mesh : Resource
{	protected Vec3i[]		triangles;
	protected LazyVBO		vbo_triangles;
	protected Material		material;

	///
	this()
	{	
	}

	/// Create as an exact duplicate of another Mesh.
	this(Mesh mesh)
	{	this();
		triangles = mesh.triangles.dup;
		material = mesh.material;
	}

	/// Create with a material and triangles.
	this(Material matl, Vec3i[] triangles)
	{	this();
		setMaterial(matl);
		setTriangles(triangles);
	}
	
	void finalize()
	{	vbo_triangles.destroy();		
	}
	
	/// Get the array of triangle indices that define this Mesh.
	Vec3i[] getTriangles()
	{	return triangles;
	}

	/// Get the OpenGL Vertex Buffer Object index for the triangles indices.
	uint getTrianglesVBO()
	{	return vbo_triangles.getId();
	}

	/// Get the Material assigned to this Mesh.
	Material getMaterial()
	{	return material;
	}

	/// Set the Material of this Mesh.
	void setMaterial(Material matl)
	{	this.material = matl;
	}
	
	/// Ditto
	void setMaterial(char[] filename)
	{	this.material = ResourceManager.material(filename);
	}

	/**
	 * Set the triangles of this mesh.  Each triangle contains
	 * three vertex indicies from the vertex arrays in the containing Model.*/
	void setTriangles(Vec3i[] triangles){
		this.triangles = triangles;		
		if (Probe.openGL(Probe.OpenGL.VBO))
		{	vbo_triangles.create(LazyVBO.Type.GL_ELEMENT_ARRAY_BUFFER_ARB, cast(float[])triangles);		
		}
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
