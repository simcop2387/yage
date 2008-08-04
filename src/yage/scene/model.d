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
import yage.system.interfaces;
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
	protected bool animation_looping = false;

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

	
	/**
	 * Get the timer used for the skeletal animation of this model.
	 * If the model has no joints and keyframes for skeletal animation, modifying this timer will do nothing.
	 * TODO: Implement a similar interface for SoundNode?
	 * 
	 * See: yage.core.timer
	 * 
	 * Example:
	 * --------------------------------
	 * // Continuously play the model's skeletal animation from 5 to 12 seconds.
	 * Timer t1 = myModel.getAnimationTimer();
	 * t1.setRange(5, 12);
	 * t1.play();
	 * 
	 * // Play the animation from 0 to 60 seconds and then stop.
	 * Timer t2 = myModel.getAnimationTimer();
	 * t2.setRange(0, 60);
	 * t2.pauseAfter(60);
	 * t2.play(); 
	 * --------------------------------
	 */
	Timer getAnimationTimer()
	{	if (!animation_timer)
			animation_timer = new Timer(false);
		return animation_timer;
	}

	
	/// Get / set the 3D model that is being used by this Node.
	Model getModel()
	{	return model;
	}
	void setModel(Model model) /// ditto
	{	this.model = model;
		radius = model.getRadius()*size.max();
	}

	/**
	 * Set the 3D model used by this Node, using the Resource Manager to ensure that no Model is loaded twice.
	 * Equivalent of setModel(Resource.model(filename)); */
	void setModel(char[] filename)
	{	setModel(Resource.model(filename));
	}

	/// Overridden to cache the radius if changed by the scale.
	void setSize(Vec3f s)
	{	super.size = s;
		if (model)
			radius = model.getRadius()*size.max();
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
