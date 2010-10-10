/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.node;

import tango.core.Thread;
import tango.text.convert.Format;
import yage.core.all;
import yage.core.tree;
import yage.scene.scene;
import yage.scene.all;
import yage.system.log;

/// Add this as the first line of a function to synchronize the entire body using the name of a Tango mutex.
template Sync(char[] T)
{	const char[] Sync = "if ("~T~") { "~T~".lock(); scope(exit) " ~ T ~ ".unlock(); }";	
}

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
class Node : Tree!(Node), IDisposable, ICloneable
{
	// New
	protected Vec3f position;
	protected Vec3f rotation;
	protected Vec3f scale = Vec3f(1);
	
	protected Vec3f velocity;
	protected Vec3f angularVelocity;
	
	protected Vec3f worldPosition;
	protected Vec3f worldRotation;
	protected Vec3f worldScale;
	
	/**
	 * Get / set the xyz position of this Node relative to its parent's position. */
	Vec3f getPosition2()
	{	mixin(Sync!("scene"));
		return position;
	}	
	void setPosition2(Vec3f position) /// ditto
	{	mixin(Sync!("scene"));
		this.position = position;
	}
	
	/**
	 * Get / set the rotation of this Node (as an axis-angle vector) relative to its parent's rotation. */
	Vec3f getRotation2()
	{	mixin(Sync!("scene"));
		return rotation;
	}	
	void setRotation2(Vec3f rotation) /// ditto
	{	mixin(Sync!("scene"));
		this.rotation = rotation;
	}
	
	/**
	 * Get / set the xyz scale of this Node relative to its parent's scale. */
	Vec3f getScale2()
	{	mixin(Sync!("scene"));
		return scale;
	}	
	void setScale2(Vec3f scale) /// ditto
	{	mixin(Sync!("scene"));
		this.scale = scale;
	}

	
	/**
	 * Get / set the linear velocity this Node relative to its parent's velocity. */
	Vec3f getVelocity2()
	{	mixin(Sync!("scene"));
		return velocity;
	}	
	void setVelocit2(Vec3f velocity) /// ditto
	{	mixin(Sync!("scene"));
		this.velocity = velocity;
	}
	
	/**
	 * Get / set the angular (rotation) velocity this Node relative to its parent's velocity. */
	Vec3f getAngularVelocity2()
	{	mixin(Sync!("scene"));
		return velocity;
	}	
	void setAngularVelocity2(Vec3f axis) /// ditto
	{	mixin(Sync!("scene"));
		this.angularVelocity = axis;
	}
	
	Matrix getMatrix2()
	{	return Matrix.compose(position, rotation, scale);
	}
	
	/**
	 * Get the position, axis-angle rotation, or scale in world coordinates, 
	 * instead of relative to the parent Node. */
	Vec3f getWorldPosition()
	{	mixin(Sync!("scene"));
		return getWorldMatrix().getPosition(); // TODO: optimize
	}
	Vec3f getWorldRotation() /// ditto
	{	mixin(Sync!("scene"));
		return getWorldMatrix().toAxis();
	}
	Vec3f getWorldScale() /// ditto
	{	mixin(Sync!("scene"));
		return getWorldMatrix().getScale();
	}
	
	// Temporary until I have something more optimized
	Matrix getWorldMatrix()
	{	mixin(Sync!("scene"));
		
		if (parent) // TODO and if parent isn't scene?
			return parent.getWorldMatrix().transformAffine(getMatrix2());		
		return getMatrix2();
	}	
	unittest
	{
		Node a = new Node();
		a.setRotation2(Vec3f(0, 3.1415927, 0));
		a.setPosition2(Vec3f(3, 0, 0));
		
		Node b = new Node(a);
		b.setPosition2(Vec3f(5, 0, 0));
		assert(b.getWorldPosition().almostEqual(Vec3f(-2, 0, 0)));
	}

