/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.model;

import std.gc;
import std.string;
import std.file;
import std.math;
import std.path;
import std.stdio;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.matrix;
import yage.core.misc;
import yage.core.vector;

import yage.resource.material;
import yage.resource.mesh;
import yage.resource.resource;
import yage.node.node;
import yage.system.constant;
import yage.system.device;
import yage.system.log;

import yage.resource.ms3dloader;
import yage.resource.objloader;


/**
 * An array of vertex attribute.
 * Vertex attributes can be vertices themselves, texture coordinates, normals, colors, or anything else.
 * They can be an array of floats, vectors of varying size, or matrices. */
struct Attribute
{	float[]	values;			// Raw data of the attributes
	ubyte	width;			// Number of floats to use for each vertex.
	uint	vbo;		
	bool	cached = false; // Are the values of this attribute cached in video memory?

	/// Get the values of this attribute as an array of Vec3f
	Vec3f[] vec3f()
	{	return (cast(Vec3f*)values.ptr)[0..values.length/3];
	}

	/// Get the values of this attribute as an array of Vec3f
	Vec2f[] vec2f()
	{	return (cast(Vec2f*)values.ptr)[0..values.length/2];
	}
}

/**
 * A Model is a 3D object, typically loaded from a file.
 *
 * Each model is divided into one or more Meshes; each Mesh has its own material
 * and an array of triangle indices that correspond to vertices in the Model's vertex array.  
 * ModelNodes can be used to create 3D models in a scene.*/
class Model
{	
	protected char[] source;
	protected Mesh[] meshes;
	protected Attribute[char[]] attributes;	// An associative array to store as many attributes as necessary

	mixin Ms3dLoader;
	mixin ObjLoader;

	/// Generate buffers in video memory for the vertex data.
	this()
	{	Attribute a;
		attributes["gl_Vertex"] = a;
		attributes["gl_TexCoord"] = a;
		attributes["gl_Normal"] = a;
		
		if (Device.getSupport(DEVICE_VBO))
		{	glGenBuffersARB(1, &attributes["gl_Vertex"].vbo);	
			glGenBuffersARB(1, &attributes["gl_TexCoord"].vbo);
			glGenBuffersARB(1, &attributes["gl_Normal"].vbo);			
		}
	}

	/// Generate buffers and load and upload the given model file.
	this (char[] filename)
	{	this();
		load(filename);
	}

	/// Create as an exact duplicate of another Model.
	this (Model model)
	{	this();
		source = model.source.dup;
		foreach (name, attrib; model.attributes)
		{	setAttribute(name, attrib.values);
			attributes[name].width = attrib.width;			
		}		
		Mesh[] lhs;
		foreach (Mesh m; model.getMeshes)
			lhs[]= (new Mesh(m));
		setMeshes(lhs);
	}

	/// Remove the model's vertex data from video memory.
	~this()
	{	if (source.length)
			Log.write("Removing model '" ~ source ~ "'.");
		foreach (name, attrib; attributes)
			clearAttribute(name);
	}

	/// This can only be called before upload()

	/// Bind the Vertex, Texture, and Normal VBO's for use.
	void bind()
	{	foreach (name, attrib; attributes)
		{	switch (name)
			{	case "gl_Vertex":
					if (attrib.cached)
					{	glBindBufferARB(GL_ARRAY_BUFFER_ARB, attrib.vbo);
						glVertexPointer(3, GL_FLOAT, 0, null);					
					} else
						glVertexPointer(3, GL_FLOAT, 0, attrib.vec3f.ptr);
					break;
				
				case "gl_TexCoord":
					if (attrib.cached)
					{	glBindBufferARB(GL_ARRAY_BUFFER_ARB, attrib.vbo);
						glTexCoordPointer(2, GL_FLOAT, 0, null);		
					} else
						glTexCoordPointer(2, GL_FLOAT, 0, attrib.vec2f.ptr);				
					break;
				case "gl_Normal":
					if (attrib.cached)
					{	glBindBufferARB(GL_ARRAY_BUFFER_ARB, attrib.vbo);
						glNormalPointer(GL_FLOAT, 0, null);
					} else
						glNormalPointer(GL_FLOAT, 0, attrib.vec3f.ptr);
					break;
				default:					
			}			
		}
	}

