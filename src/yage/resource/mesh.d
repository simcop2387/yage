/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.mesh;

import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.vector;

import yage.resource.material;
import yage.resource.resource;
import yage.system.constant;
import yage.system.device;

/**
 * Models are divided into one or more meshes.
 * Each mesh has its own material and an array of triangle indices.
 * The triangle indicices index into an array of Vertices in the parent Model. */
class Mesh
{	/*protected*/ Vec3i[]	triangles;
	protected uint		vbo_triangles;
	protected Material	material;

	/// Construct and allocate Opengl buffer.
	this()
	{	if (Device.getSupport(DEVICE_VBO))
			glGenBuffersARB(1, &vbo_triangles);
	}

	/// Cleanup Opengl buffer if necessary.
	~this()
	{	if (Device.getSupport(DEVICE_VBO))
			glDeleteBuffersARB(triangles.length*Vec3i.sizeof, &vbo_triangles);
	}

	/// Add three vertex indices (that define a Triangle) to this Mesh.
	void addTriangle(Vec3i t)
	{	triangles ~= t;
	}

	/// Get the array of triangle indices that define this Mesh.
	Vec3i[] getTriangles()
	{	return triangles;
	}

	/// Get the OpenGL Vertex Buffer Object index for the triangles indices.
	uint getTrianglesVBO()
	{	return vbo_triangles;
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
	{	this.material = Resource.material(filename);
	}
}
