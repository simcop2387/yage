/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.model;

import yage.core.timer;
import yage.core.vector;
import yage.system.system;
import yage.system.log;
import yage.resource.manager;
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
	
	double last_time;
	
	/**
	 * Create a ModelNode and optionally set the model from an already loaded model or a model filename. */
	this()
	{	super();
	}
	this(Model model) /// ditto
	{	this();
		setModel(model);
	}	
	this(char[] filename) /// ditto
	{	this();
		setModel(filename);
	}
	
	
	/**
	 * Call this function from onUpdate when the model's current animation completes.
	 * The animation is considered complete when the animation timer reachers its pauseAfter value
	 * or if a range is set and it loops. */
	void delegate(ModelNode self) onAnimationComplete = null; 

	/**
	 * Make a duplicate of this node, unattached to any parent Node.
	 * Animation is not yet cloned since its current implementation may soon change.
	 * Params:
	 *     children = recursively clone children (and descendants) and add them as children to the new Node.
	 * Returns: The cloned Node. */
	override ModelNode clone(bool children=false)
	{	auto result = cast(ModelNode)super.clone(children);
		result.model = model; // atomic
		result.radius = radius;
		return result;
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
	 * t1.set(5);
	 * t1.play();
	 * 
	 * // Play the animation from 3 to 5 once and then loop the animation from 5 to 12.
	 * Timer t1 = myModel.getAnimationTimer();
	 * t1.setRange(3, 5);
	 * t1.setPauseAfter(5);
	 * t1.set(3);
	 * t1.play();
	 * myModel.onAnimationComplete = (ModelNode self) {
	 * 	Timer t1 = self.getAnimationTimer();
	 *  t1.setRange(5, 12);
	 * 	t1.set(5);
	 * 	t1.setPauseAfter(); // clear pauseAfter
	 * };
	 * --------------------------------
	 */
	Timer getAnimationTimer()
	{	if (!animation_timer)
			animation_timer = new Timer(false);
		return animation_timer;
	}
	
	// TODO: Rewrite this to use scene's timer, so that animation is sync'd with scene's timer.
	void animationPlayOnce(float start, float end)
	{	Timer t1 = getAnimationTimer();
		t1.setRange(start, end);
		t1.set(start);
		t1.setPauseAfter(end);
		t1.play();
	}
	
	void animationPlayLoop(float start, float end)
	{	Timer t1 = getAnimationTimer();
		t1.setRange(start, end);
		t1.set(start);
		t1.play();
	}	
	
	/**
	 * Get / set the 3D model used by this Node.
	 * If a filename is passed, the ResourceManager Manager will ensure that no Model is loaded twice.
	 * If no argument is passed to setModel(), the model will be cleared.
	 * Equivalent of setModel(ResourceManager.model(filename)); */
	Model getModel()
	{	return model;
	}
	void setModel(Model model=null) /// ditto
	{	this.model = model;
		if (model)
			radius = model.getRadius()*size.max();
		else
			radius = 0;
	}	
	void setModel(char[] filename) /// ditto
	{	setModel(ResourceManager.model(filename));
	}

	/// Overridden to cache the radius if changed by the scale.
	override void setSize(Vec3f s) /// Ditto
	{	super.setSize(s);
		if (model)
			radius = model.getRadius()*size.max();
	}	
	
	/**
	 * Get the radius of the culling sphere used when rendering the 3D Model
	 * This is usually the distance from the center of its coordinate plane to
	 * the most distant vertex.  There is no setRadius() */
	float getRadius()
	{	return radius;
	}

	/*
	 * This function is called automatically as a Scene's update() function recurses through Nodes.
	 * It normally doesn't need to be called manually.*/
	void update(float delta)
	{	
		// Call animationComplete if an animation has completed.
		if (onAnimationComplete && animation_timer)
		{	last_time = animation_timer.tell();
			double time = animation_timer.get();
			if (time == animation_timer.getPauseAfter() || last_time > time)
			{	onAnimationComplete(this);
				//onAnimationComplete = null;
				// TODO: Prevent onAnimationComplete from playing over and over again.
			}
		}

		// Recurse through children
		super.update(delta);
	}

}
