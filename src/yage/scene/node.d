/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.node;

import std.stdio;
import yage.core.all;
import yage.core.tree;
import yage.scene.scene;
import yage.scene.all;

/**
 * Nodes are used for building scene graphs in Yage.
 * Every node has an array of child nodes as well as a parent node, with
 * the exception of a Scene that exists at the top of the scene graph and has no parent.  
 * When one node is moved or rotated, all of its child nodes move and rotate as well.
 * Likewise, setting the position or rotation of a node does so relative to its parent.  
 * Rendering is done recursively from the Scene down through every child node.  
 * Likewise, updating of position and rotation occurs recursively from Scene's update() method.
 * 
 * All other Nodes extend this class.
 * Methods for modifying the hierarchy of Nodes (parents, children) are defined here.
 *  
 * Example:
 * --------
 * Scene s = new Scene();
 * ModelNode a = s.addChild(new ModelNode());   // a is a child of s, it exists in Scene s.
 * a.setPosition(3, 5, 0);           // Position is set relative to 0, 0, 0 of the entire scene.
 * a.setRotation(0, 3.14, 0);        // a is rotated PI radians (180 degrees) around the Y axis.
 *
 * SpriteNode b = new SpriteNode(a); // b is a child of a, therefore,
 * b.setPosition(5, 0, 0);           // its positoin and rotation are relative to a's.
 * b.getAbsolutePosition();          // Returns Vec3f(-2, 5, 0), b's position relative to the origin.
 *
 * s.addChild(b);                    // b is now a child of s.
 * b.getAbsolutePosition();          // Returns Vec3f(5, 0, 0), since it's position is relative
 *                                   // to 0, 0, 0, instead of a.
 * --------
 */
abstract class Node : Tree!(Node), IFinalizable 
{
	// These are public for easy internal access.
	Scene	scene;			// The Scene that this node belongs to.
	protected float lifetime = float.infinity;	// in seconds
	protected void delegate(Node self) on_update = null;	// called on update
	
	protected Matrix	transform;				// The position and rotation of this node relative to its parent
	protected Matrix	transform_abs;			// The position and rotation of this node in worldspace coordinates
	public bool			transform_dirty=true;	// The absolute transformation matrix needs to be recalculated.

	protected Vec3f		linear_velocity;
	protected Vec3f		angular_velocity;
	protected Vec3f		linear_velocity_abs;	// Store a cached version of the absolute linear velocity.
	protected Vec3f		angular_velocity_abs;
	protected bool		velocity_dirty=true;	// The absolute velocity vectors need to be recalculated.
	
	protected Object	transform_mutex;

	// Rendering and scene-graph updates run in different threads.
	// If the scene is rendered halfway through updating, rendering glitches may occur.
	// Therefore, the scene-graph implements a sort of "triple buffering".
	// Each node has three extra copies of its relative and absolute transform matrices.
	// The renderer simply uses the copy (buffer) that isn't being updated.  A third copy
	// exists so neither the renderer or updater need to wait on one another.
	struct Cache
	{	Matrix transform;
		Matrix transform_abs;
	}
	protected Cache cache[3];

	/// Constructor
	this()
	{	transform_mutex = new Object();		
	}
	
	/**
	 * Add a child Node to this Node's array of children.
	 * Overridden to call ancestorChange() and mark transformation matrices dirty.
	 * Params:
	 *     child = The Node to add.
	 * Returns: The child Node that was added.  Templating is used to ensure the return type is exactly the same.*/
	T addChild(T /*: Node*/)(T child)
	{			
		auto old_parent = child.getParent();
		super.addChild(child);
		child.ancestorChange(old_parent); // handles 
		return child;
	}
	
	/**
	 * Remove a child Node to this Node's array of children.
	 * Overridden to call ancestorChange() and mark transformation matrices dirty.
	 * Params:
	 *     child = The Node to remove.
	 * Returns: The child Node that was removed.  Templating is used to ensure the return type is exactly the same.*/
	T removeChild(T/* : Node*/)(T child)
	{	auto old_parent = child.getParent();
		super.removeChild(child);
		child.ancestorChange(old_parent); // sets transform dirty also
		return child;
	}
	
	/**
	 * Make a duplicate of this node, unattached to any parent Node.
	 * Params:
	 *     children = recursively clone children (and descendants) and add them as children to the new Node.
	 * Returns: The cloned Node. */
	Node clone(bool children=false)
	{
		Node result = cast(Node)this.classinfo.create();		
		
		// Since "this" may have its properties changed by other calls during this process.
		synchronized(this) 
		{	result.lifetime = lifetime;
			result.transform = transform;
			result.linear_velocity = linear_velocity;
			result.angular_velocity = angular_velocity;
			result.linear_velocity_abs = linear_velocity_abs;
			result.angular_velocity_abs = angular_velocity_abs;
			result.cache[0..3] = cache[0..3];
			
			if (children)
				foreach (c; this.children)
					result.addChild(c.clone());
		}
		
		return result;
	}
	unittest
	{	// Test child cloning
		auto a = new VisibleNode();
		a.addChild(new VisibleNode());
		auto b = a.clone(true);
		assert(b.getChildren().length == 1);
		assert(b.getChildren()[0] != a.getChildren()[0]); // should not be equal, should've been cloned.
	}
	
