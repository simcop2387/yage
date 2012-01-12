/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.node;

import tango.core.Thread;
import yage.core.all;
import yage.core.tree;
import yage.scene.scene;
import yage.scene.all;
import yage.system.log;

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
 * Node a = s.addChild(new Node());  // a is a child of s, it exists in Scene s.
 * a.setPosition(3, 5, 0);           // Position is set relative to 0, 0, 0 of the entire scene.
 * a.setRotation(0, 3.14, 0);        // a is rotated PI radians (180 degrees) around the Y axis.
 *
 * SpriteNode b = new SpriteNode(a); // b is a child of a, therefore,
 * b.setPosition(5, 0, 0);           // its positoin and rotation are relative to a's.
 * b.getWorldPosition();             // Returns Vec3f(-2, 5, 0), b's position relative to the origin.
 *
 * s.addChild(b);                    // b is now a child of s.
 * b.getWorldPosition();             // Returns Vec3f(5, 0, 0), since it's position is relative
 *                                   // to 0, 0, 0, instead of a.
 * --------
 */
class Node : Tree!(Node), IDisposable
{
	void delegate() onUpdate = null;	/// If set, call this function instead of the standard update function.

	package Vec3f position;
	package Quatrn rotation;
	//package Vec3f rotation;
	package Vec3f scale = Vec3f.ONE;
	
	package Vec3f velocity;
	private Vec3f angularVelocity;
	package Quatrn angularVelocityDelta;
	
	package Vec3f worldPosition;
	package Quatrn worldRotation;
	//package Vec3f worldRotation;
	package Vec3f worldScale = Vec3f.ONE;
	
	package Vec3f worldVelocity;
	
	package bool worldDirty;
		
	package Scene scene;			// The Scene that this node belongs to.
	
	invariant()
	{	assert(parent !is this);
	}
	
	/**
	 * Construct and optionally add as a child of another Node. */
	this()
	{	// default constructor required for clone.
	}	
	this(Node parent) /// ditto
	{	if (parent)
		{	mixin(Sync!("scene"));
			parent.addChild(this);
		}
	}
	
