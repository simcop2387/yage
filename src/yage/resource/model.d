 /**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.model;

import tango.stdc.math : fmod;
import tango.math.Math;

import yage.core.math.quatrn;
import yage.core.math.matrix;
import yage.core.math.vector;
import yage.core.object2;
import yage.resource.collada;
import yage.resource.geometry;
import yage.resource.material;
import yage.resource.manager;
import yage.system.log;

///
struct KeyFrame
{	float time;
	Vec3f value;
};

///
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
};


/**
 * A Model is a 3D object, often loaded from a file.
 *
 * Each model is divided into one or more Meshes; each Mesh has its own material
 * and an array of triangle indices that correspond to vertices in the Model's vertex array.  
 * ModelNodes can be used to create 3D models in a scene.*/
class Model : Geometry
{	
	private char[] source;

	protected float fps=24;
	protected bool animated = false;
	protected double animation_time=-1;
	protected double animation_max_time=0;
	protected Joint[] joints; // used for skeletal animation
	protected int[] joint_indices;

	/// Instantiate an empty model.
	this()
	{	
	}

	/// Instantiate and and load the given model file.
	this (char[] filename)
	{	this();		
		source = ResourceManager.resolvePath(filename);
		auto c = ResourceManager.collada(filename);
		auto geometry = c.getMergedGeometry();
		
		this.attributes = geometry.attributes;
		this.meshes = geometry.meshes;
		delete geometry;
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
		if (!getAttribute(Geometry.VERTICES))
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
				prev = joint.rotations[i-1].value.toQuatrnEuler();
				next = joint.rotations[i].value.toQuatrnEuler();
				Quatrn finl = prev.slerp(next, fraction);
												
				m_frame.setRotation(finl);
			} else if (i==0)
				m_frame.setRotationEuler(joint.rotations[0].value);
			else // i==joints.rotations.length
				m_frame.setRotationEuler(joint.rotations[length].value);
			
			m_rel.setRotationEuler(joint.startRotation); 
			m_rel.v[12..15] = joint.startPosition.v[0..3];			
			m_rel = m_frame*m_rel;
			
			if (!joint.parent)
				joint.transformAbs = m_rel;
			else
				joint.transformAbs = m_rel * joint.parent.transformAbs;					
		}
		
		// Update vertex positions based on joints.
		Vec3f[] vertices = cast(Vec3f[])getAttribute(Geometry.VERTICES);
		Vec3f[] vertices_original =  cast(Vec3f[])getAttribute("gl_VertexOriginal");
		
		Vec3f[] normals;
		Vec3f[] normals_original;
		if (getAttribute("gl_Normal"))
		{	normals =  cast(Vec3f[])getAttribute(Geometry.NORMALS);
			normals_original =  cast(Vec3f[])getAttribute("gl_NormalOriginal");		
		}
		for (int v=0; v<vertices.length; v++)
		{	if (joint_indices[v] != -1)
			{	
				Matrix cmatx = joints[joint_indices[v]].transformAbs; 
				vertices[v] = vertices_original[v].transform(cmatx);				
				
				if (normals.length)
					normals[v] = normals_original[v].rotate(cmatx);
				// TODO: only reassign cmatx if joint_indices[v] has changed.
		}	}
				
		setAttribute(Geometry.VERTICES, vertices);
		if (normals.length)
			setAttribute(Geometry.NORMALS, normals);
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
	
	/// Get the path to the file where the model was loaded.
	char[] getSource()
	{	return source;
	}

}