	void update2(float delta)
	{	mixin(Sync!("scene"));
		
		foreach (node; children)
			node.update2(delta);
	}
	
	

	// old:
	// ---------------------------------------------
	
	// These are public for easy internal access.
	Scene	scene;			// The Scene that this node belongs to.
	protected float lifetime = float.infinity;	// in seconds
	
	void delegate() onUpdate = null;	// Set a function that will be called every time this Node is updated.
	
	protected Matrix	transform;				// The position and rotation of this node relative to its parent
	protected Matrix	transform_abs;			// The position and rotation of this node in worldspace coordinates
	public bool			transform_dirty=true;	// The absolute transformation matrix needs to be recalculated.

	protected Vec3f		linear_velocity;
	protected Vec3f		angular_velocity;
	protected Vec3f		linear_velocity_abs;	// Store a cached version of the absolute linear velocity.
	protected Vec3f		angular_velocity_abs;
	protected bool		velocity_dirty=true;	// The absolute velocity vectors need to be recalculated.

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
	/* protected*/ Cache cache[3];

	/// Constructor
	this(Node parent=null)
	{	if (parent)
			parent.addChild(this);
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
	override Node clone()
	{	return clone(false);		
	}
	Node clone(bool children) /// ditto
	{	Node result = cast(Node)this.classinfo.create();		
		
		// Since "this" may have its properties changed by other calls during this process.
		// TODO: Nothing else synchronizes, so this doesn't really provide any protection!
		synchronized(this) 
		{	result.lifetime = lifetime;
			result.transform = transform;
			result.linear_velocity = linear_velocity;
			result.angular_velocity = angular_velocity;
			result.linear_velocity_abs = linear_velocity_abs;
			result.angular_velocity_abs = angular_velocity_abs;
			result.cache[0..3] = cache[0..3];
			
			result.onUpdate = onUpdate;
			
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
	override void dispose()
	{	if (children.length)
		{	foreach_reverse (c; children)
				c.dispose();
			children.length = 0; // prevent multiple calls.
		}
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
	{	return Format.convert("<{} children=\"{}\"/>", getType(), children.length);
	}


	/**
	 * Update the positions and rotations of this Node and all children by delta seconds.*/ 
	void update(float delta)
	{	
		// Call the onUpdate() function
		if (onUpdate !is null)
			onUpdate(); // TODO: make this exclusive like Surface events.
		
		// Cache the current relative and absolute position/rotation for rendering.
		// This prevents rendering a halfway-updated scenegraph.
		if (scene)
		{	cache[scene.transform_write].transform = transform;
			if (transform_dirty)
				calcTransform();
			cache[scene.transform_write].transform_abs = transform_abs;
		}
		
		// We iterate in reverse in case a child deletes itself.
		// What about one child deleting another?
		// I guess the preferred way to remove an object would be to set its lifetime to 0.
		// Perhaps we should override remove to do this so that items are removed in a controlled way?
		foreach_reverse(Node c; children) // gdc segfaults 2 lines below unless this is foreach_reverse
			if (c) // does this solve the problem above?
				c.update(delta);
		
		lifetime-= delta;
		if (lifetime <= 0)
		{	if (parent)
				parent.removeChild(this);
			lifetime = float.infinity;
		}
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
		// TODO: IF I syncrhonize on the multiply by a copied result 
		// of parent.getAbsoluteTransform(), that should be threadsafe.
		if (transform_dirty) 
			
		{	//synchronized(this) // still causes deadlock
			{	if (parent)
				{	//synchronized(this.parent) // still causes deadlock.
					{	parent.calcTransform();
						//transform_abs = transform * parent.transform_abs;
						transform_abs = parent.transform_abs.transformAffine(transform);
						linear_velocity_abs = linear_velocity + parent.linear_velocity_abs;
						// TODO: linear_velocity_abs doesn't account for angular velocity
						
				}	}
				else
				{	transform_abs = transform;
					linear_velocity_abs = linear_velocity;
				}
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