	/// Clear an attribute.
	void clearAttribute(char[] name)
	{	if (name in attributes)
		{	if (attributes[name].cached)
				glDeleteBuffersARB(1, &attributes[name].vbo);
			attributes.remove(name);
		}
	}
	
	/// Get an associative array of all attributes.  The index is the attribute name.
	Attribute[char[]] getAttributes()
	{	return attributes;
	}
	
	///
	Attribute getAttribute(char[] name)
	{	return attributes[name];
	}

	/// Get the dimensions of a box, centered at the origin, that can contain this Model.
	Vec3f getDimensions()
	{	Vec3f result;
		foreach (Vec3f v; getAttribute("gl_Vertex").vec3f)
		{	if (abs(v.x) > result.x) result.x=v.x;
			if (abs(v.y) > result.y) result.y=v.y;
			if (abs(v.z) > result.z) result.z=v.z;
		}
		return result;
	}

	/// Get the array of meshes that compose this model.
	Mesh[] getMeshes()
	{	return meshes;
	}

	///
	bool hasAttribute(char[] name)
	{	return cast(bool)(name in attributes);
	}

	/// Get the path to the file where the model was loaded.
	char[] getSource()
	{	return source;
	}

	/// Load vertex, mesh, and material data from a 3D model file.
	void load(char[] filename)
	{	char[] ext = getExt(filename);
		switch (tolower(ext))
		{	case "ms3d":
				loadMs3d(filename);
				break;
			case "obj":
				loadObj(filename);
				fullCollect();
				break;
			default:
				throw new Exception("Unrecognized file format '"~ext~"'.");
		}
	}

	/**
	 * Set the Meshes used by this model. */
	void setMeshes(Mesh[] meshes)
	{	this.meshes = meshes;
	}
	
	/**
	 * Set a per-vertex attribute for this Model.
	 * Attributes can be accessed by OpenGl vertex shaders.
	 * If an attribute is defined for this model, and a mesh of this model has
	 * a material with a shader that has an attribute variable of the same name,
	 * the values of the attribute will be bound automaticallyat runtime and can
	 * then be accessed by the shader.
	 * Params:
	 * name = the name of the attribute, should be the same as the attribute
	 * variable name in the vertex shader.
	 * values = an array of values; should be the same length as the number of
	 * vertices for the model.*/
	void setAttribute(char[] name, float[] values)
	{	setAttribute(name, values, 1);
	}

	/// ditto
	void setAttribute(char[] name, Vec2f[] values)
	{	float[] arg = (cast(float*)&values[0].v)[0..values.length*2];
		setAttribute(name, arg, 2);
	}

	/// ditto
	void setAttribute(char[] name, Vec3f[] values)
	{	float[] arg = (cast(float*)&values[0].v)[0..values.length*3];
		setAttribute(name, arg, 3);
	}

	/**
	 * Return a string representation of this Model and all of its data. */
	char[] toString()
	{	char[] result;
		result ~= "Model:  '"~source~"'\n";
		return result;
	}

	// Used by the other setAttribute functions.
	private void setAttribute(char[] name, float[] values, int width)
	{	
		if (!(name in attributes))
		{	Attribute a;
			attributes[name] = a;
			if (Device.getSupport(DEVICE_VBO))
				glGenBuffersARB(1, &attributes[name].vbo);
		}

		attributes[name].values = values;
		attributes[name].width = width;

		if (Device.getSupport(DEVICE_VBO))
		{	glBindBufferARB(GL_ARRAY_BUFFER_ARB, attributes[name].vbo);
			glBufferDataARB(GL_ARRAY_BUFFER_ARB, attributes[name].values.length*float.sizeof, attributes[name].values.ptr, GL_STATIC_DRAW);
			//glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);
			attributes[name].cached = true;
		}
	}
}
