 /**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.model;

import std.c.math : fmod;
import std.string;
import std.file;
import std.math;
import std.path;
import std.stdio;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.matrix;
import yage.core.misc;
import yage.core.parse;
import yage.core.quatrn;
import yage.core.vector;
import yage.system.exceptions;
import yage.resource.material;
import yage.resource.mesh;
import yage.resource.resource;
import yage.system.log;
import yage.system.probe;
import yage.resource.ms3dloader;
import yage.resource.objloader;
import yage.scene.visible;


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

struct KeyFrame
{	float time;
	Vec3f value;
	
	char[] toString()
	{
		char[] result = formatString(
			"%ss, %s",
			time, value);
		return result;
	}
};

class Joint
{	char[]	name;
	char[]	parentName;
	Joint	parent;				// pointer to parent bone (or null)
	Joint[] children;
	Vec3f	startPosition;
	Vec3f	startRotation;
	Matrix	transform;			// fixed transformation matrix relative to parent 
	Matrix	transformAbs;		// absolute in accordance to animation	
	KeyFrame[] positions;	
	KeyFrame[] rotations;
	
	char[] toString()
	{
		char[] result = formatString(
			"Name: %s\n" ~
			"Parent: %s\n" ~
			"Start Position: %s\n" ~
			"Start Rotation: %s\n",
			name, parentName, startPosition, startRotation);		
		foreach (i, k; positions)		
			result ~= formatString("Position %d: %s\n", i, k.toString());
		foreach (i, k; rotations)		
			result ~= formatString("Rotation %d: %s\n", i, k.toString());
		return result;
	}
};


/**
 * A Model is a 3D object, often loaded from a file.
 *
 * Each model is divided into one or more Meshes; each Mesh has its own material
 * and an array of triangle indices that correspond to vertices in the Model's vertex array.  
 * ModelNodes can be used to create 3D models in a scene.*/
class Model
{	
	protected char[] source;
	protected Mesh[] meshes;
	protected Attribute[char[]] attributes;	// An associative array to store as many attributes as necessary

	protected float fps=24;
	protected bool animated = false;
	protected double animation_time=-1;
	protected double animation_max_time=0;
	protected Joint[] joints; // used for skeletal animation
	protected int[] joint_indices;
	
	mixin Ms3dLoader;
	mixin ObjLoader;

