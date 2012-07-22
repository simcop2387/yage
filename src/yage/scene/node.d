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
	/*
	 * A node's transformation values are stored in a consecutive array in its scene, for better cache performance
	 * Or if, it has no scene, this structure is allocated on the heap. */
	struct Transform
	{	package Vec3f position;
		package Quatrn rotation;
		package Vec3f scale = Vec3f.ONE;

		package Vec3f velocityDelta;	// Velocity times the scene increment, for faster updating.
		package Vec3f angularVelocity;	// Stored as a vector to allow storing rotations beyond -PI to PI
		package Quatrn angularVelocityDelta; // Stored as a quaternion for faster updating.

		package Vec3f worldPosition;
		package Quatrn worldRotation;
		package Vec3f worldScale = Vec3f.ONE;

		package float radius=0;	// TODO: unionize these with the vectors above for tighter packing once we switch to simd.
		package bool worldDirty=true;

		package Node.Transform* parent; // For fast lookups when calculating world transforms
		package Node node;				// Pointer back to the node.

		static Transform opCall()
		{	Transform result;
			return result;
		}
	}
	
	package int sceneIndex=-1;			// Index of the transform structure in the scene's nodeTransforms array.
	
	package Node.Transform* transform() { 
		assert (!scene || (sceneIndex>=0 && sceneIndex<scene.nodeTransforms.length), format("%s", sceneIndex));
		return scene ? 
			&scene.nodeTransforms.transforms[sceneIndex] : 
			&Scene.orphanNodeTransforms.transforms[sceneIndex]; 
	}


	package Scene scene;				// The Scene that this node belongs to.

	void delegate() onUpdate = null;	/// If set, call this function instead of the standard update function.

	
	invariant()
	{	assert(parent !is this);
	}
	
	/**
	 * Construct and optionally add as a child of another Node. */
	this()
	{	ancestorChange(null);
		transform().node = this;
	}	
	this(Node parent) /// ditto
	{	if (parent)
		{	mixin(Sync!("scene"));
			parent.addChild(this); // calls ancestorChange()
		} else
			ancestorChange(null);
		transform.node = this;
	}
	
	/**
	 * Add a child Node to this Node's array of children.
	 * Overridden to call ancestorChange() and mark transformation matrices dirty.
	 * Params:
	 *     child = The Node to add.
	 * Returns: The child Node that was added.  Templating is used to ensure the return type is exactly the same.*/
	T addChild(T : Node)(T child)
	{	assert(child !is this);
		assert(child !is parent);
		
		mixin(Sync!("scene"));
		auto old_parent = child.getParent();
		super.addChild(child);
		child.ancestorChange(old_parent);

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
		auto oldParent = child.getParent();
		super.removeChild(child);
		child.ancestorChange(oldParent); // sets worldDirty also
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
		if (scene)
		{	destination.transform.velocityDelta /= scene.increment;
			destination.transform.angularVelocityDelta.multiplyAngle(1/scene.increment);
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
		if (scene)
			return transform.velocityDelta/scene.increment;
		else
			return transform.velocityDelta;
	}	
	void setVelocity(Vec3f velocity) /// ditto
	{	mixin(Sync!("scene"));
		if (scene)		
			transform.velocityDelta = velocity*scene.increment;
		else
			transform.velocityDelta = velocity;
	}
	
	/**
	 * Get / set the angular (rotation) velocity this Node relative to its parent's velocity. */
	Vec3f getAngularVelocity()
	{	mixin(Sync!("scene"));
		return transform.angularVelocity;
	}	
	void setAngularVelocity(Vec3f axisAngle) /// ditto
	{	mixin(Sync!("scene"));		
		transform.angularVelocity = axisAngle;
		if (scene)
			transform.angularVelocityDelta = (axisAngle*scene.increment).toQuatrn();
		else
			transform.angularVelocityDelta = axisAngle.toQuatrn();
	}
	unittest
	{	Node n = new Node();
		Vec3f av1 = Vec3f(-.5, .5, 1);
		n.setAngularVelocity(av1);
		Vec3f av2 = n.getAngularVelocity();
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
		{	if (scene)
				return transform.velocityDelta/scene.increment + parent.getWorldVelocity();
			return transform.velocityDelta + parent.getWorldVelocity();
		}
		if (scene)
			return transform.velocityDelta/scene.increment;
		return transform.velocityDelta;
	}
	
	// Convenience functions:
	
	///
	Matrix getTransform()
	{	return Matrix.compose(transform.position, transform.rotation, transform.scale);
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
		if (scene)
			transform.velocityDelta += amount*scene.increment;
		else
			transform.velocityDelta += amount;
	}
	
	///
	void angularAccelerate(Vec3f axisAngle)
	{	//mixin(Sync!("scene")); // already present in called function
		setAngularVelocity(transform.angularVelocity.combineRotation(axisAngle)); // TODO: Is this clamped to -PI to PI?
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
	 * Set the worldDirty flag on this Node and all of its children, if they're not dirty already.
	 * This should be called whenever a Node has its transformation matrix changed.
	 * This function is used internally by the engine usually doesn't need to be called manually. */
	package void setWorldDirty()
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
	 * Params:
	 *    oldAncestor = The ancestor that was previously one above the top node of the tree that had its parent changed. */
	protected void ancestorChange(Node oldAncestor)
	{	
		Scene newScene = parent ? parent.scene : null;		
		auto transforms = newScene ? &newScene.nodeTransforms : &Scene.orphanNodeTransforms;
		auto oldTransforms = scene ? &scene.nodeTransforms : &Scene.orphanNodeTransforms;

		if (transforms !is oldTransforms) // changing scene of existing node
		{	
			if (sceneIndex==-1)
				sceneIndex = transforms.addNew(this);
			else
			{	int newIndex = transforms.add(transform());		
				oldTransforms.remove(sceneIndex);
				sceneIndex = newIndex;
			}
			scene = newScene;

			// Update the incrementing values to match the scene increment.
			float incrementChange = (scene ? scene.increment : 1f) / (scene ? scene.increment : 1f);
			transform.velocityDelta *= incrementChange;
			transform.angularVelocityDelta.multiplyAngle(incrementChange);
		} 
		else if (sceneIndex==-1) // a brand new node
			sceneIndex = transforms.addNew(this);

		transform().parent = (parent && parent !is scene) ? parent.transform() : null;
		transform().worldDirty = true;

		foreach(c; children)
			c.ancestorChange(oldAncestor); // breaks the assertions below!  But how?

		debug if (scene)
			assert(0<=sceneIndex && sceneIndex < transforms.length);
		else
			assert(sceneIndex != -1);
		assert(transform); // assert it is accessible
		assert(transform.worldDirty || !transform.worldDirty);		
	}
	unittest
	{	Node a = new Node();
		Node b = new Node(a);
		Node c = new Node(a);		
		b.addChild(c);
		a.addChild(c);

		Scene s = new Scene();
		Node d = new Node();
		s.addChild(d);
	}
}