	/**
	 * Add a child Node to this Node's array of children.
	 * Overridden to call ancestorChange() and mark transformation matrices dirty.
	 * Params:
	 *     child = The Node to add.
	 * Returns: The child Node that was added.  Templating is used to ensure the return type is exactly the same.*/
	T addChild(T : Node)(T child)
	{	mixin(Sync!("scene"));
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
	T removeChild(T : Node)(T child)
	{	mixin(Sync!("scene"));
		auto old_parent = child.getParent();
		super.removeChild(child);
		child.ancestorChange(old_parent); // sets transform dirty also
		return child;
	}
	
	/**
	 * Make a duplicate of this node, unattached to any parent Node.
	 * Params:
	 *     children = recursively clone children (and descendants) and add them as children to the new Node.
	 * Returns: The cloned Node. */
	Node clone(bool children=true, Node destination=null) /// ditto
	{	mixin(Sync!("scene"));
		
		if (!destination)
			destination = cast(Node)this.classinfo.create(); // why does new typeof(this) fail?
		assert(destination);
		
		destination.position = position;
		destination.rotation = rotation;
		destination.scale = scale;
		destination.velocity = velocity;
		destination.angularVelocity = angularVelocity;				
		destination.onUpdate = onUpdate;
		
		if (children)
			foreach (c; this.children)
			{	auto copy = cast(Node)c.classinfo.create();
				destination.addChild(c.clone(true, copy));
			}
		destination.setWorldDirty();
		
		return destination;
	}	
	unittest
	{	// Test child cloning
		auto a = new Node();
		a.addChild(new Node());
		auto b = a.clone(true);
		assert(b.getChildren().length == 1);
		assert(b.getChildren()[0] != a.getChildren()[0]); // should not be equal, should've been cloned.
	}
	
	/**
	 * Some types of Nodes may need to free resources before being destructed. */
	override void dispose()
	{	mixin(Sync!("scene"));
		if (children.length)
		{	foreach_reverse (c; children)
				c.dispose();
			children.length = 0; // prevent multiple calls.
		}
	}
	
	/**
	 * Get / set the xyz position of this Node relative to its parent's position. */
	Vec3f getPosition()
	{	mixin(Sync!("scene"));
		return position;
	}	
	void setPosition(Vec3f position) /// ditto
	{	mixin(Sync!("scene"));
		setWorldDirty();
		this.position = position;
	}
	
	/**
	 * Get / set the rotation of this Node (as an axis-angle vector) relative to its parent's rotation. */
	Vec3f getRotation()
	{	mixin(Sync!("scene"));
		return rotation.toAxis();
	}	
	void setRotation(Vec3f axisAngle) /// ditto
	{	mixin(Sync!("scene"));
		setWorldDirty();
		this.rotation = axisAngle.toQuatrn();
	}
	
	/**
	 * Get / set the xyz scale of this Node relative to its parent's scale. */
	Vec3f getScale()
	{	mixin(Sync!("scene"));
		return scale;
	}	
	void setScale(Vec3f scale) /// ditto
	{	mixin(Sync!("scene"));
		setWorldDirty();
		this.scale = scale;
	}

	
	/**
	 * Get / set the linear velocity this Node relative to its parent's velocity. */
	Vec3f getVelocity()
	{	mixin(Sync!("scene"));
		return velocity;
	}	
	void setVelocity(Vec3f velocity) /// ditto
	{	mixin(Sync!("scene"));
		this.velocity = velocity;
	}
	
		import tango.math.IEEE;
	/**
	 * Get / set the angular (rotation) velocity this Node relative to its parent's velocity. */
	Vec3f getAngularVelocity()
	{	mixin(Sync!("scene"));
		return angularVelocity;
	}	
	void setAngularVelocity(Vec3f axisAngle) /// ditto
	{	mixin(Sync!("scene"));
		//Log.write(axisAngle.v);
		
		debug axisAngle.check();
		
		this.angularVelocity = axisAngle;
		this.angularVelocityDelta = (axisAngle*(1/60f)).toQuatrn();
	}
	
	/**
	 * Get the position, axis-angle rotation, or scale in world coordinates, 
	 * instead of relative to the parent Node. */
	Vec3f getWorldPosition()
	{	mixin(Sync!("scene"));
		if (worldDirty) // makes it faster.
			calcWorld();
		return worldPosition; // TODO: optimize
	}
	Vec3f getWorldRotation() /// ditto
	{	mixin(Sync!("scene"));
		calcWorld();
		return worldRotation.toAxis();
	}
	Vec3f getWorldScale() /// ditto
	{	mixin(Sync!("scene"));
		calcWorld();
		return worldScale;
	}
	
	///
	Vec3f getWorldVelocity()
	{	mixin(Sync!("scene"));
		calcWorld();
		return worldVelocity;
	}
	
	// Convenience functions:
	
	///
	Matrix getTransform()
	{	return Matrix.compose(position, rotation, scale);
	}
	
	///
	Matrix getWorldTransform()
	{	mixin(Sync!("scene"));
		calcWorld();
		return Matrix.compose(worldPosition, worldRotation, worldScale);
	}

	///
	void move(Vec3f amount)
	{	mixin(Sync!("scene"));
		position += amount;
		setWorldDirty();
	}

	///
	void rotate(Vec3f axisAngle)
	{	mixin(Sync!("scene"));
		rotation = rotation*axisAngle.toQuatrn(); 
		//Log.write(rotation, axisAngle);
		//rotation = rotation.combineRotation(axisAngle);
		setWorldDirty();
	}

	///
	void accelerate(Vec3f amount)
	{	mixin(Sync!("scene"));
		velocity += amount;
	}
	
	///
	void angularAccelerate(Vec3f axisAngle)
	{	mixin(Sync!("scene"));
		
		debug axisAngle.check();
		
		angularVelocity = angularVelocity.combineRotation(axisAngle);; // TODO: Is this clamped to -PI to PI?
		
		debug angularVelocity.check();
	}

	///
	void update(float delta)
	{	mixin(Sync!("scene"));
	
		bool dirty = false;
		if (velocity != Vec3f.ZERO)
		{	position += velocity*delta;
			dirty = true;
		}
	
		// Rotate if angular velocity is not zero.
		if (angularVelocity != Vec3f.ZERO)
		{	//rotation = rotation.combineRotation(angularVelocity*delta);
			//debug angularVelocity.check();
			rotation = rotation * (angularVelocity*delta).toQuatrn();
			//rotation += angularVelocity*delta;
			dirty = true;
		}
		if (dirty)
			setWorldDirty();
		
		foreach (node; children)
		{	if (node.onUpdate)
				node.onUpdate();
			else
				node.update(delta);
		}
	}
	
	/// Get the Scene at the top of the tree that this node belongs to, or null if this is part of a scene-less node tree.
	Scene getScene()
	{	return scene;
	}
	
	/*
	 * Set the transform_dirty flag on this Node and all of its children, if they're not dirty already.
	 * This should be called whenever a Node has its transformation matrix changed.
	 * This function is used internally by the engine usually doesn't need to be called manually. */
	protected void setWorldDirty()
	{	if (!worldDirty)
		{	worldDirty=true;
			foreach(c; children)
				c.setWorldDirty();
	}	}

	protected void calcWorld()
	{	
		if (worldDirty)
		{		
			if (parent && parent !is scene)
			{	parent.calcWorld(); // TODO: optimize this!
				Matrix worldTransform = parent.getWorldTransform().transformAffine(getTransform());	
				//matrix.decompose(worldPosition, worldRotation, worldScale);
				
				Vec3f wp, wr, ws;
				worldTransform.decompose(wp, wr, ws);
				worldPosition = wp;
				worldRotation = wr.toQuatrn();
				worldScale = ws;
				
				worldVelocity = velocity + parent.worldVelocity; // TODO: This doesn't even take rotation into account!
			} else
			{	
				worldPosition = position;
				worldRotation = rotation;
				worldScale = scale;
				worldVelocity = velocity;
			}
			worldDirty = false;
		}
	}	
	unittest
	{
		Node a = new Node();
		a.setPosition(Vec3f(3, 0, 0));
		a.setRotation(Vec3f(0, 3.1415927, 0));
		
		Node b = new Node(a);
		b.setPosition(Vec3f(5, 0, 0));
		assert(b.getWorldPosition().almostEqual(Vec3f(-2, 0, 0)));
	}
	
	/*
	 * Called after any of a node's ancestors have their parent changed. 
	 * This function also sets transform_dirty.  
	 * Yes, this is a side-effect,  but it increases performance in cases where both need to be called, 
	 * since the transformation matrix should always be dirty after an ancestor change. 
	 * @param old_ancestor The ancestor that was previously one above the top node of the tree that had its parent changed. */
	protected void ancestorChange(Node old_ancestor)
	{	worldDirty = true;
		scene = parent ? parent.scene : null;
		foreach(c; children)
			c.ancestorChange(old_ancestor);
		
	}
}