	/// Generate buffers in video memory for the vertex data.
	this()
	{	Attribute a;
		attributes["gl_Vertex"] = a;
		attributes["gl_TexCoord"] = a;
		attributes["gl_Normal"] = a;
		
		if (Probe.openGL(Probe.OpenGL.VBO))
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

	
	
	/**
	 * Advance this Model's animation to time.
	 * This still has bugs somehow.
	 * Params:
	 *     time =
	 */
	void animateTo(double time)
	{
		// If nothing to do.
		if (animation_time == time)
			return;
		
		time = fmod(time, animation_max_time);		
		animation_time = time;
		
		
		// TODO: check time constraints
		int i=0;
		foreach(j, joint; joints)
		{
			float deltatime;	// time between frames	
			float fraction;		// percent between frames
			Matrix m_rel = Matrix();		// relative matx  for this frame
			Matrix m_frame = Matrix();		// final matx for this frame
			
			// Find appropriate position keyframe
			i=0;
			while ((i<joint.positions.length) && (joint.positions[i].time < time))
				i++;
			
			// Interpolate between 2 keyframes
			if (i>0 && i < joint.positions.length)
			{	
				deltatime = joint.positions[i].time - joint.positions[i-1].time;
				fraction = (time - joint.positions[i-1].time) / deltatime;
				assert(fraction > 0 && fraction <= 1);
								
				m_frame.v[12] = joint.positions[i-1].value.x + fraction * (joint.positions[i].value.x - joint.positions[i-1].value.x);
				m_frame.v[13] = joint.positions[i-1].value.y + fraction * (joint.positions[i].value.y - joint.positions[i-1].value.y);
				m_frame.v[14] = joint.positions[i-1].value.z + fraction * (joint.positions[i].value.z - joint.positions[i-1].value.z);
			}
			else if (i==0)
				m_frame.setPosition(joint.positions[0].value);
			else // i==joints.positions.length
				m_frame.setPosition(joint.positions[length].value);
						
			// Find appropriate rotation keyframe
			i=0;
			while ((i<joint.rotations.length) && (joint.rotations[i].time < time))
				i++;
			// Interpolate between 2 keyframes
			if (i>0 && i<joint.rotations.length)
			{	
				deltatime = joint.rotations[i].time - joint.rotations[i-1].time;				
				fraction = (time - joint.rotations[i-1].time) / deltatime;
				assert(fraction > 0 && fraction <= 1);
								
				Quatrn prev, next;
				prev.setEuler(joint.rotations[i-1].value);
				next.setEuler(joint.rotations[i].value);
				Quatrn finl = prev.slerp(next, fraction);
												
				m_frame.setRotation(finl);
			} else if (i==0)
				m_frame.setEuler(joint.rotations[0].value);
			else // i==joints.rotations.length
				m_frame.setEuler(joint.rotations[length].value);
			
			m_rel.setEuler(joint.startRotation); 
			m_rel.v[12..15] = joint.startPosition.v[0..3];			
			m_rel = m_frame*m_rel;
			
			if (!joint.parent)
				joint.transformAbs = m_rel;
			else
				joint.transformAbs = m_rel * joint.parent.transformAbs;					
		}
		
		// Update vertex positions based on joints.
		Vec3f[] vertices = getAttribute("gl_Vertex").vec3f;
		Vec3f[] vertices_original = getAttribute("gl_VertexOriginal").vec3f;
		
		Vec3f[] normals;
		Vec3f[] normals_original;
		if (hasAttribute("gl_Normal"))
		{	normals = getAttribute("gl_Normal").vec3f;
			normals_original = getAttribute("gl_NormalOriginal").vec3f;		
		}
		for (int v=0; v<vertices.length; v++)
		{	if (joint_indices[v] != -1)
			{	
				Matrix cmatx = joints[joint_indices[v]].transformAbs; 
				vertices[v] = vertices_original[v].transform(cmatx);				
				
				if (normals.length)
					normals[v] = normals_original[v].rotate(cmatx);
				// TODO: only reassign cmatx if joint_indices[v] has changed.
			}				
		}
				
		setAttribute("gl_Vertex", vertices);
		if (normals.length)
			setAttribute("gl_Normal", normals);
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
	
	/**
	 * Get the requested attribute.
	 * @throws Exception if the attribute is not defined. */
	Attribute getAttribute(char[] name)
	{	return attributes[name];
	}

	/// Get radius of a sphere, centered at the model's origin, that can contain this Model.
	float getRadius()
	{	float result=0;
		foreach (Vec3f v; getAttribute("gl_Vertex").vec3f)
		{	float length2 = v.length2();
			if (length2 > result)
				result = length2;
		}
		return sqrt(result);
	}

	/**
	 * Get an array of all of the Model's Joints, which are used for skeletal animation.
	 * This can be traversed as an array, or as a tree since each Joint references its parent and children. */
	Joint[] getJoints()
	{	return joints;		
	}
	
	/**
	 * Get whether this model is animated. */
	bool getAnimated()
	{	return animated;		
	}
	
	
	/**
	 * Get the time in seconds of the end of this Model's skeletal animation.*/
	double getAnimationMax()
	{	return animation_max_time;		
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
				//std.gc.genCollect();
				break;
			case "obj":
				loadObj(filename);
				//std.gc.genCollect();
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
	 * name = the name of the attribute, should be the same as the attribute variable name in the vertex shader.
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
	char[] toString(bool detailed=false)
	{	char[] result;
		result ~= "Model:  '"~source~"'\n";

		foreach (j; joints)
			result ~= j.toString();
		
		return result;
	}

	// Used by the other setAttribute functions.
	protected void setAttribute(char[] name, float[] values, int width)
	{		
		if (!(name in attributes))
		{	Attribute a;
			attributes[name] = a;
			if (Probe.openGL(Probe.OpenGL.VBO))
				glGenBuffersARB(1, &attributes[name].vbo);
		}

		attributes[name].values = values;
		attributes[name].width = width;

		if (Probe.openGL(Probe.OpenGL.VBO))
		{	glBindBufferARB(GL_ARRAY_BUFFER_ARB, attributes[name].vbo);
			glBufferDataARB(GL_ARRAY_BUFFER_ARB, attributes[name].values.length*float.sizeof, attributes[name].values.ptr, GL_STATIC_DRAW);
			//glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0); // unbind
			attributes[name].cached = true;
		}
	}
}