	/**
	 * Some types of Nodes may need to free resources before being destructed. */
	void finalize()
	{	foreach (c; children)
			c.finalize();
	}
	

	/**
	 * Get / set the lifeime of a Node (in seconds).
	 * The default lifetime is float.infinity.  A lower number will cause the Node to be removed
	 * from the scene graph after that amount of time.  
	 * It's lifetime is decreased every time update() is called (usually by the Node's scene).*/	
	float getLifetime() 
	{	return lifetime; 
	}
	void setLifetime(float seconds)  /// ditto
	{	lifetime = seconds; 
	}
	
	/// Get the Scene at the top of the tree that this node belongs to, or null if this is part of a scene-less node tree.
	Scene getScene()
	{	return scene;
	}

	/// Get the type of this Node as a string; i.e. "yage.scene.visible.ModelNode".
	char[] getType()
	{	return this.classinfo.name;
	}
	
	/// Always returns false for Nodes but can be true for subtypes.
	bool getVisible()
	{	return false;		
	}

	/**
	 * Return a string representation of this Node for human reading. */	
	override char[] toString()
	{	return swritef("<%s children=\"%d\"/>", getType(), children.length);
	}
	
	/**
	 * Set a function that will be called every time this Node is updated.
	 * Specifically, the supplied function is called after a Node's matrices
	 * are updated and before its children are updated and before it's removed if
	 * it's lifetime is zero.
	 * Params:
	 * on_update = the function that will be called.  Use null as an argument to clear
	 * the function.
	 * 
	 * Example:
	 * --------------------------------
	 * SpriteNode s = new SpriteNode(scene);
	 * s.setMaterial("something.xml");
	 *
	 * // Gradually fade to transparent as lifetime decreases.
	 * void fade(Node self)
	 * {   SpriteNode node = cast(SpriteNode)self;
	 *     node.setColor(1, 1, 1, node.getLifetime()/5);
	 * }
	 * s.setLifetime(5);
	 * s.onUpdate(&fade);
	 * --------------------------------*/
	void onUpdate(void delegate(typeof(this) self) on_update)
	{	this.on_update = on_update;
	}

	/**
	 * Update the positions and rotations of this Node and all children by delta seconds.*/ 
	void update(float delta)
	{	
		// Cache the current relative and absolute position/rotation for rendering.
		// This prevents rendering a halfway-updated scenegraph.
		if (scene)
		{	cache[scene.transform_write].transform = transform;
			if (transform_dirty)
				calcTransform();
			cache[scene.transform_write].transform_abs = transform_abs;
		}
		// Call the onUpdate() function
		if (on_update !is null)
			on_update(this);
		
		lifetime-= delta;
		if (lifetime <= 0)
		{	if (parent)
				parent.removeChild(this);
			lifetime = float.infinity;
		}

		// We iterate in reverse in case a child deletes itself.
		// What about one child deleting another?
		// I guess the preferred way to remove an object would be to set its lifetime to 0.
		// Perhaps we should override remove to do this so that items are removed in a controlled way?
		foreach(Node c; children)
			if (c) // does this solve the problem above?
				c.update(delta);
	}
	
	/*
	 * Set the transform_dirty flag on this Node and all of its children, if they're not dirty already.
	 * This should be called whenever a Node has its transformation matrix changed.
	 * This function is used internally by the engine usually doesn't need to be called manually. */
	void setTransformDirty()
	{	if (!transform_dirty)
		{	transform_dirty=true;
			foreach(c; children)
				c.setTransformDirty();
	}	}
	
	/*
	 * Calculate and store the absolute transformation matrices of this Node up to the first node
	 * that has a correct absolute transformation matrix.
	 * This is called automatically when the absolute transformation matrix of a node is needed.
	 * Remember that rotating a Node's parent will change the Node's velocity. */
	protected void calcTransform()
	{
		if (transform_dirty)
		{	//synchronized(this) // still causes deadlock
			{	if (parent)
				{	//synchronized(this.parent) // still causes deadlock.
					{	parent.calcTransform();
						transform_abs = transform * parent.transform_abs;						
				}	}
				else
					transform_abs = transform;
				transform_dirty = false;
		}	}
	}
	unittest
	{	// Ensure absolute position is calculated properly in a node heirarchy.
		MovableNode a = new MovableNode();
		a.setPosition(Vec3f(0, 1, 0));
		MovableNode b = a.addChild(new MovableNode());
		b.setPosition(Vec3f(0, 2, 0));		
		assert(b.getAbsolutePosition() == Vec3f(0, 3, 0));
	}

	/*
	 * Called after any of a node's ancestors have their parent changed. 
	 * This function also sets transform_dirty.  
	 * Yes, this is a side-effect,  but it increases performance in cases where both need to be called, 
	 * since the transformation matrix should always be dirty after an ancestor change. 
	 * @param old_ancestor The ancestor that was previously one above the top node of the tree that had its parent changed. */
	protected void ancestorChange(Node old_ancestor)
	{	// synchronized(this) // causes deadlock with calcTransform.
		{	transform_dirty = true;
			scene = parent ? parent.scene : null;
			foreach(c; children)
				c.ancestorChange(old_ancestor);
		}
	}
}
