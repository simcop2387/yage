/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.node;

import std.stdio;
import std.traits;
import std.bind;
import yage.core.all;
import yage.core.tree;
import yage.scene.visible;
import yage.scene.scene;
import yage.scene.movable;
import yage.scene.all;
import yage.scene.light;
import yage.scene.node;

/**
 * All other Nodes extend this class.
 * Methods for modifying the hierarchy of Nodes (parents, children) are defined here.
 * 
 * Every node has an array of child nodes as well as a parent node, with
 * the exception of a Scene that exists at the top of the scene graph and has no parent.  
 * When one node is moved or rotated, all of its child nodes move and rotate as well.
 * Likewise, setting the position or rotation of a node does so relative to its parent.  
 * Rendering is done recursively from the Scene down through every child node.  
 * Likewise, updating of position and rotation occurs recusively from Scene's update() method.
 *  
 * Example:
 * --------------------------------
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
 * --------------------------------*/
abstract class Node : Tree!(Node)
{
	// These are public for easy internal access.
	Scene	scene;			// The Scene that this node belongs to.
	protected float lifetime = float.infinity;	// in seconds
	protected void delegate(Node self) on_update = null;	// called on update
	
	protected Matrix	transform;				// The position and rotation of this node relative to its parent
	protected Matrix	transform_abs;			// The position and rotation of this node in worldspace coordinates
	protected bool		transform_dirty=true;	// The absolute transformation matrix needs to be recalculated.

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
	 * Overridden from Tree to mark transform dirty. 
	 * Returns: The child parameter.  Templating is used to ensure the return type is exactly the same.*/
	T addChild(T : Node)(T child)
	{	// Recursively set secene and update scene's list of lights for all children
		void merge(Node node)
		{	if (cast(LightNode)node)
			{	if (node.scene)
					node.scene.removeLight(cast(LightNode)node);
				if (scene)
					scene.addLight(cast(LightNode)node);
			}
			node.scene = scene;			
			foreach (c; node.children)
				merge(c);
		}
		
		merge(child);
		auto old_parent = child.getParent();
		super.addChild(child);
		setTransformDirty(); // seems like this should be child.setTransformDirty(), but that breaks things.
		child.parentChange(old_parent);
		return child;
	}
	
	T clone(T : typeof(this))()
	{
		T result = new T();		
		return result;		
	}

	/// Construct as a child of parent, a copy of original and recursivly copy all children.
	this(Node parent, Node original)
	{	this();
		parent.addChild(this);

		lifetime = original.lifetime;
		on_update = original.on_update;

		// From Node
		transform = original.transform;
		linear_velocity = original.linear_velocity;
		angular_velocity = original.angular_velocity;
		cache[0] = original.cache[0];
		cache[1] = original.cache[1];
		cache[2] = original.cache[2];

		// Also recursively copy every child
		foreach (inout Node c; original.children)
		{	// Scene and Node are never children
			// Is there a better way to do this?
			switch (c.classinfo.name)
			{	case "yage.scene.camera.CameraNode": new CameraNode(this, cast(CameraNode)c); break;
				case "yage.scene.graph.GraphNode": new GraphNode(this, cast(GraphNode)c); break;
				case "yage.scene.light.LightNode": new LightNode(this, cast(LightNode)c); break;
				case "yage.scene.model.ModelNode": new ModelNode(this, cast(ModelNode)c); break;
				case "yage.scene.sound.SoundNode": new SoundNode(this, cast(SoundNode)c); break;
				case "yage.scene.sprite.SpriteNode": new SpriteNode(this, cast(SpriteNode)c); break;
				case "yage.scene.terrain.TerrainNode": new TerrainNode(this, cast(TerrainNode)c); break;				
				default:
			}
			/*
			new Object.factory(c.classinfo.name);
			auto ci = ClassInfo.find(classname);
			if (ci)
			{
			    return ci.create();
			}
			return null;
			*/
		}
	}
	

	/**
	 * Get / set the lifeime of a VisibleNode (in seconds).
	 * The default value is float.infinity, but a lower number will cause the VisibleNode to be removed
	 * from the scene graph after that amount of time, as its lifetime is decreased with every Scene update.*/	
	float getLifetime() 
	{	return lifetime; 
	}
	void setLifetime(float seconds)  /// Ditto
	{	lifetime = seconds; 
	}
	
	

	/// Get the Scene at the top of the tree that this node belongs to, or null if this is part of a sceneless node tree.
	Scene getScene()
	{	return scene;
	
		// properly handles node trees with no parent scene.
		//if (parent)
		//	return parent.getScene();
		//return null;		
	}

	/// Get the type of this Node as a string; i.e. "yage.scene.visible.ModelNode".
	char[] getType()
	{	return this.classinfo.name;
	}
	
	/// Always returns false unless overridden.
	bool getVisible()
	{	return false;		
	}

	/**
	 * Return a string representation of this Node for human reading. */	
	override char[] toString()
	{	return formatString("<%s children=\"%d\"/>", getType(), children.length);
	}
	
	/**
	 * Set a function that will be called every time this Node is updated.
	 * Specifically, the supplied function is called after a Node's matrices
	 * are updated and before its children are updated and before it's removed if
	 * it's lifetime is zero.
	 * Params:
	 * on_update = the function that will be called.  Use null as an argument to clear
	 * the function.
	 * Bugs:
	 * Certain Node methods cause access violations.  Perhaps this is a dmd bug?
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
		cache[scene.transform_write].transform = transform;
		if (transform_dirty)
			calcTransform();
		cache[scene.transform_write].transform_abs = transform_abs;

		// Call the onUpdate() function
		if (on_update !is null)
			on_update(this);

		// We iterate in reverse in case a child deletes itself.
		// What about one child deleting another?
		// I guess the preferred way to remove an object would be to set its lifetime to 0.
		// Perhaps we should override remove to do this so that items are removed in a controlled way?
		foreach_reverse(Node c; children)
			if (c) // does this solve the problem above?
				c.update(delta);
		
		lifetime-= delta;
		if (lifetime <= 0)
			remove();
	}
	
	/*
	 * Set the transform_dirty flag on this Node and all of its children, if they're not dirty already.
	 * This should be called whenever a Node is moved or rotated
	 * This function is used internally by the engine usually doesn't need to be called manually. */
	void setTransformDirty()
	{	if (!transform_dirty)
		{	transform_dirty=true;
			foreach(Node c; children)
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
		{	synchronized(this)			
			{	if (parent)
				{	synchronized(this.parent)
					{	parent.calcTransform();
						transform_abs = transform * parent.transform_abs;
						transform_dirty = false;
				}	}
				else
					transform_abs = transform;
		}	}
	}

	/*
	 * Called after a node's parent changes. */
	protected void parentChange(Node old_parent)
	{
		
	}
}
