/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.node;

import tango.core.Thread;
import tango.math.Math;
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

	struct Transform
	{	Vec3f position;
		Quatrn rotation;
		Vec3f scale = Vec3f.ONE;

		Vec3f velocityDelta;
		Quatrn angularVelocityDelta;

		Vec3f worldPosition;
		Quatrn worldRotation;
		Vec3f worldScale = Vec3f.ONE;

		float radius=0;	// TODO: unionize these with the vectors above for tighter packing once we switch to simd.
		bool worldDirty=true;
		Node.Transform* parent;
		Node* node;

		static Transform opCall()
		{	Transform result;
			return result;
		}
	}
	package Transform* transform;
	package int sceneIndex=-1;

	//alias transform this;

	//package Vec3f position;
	//package Quatrn rotation;
	//package Vec3f scale = Vec3f.ONE;
	
	//protected Vec3f velocity;	// deprecated?
	//protected Vec3f angularVelocity; // deprecated?

	//private Vec3f velocityDelta;
	//private Quatrn angularVelocityDelta;
	
	//package Vec3f worldPosition;
	//package Quatrn worldRotation;
	//package Vec3f worldScale = Vec3f.ONE;

	//package bool worldDirty=true;		
	package Scene scene;			// The Scene that this node belongs to.

	static const float DEFAULT_INCREMENT = 1f/60f;


	void delegate() onUpdate = null;	/// If set, call this function instead of the standard update function.

	
	invariant()
	{	assert(parent !is this);
	//	assert(transform !is null);
	}
	
	/**
	 * Construct and optionally add as a child of another Node. */
	this()
	{	transform = new Transform();
	}	
	this(Node parent) /// ditto
	{	if (parent)
		{	mixin(Sync!("scene"));
			parent.addChild(this);
		} else
			transform = new Transform();
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
		
		*destination.transform = *transform;

		//destination.position = position;
		//destination.rotation = rotation;
		//destination.scale = scale;
		//destination.velocityDelta = velocityDelta;
		//destination.angularVelocity = angularVelocity;	
		//destination.angularVelocityDelta = angularVelocityDelta;

		if (scene && scene.increment != DEFAULT_INCREMENT)
		{	float change = scene.increment/DEFAULT_INCREMENT;
			destination.transform.velocityDelta *= change;
			destination.transform.angularVelocityDelta.multiplyAngle(change);
		}
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
		return transform.position;
	}	
	void setPosition(Vec3f position) /// ditto
	{	mixin(Sync!("scene"));
		setWorldDirty();
		transform.position = position;
	}
	
	/**
	 * Get / set the rotation of this Node (as an axis-angle vector) relative to its parent's rotation. */
	Vec3f getRotation()
	{	mixin(Sync!("scene"));
		return transform.rotation.toAxis();
	}
	void setRotation(Vec3f axisAngle) /// ditto
	{	mixin(Sync!("scene"));
		setWorldDirty();
		transform.rotation = axisAngle.toQuatrn();
	}

	void setRotation(Quatrn quaternion) /// ditto
	{	mixin(Sync!("scene"));
		setWorldDirty();
		transform.rotation = quaternion;
	}
	
	/**
	 * Get / set the xyz scale of this Node relative to its parent's scale. */
	Vec3f getScale()
	{	mixin(Sync!("scene"));
		return transform.scale;
	}	
	void setScale(Vec3f scale) /// ditto
	{	mixin(Sync!("scene"));
		setWorldDirty();
		transform.scale = scale;
	}

	
	/**
	 * Get / set the linear velocity this Node relative to its parent's velocity. */
	Vec3f getVelocity()
	{	mixin(Sync!("scene"));
		return transform.velocityDelta/(scene?scene.increment:DEFAULT_INCREMENT);
	}	
	void setVelocity(Vec3f velocity) /// ditto
	{	mixin(Sync!("scene"));
		transform.velocityDelta = velocity*(scene?scene.increment:DEFAULT_INCREMENT);
	}
	
	/**
	 * Get / set the angular (rotation) velocity this Node relative to its parent's velocity. */
	Vec3f getAngularVelocity()
	{	mixin(Sync!("scene"));
		Quatrn result = transform.angularVelocityDelta;
		result.multiplyAngle(1/(scene?scene.increment:DEFAULT_INCREMENT));
		return result.toAxis();		
	}	
	void setAngularVelocity(Vec3f axisAngle) /// ditto
	{	mixin(Sync!("scene"));
		transform.angularVelocityDelta = (axisAngle * (scene?scene.increment:DEFAULT_INCREMENT)).toQuatrn();
	}
	unittest
	{	Node a = new Node();
		Vec3f av1 = Vec3f(1, 2, 3);
		a.setAngularVelocity(av1);
		Vec3f av2 = a.getAngularVelocity();
		assert(av1.almostEqual(av2), format("%s", av2.v));
	}
	
	/**
	 * Get the position, axis-angle rotation, or scale in world coordinates, 
	 * instead of relative to the parent Node. */
	Vec3f getWorldPosition()
	{	mixin(Sync!("scene"));
		if (transform.worldDirty) // makes it faster.
			calcWorld();
		return transform.worldPosition; // TODO: optimize
	}
	Vec3f getWorldRotation() /// ditto
	{	mixin(Sync!("scene"));
		calcWorld();
		return transform.worldRotation.toAxis();
	}
	Vec3f getWorldScale() /// ditto
	{	mixin(Sync!("scene"));
		calcWorld();
		return transform.worldScale;
	}
	
	/// Bug:  Doesn't take parent's rotation or scale into account
	Vec3f getWorldVelocity()
	{	mixin(Sync!("scene"));
		calcWorld();
		if (parent)
			return transform.velocityDelta/(scene?scene.increment:DEFAULT_INCREMENT) + parent.getWorldVelocity();
		
		return transform.velocityDelta/(scene?scene.increment:DEFAULT_INCREMENT);
	}
	
	// Convenience functions:
	
	///
	Matrix getTransform()
	{	//Log.write(rotation.v);
		return Matrix.compose(transform.position, transform.rotation, transform.scale);
	}

	
	///
	Matrix getWorldTransform()
	{	mixin(Sync!("scene"));
		calcWorld();
		return Matrix.compose(transform.worldPosition, transform.worldRotation, transform.worldScale);
	}

	///
	void move(Vec3f amount)
	{	mixin(Sync!("scene"));
		transform.position += amount;
		setWorldDirty();
	}

	///
	void rotate(Vec3f axisAngle)
	{	mixin(Sync!("scene"));
		transform.rotation = transform.rotation*axisAngle.toQuatrn(); 
		setWorldDirty();
	}

	///
	void rotate(Quatrn quaternion)
	{	mixin(Sync!("scene"));
		transform.rotation = transform.rotation*quaternion; 
		setWorldDirty();
	}

	///
	void accelerate(Vec3f amount)
	{	mixin(Sync!("scene"));
		transform.velocityDelta += amount*(scene?scene.increment:DEFAULT_INCREMENT);
	}
	
	///
	void angularAccelerate(Vec3f axisAngle)
	{	mixin(Sync!("scene"));		
		transform.angularVelocityDelta = transform.angularVelocityDelta.rotate(axisAngle.scale(scene?scene.increment:DEFAULT_INCREMENT).toQuatrn()); // TODO: Is this clamped to -PI to PI?
	}
	unittest
	{	Node n = new Node();
		Vec3f av = Vec3f(-.5, .5, 1);
		n.setAngularVelocity(av);
		n.angularAccelerate(av);
		Vec3f av2 = n.getAngularVelocity();
		assert(av2.almostEqual(av*2), format("%s", av2.v));
	}

	///
	void update(float delta)
	{	mixin(Sync!("scene"));
	
		bool dirty = false;
		if (transform.velocityDelta != Vec3f.ZERO)
		{	transform.position += transform.velocityDelta; // TODO: store cached version?
			dirty = true;
		}
	
		// Rotate if angular velocity is not zero.
		float angle = transform.angularVelocityDelta.w - 3.1415927/4;
		if (angle < -0.0001 || angle > 0.001)
		{	transform.rotation = transform.rotation * transform.angularVelocityDelta;
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
	{	if (!transform.worldDirty)
		{	transform.worldDirty=true;
			foreach(c; children)
				c.setWorldDirty();
	}	}

	/*
	 * Calculate the value of the worldPosition, worldRotation, and worldScale. */
	protected void calcWorld()
	{	
		if (transform.worldDirty)
		{		
			if (parent && parent !is scene)
			{	parent.calcWorld();

				transform.worldPosition = transform.position * parent.transform.worldScale;
				if (parent.transform.worldRotation != Quatrn.IDENTITY) // Because rotation is more expensive
				{	transform.worldPosition = transform.worldPosition.rotate(parent.transform.worldRotation);
					transform.worldRotation = parent.transform.worldRotation * transform.rotation;
				} else
					transform.worldRotation = transform.rotation;

				transform.worldPosition += parent.transform.worldPosition;				
				transform.worldScale =  parent.transform.worldScale * transform.scale;

			} else
			{	
				transform.worldPosition = transform.position;
				transform.worldRotation = transform.rotation;
				transform.worldScale = transform.scale;
			}
			transform.worldDirty = false;
		}
	}
	unittest
	{
		Node a = new Node();
		a.setPosition(Vec3f(3, 0, 0));
		a.setRotation(Vec3f(0, 3.1415927, 0));
		
		Node b = new Node(a);
		b.setPosition(Vec3f(5, 0, 0));
		auto bw = b.getWorldPosition();
		assert(bw.almostEqual(Vec3f(-2, 0, 0)), format("%s", bw.v));

		a.setScale(Vec3f(2, 2, 2));
		bw = b.getWorldPosition();
		assert(bw.almostEqual(Vec3f(-7, 0, 0)), format("%s", bw.v));
	}
	
	/*
	 * Called after any of a node's ancestors have their parent changed. 
	 * This function also sets worldDirty=true
	 * since the world transformation values should always be dirty after an ancestor change. 
	 * @param oldAncestor The ancestor that was previously one above the top node of the tree that had its parent changed. */
	protected void ancestorChange(Node oldAncestor)
	{	
		Scene oldScene = this.scene;
		scene = parent ? parent.scene : null;

		// Allocate, deallocate, and move transform data from one scene to another.
		if (scene !is oldScene)
		{	if (scene)
			{	
				if (!transform)				
					transform = scene.nodeTransforms.append(Transform());
				else
				{	Transform* old = transform;					
					transform = scene.nodeTransforms.append(*transform);
					if (oldScene)
						oldScene.nodeTransforms.remove(sceneIndex);
					else
						delete old; // transform was previously on the heap
				}
				sceneIndex = scene.nodeTransforms.length-1;
			} 
			else if (oldScene)
			{	transform = new Transform(); // move them onto the stack
				transform = oldScene.nodeTransforms[sceneIndex];
				sceneIndex = -1;
			} 
			else if (!transform)
				transform = new Transform();

			// Update the incrementing values to match the scene increment.
			float incrementChange = (scene?scene.increment:DEFAULT_INCREMENT) / (oldScene?oldScene.increment:DEFAULT_INCREMENT);
			if (incrementChange != 1f)
			{	transform.velocityDelta *= incrementChange;
				transform.angularVelocityDelta.multiplyAngle(incrementChange);
			}
		} 
		else if (!transform)
			transform = new Transform();

		transform.worldDirty = true;

		foreach(c; children)
			c.ancestorChange(oldAncestor);
	}
}
