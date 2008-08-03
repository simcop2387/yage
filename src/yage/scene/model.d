/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.model;

import yage.core.timer;
import yage.core.vector;
import yage.system.device;
import yage.system.log;
import yage.resource.resource;
import yage.resource.model;
import yage.resource.material;
import yage.scene.visible;
import yage.scene.node;


/// A node used for rendering a 3D model.
class ModelNode : VisibleNode
{
	protected Model model;	// The 3D model used by this node
	protected float radius=0;	// cached radius
	
	protected Timer animation_timer;

	/// Construct this Node as a child of parent.
	this(Node parent)
	{	super(parent);
	}	

	/**
	 * Construct this Node as a copy of another Node and recursively copy all children.
	 * Params:
	 * parent = This Node will be a child of parent.
	 * original = This Node will be an exact copy of original.*/
	this (Node parent, ModelNode original)
	{	super(parent, original);
		model = original.model;
		radius = original.radius;
	}

	
	void setAnimation(float from, float to, bool looping=true)
	{	if (!animation_timer)
			animation_timer = new Timer();
		
	}
	
	/// Alias of setPaused(false);
	void play()
	{	if (!animation_timer)
			animation_timer = new Timer();
	}

	/// Alias of setPaused(true);
	void pause()
	{	if (!animation_timer)
			animation_timer = new Timer();
	}

	/** Seek to the position in the track.  Seek has a precision of .05 seconds.
	 *  seek() throws an exception if the value is outside the range of the Sound. */
	void seek(double seconds)
	{	if (!animation_timer)
			animation_timer = new Timer();
	}

	/// Tell the position of the playback of the current sound file, in seconds.
	double tell()
	{	if (!animation_timer)
			animation_timer = new Timer();
		return 1.0;
	}

	/// Stop the SoundNode from playing and rewind it to the beginning.
	void stop()
	{	if (!animation_timer)
			animation_timer = new Timer();
	}

	
	
	/// Get / set the 3D model that is being used by this Node.
	Model getModel()
	{	return model;
	}
	void setModel(Model model) /// ditto
	{	this.model = model;
		radius = model.getDimensions().scale(size).length();
	}

	/**
	 * Set the 3D model used by this Node, using the Resource Manager to ensure that no Model is loaded twice.
	 * Equivalent of setModel(Resource.model(filename)); */
	void setModel(char[] filename)
	{	setModel(Resource.model(filename));
	}

	/// Overridden to cache the radius if changed by the scale.
	void setSize(Vec3f s)
	{	super.size = Vec3f(s.x, s.y, s.z);
		if (model)
			radius = model.getDimensions().scale(size).max();
	}	
	Vec3f getSize() /// Ditto
	{	return super.size;		
	}


	/**
	 * Get the radius of the culling sphere used when rendering the 3D Model
	 * This is usually the distance from the center of its coordinate plane to
	 * the most distant vertex.  There is no setRadius() */
	float getRadius()
	{	return radius;
	}
}
