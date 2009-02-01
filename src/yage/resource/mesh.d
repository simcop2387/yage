/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.mesh;

import std.stdio;
import std.string;
import yage.core.vector;

import yage.core.interfaces;
import yage.resource.manager;
import yage.resource.material;
import yage.resource.resource;
import yage.resource.vertexbuffer;

/**
 * Models are divided into one or more meshes.
 * Each mesh has its own material and an array of triangle indices that index into its models vertex array. */
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
	 * Get / set the triangles */
	VertexBuffer!(Vec3i) getTriangles()
	{	return triangles;
	}
	void setTriangles(VertexBuffer!(Vec3i) triangles) /// ditto
	{	this.triangles = triangles;
	}
	void setTriangles(Vec3i[] triangles) /// ditto
	{	this.triangles.setData(triangles);
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
}
