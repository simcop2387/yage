/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.node;

import std.math;
import std.stdio;
import std.traits;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;
import derelict.sdl.sdl;
import yage.core.all;
import yage.node.all;
import yage.node.scene;
import yage.node.light;
import yage.node.basenode;
import yage.system.constant;
import yage.system.device;
import yage.system.input;


/**
 * A Node is an instance of some tpe of object in a Scene.
 * Every node has an array of child nodes as well as a parent node, with
 * the obvious exception of a Scene whose parent is null.  When one node
 * is moved or rotated, all of its child nodes move and rotate as well.
 * Likewise, setting the position or rotation of a node does so relative
 * to its parent.  Rendering is done recursively from the Scene down
 * through every child node.  Likewise, updating of position and rotation
 * occurs recusively from Scene's update() function.
 *
 * Example:
 * --------------------------------
 * Scene s = new Scene();
 * Node a = new Node(s);      // a is a child of s, it exists in Scene s.
 * a.setPosition(3, 5, 0);    // Position is set relative to 0, 0, 0 of the entire scene.
 * a.setRotation(0, 3.14, 0); // a is rotated PI radians (180 degrees) around the Y axis.
 *
 * Node b = new Node(a);      // b is a child of a, therefore,
 * b.setPosition(5, 0, 0);    // it's positoin and rotation are relative to a's.
 * b.getAbsolutePosition();   // Returns Vec3f(-2, 5, 0), b's position relative to the origin.
 *
 * b.setParent(s);            // B is now a child of s.
 * b.getAbsolutePosition();   // Returns Vec3f(5, 0, 0), since it's position is relative
 *                            //to 0, 0, 0, instead of a.
 * --------------------------------
 */
class Node : BaseNode
{
	protected bool 	onscreen = true;		// used internally by cameras to mark if they can see this node.
	protected bool 	visible = true;
	protected Vec3f	scale;
	protected Vec4f color;					// RGBA, used for glColor4f()

	protected LightNode[] lights;			// Lights that affect this Node
	protected float[]     intensities;	// stores the brightness of each light on this Node.

	/// Construct this Node as a child of parent.
	this(BaseNode parent)
	{	debug scope( failure ) writef("Backtrace xx "__FILE__"(",__LINE__,")\n");
		super();
		visible = false;
		scale = Vec3f(1);
		setParent(parent);
	}

	/**
	 * Construct this Node as a copy of another Node and recursively copy all children.
	 * Params:
	 * parent = This Node will be a child of parent.
	 * original = This Node will be an exact copy of original.*/
	this(BaseNode parent, Node original)
	{
		debug scope( failure ) writef("Backtrace xx "__FILE__"(",__LINE__,")\n");
		this(parent);
		setVisible(original.visible);

		transform = original.transform;
		linear_velocity = original.linear_velocity;
		angular_velocity = original.angular_velocity;

		scale = original.scale;

		// Also recursively copy every child
		foreach (inout Node c; original.children.array())
		{	// Scene and BaseNode are never children
			// Is there a better way to do this?
			switch (c.getType())
			{	case "yage.node.node.Node": new Node(this, cast(Node)c); break;
				case "yage.node.camera.CameraNode": new CameraNode(this, cast(CameraNode)c); break;
				case "yage.node.graph.GraphNode": new GraphNode(this, cast(GraphNode)c); break;
				case "yage.node.light.LightNode": new LightNode(this, cast(LightNode)c); break;
				case "yage.node.model.ModelNode": new ModelNode(this, cast(ModelNode)c); break;
				case "yage.node.sound.SoundNode": new SoundNode(this, cast(SoundNode)c); break;
				case "yage.node.sprite.SpriteNode": new SpriteNode(this, cast(SpriteNode)c); break;
				default:
			}
		}
	}

	/// Hopefully a less volatile version of the destructor.
	void remove()
	{	debug scope(failure) writef("Backtrace xx "__FILE__"(",__LINE__,")\n");
		if (index != -1)
		{	parent.children.remove(index);
			if (index < parent.children.length)
				parent.children[index].index = index;
		}

		// this needs to happen because some children may need to do more in their remove() function.
		foreach(Node c; children.array())
			c.remove();
	}

	/**
	 * Set the parent of this Node (what it's attached to) and remove
	 * it from its previous parent.
	 * Returns: A self reference.*/
	Node setParent(BaseNode _parent)
	in { assert(_parent !is null);
	}body
	{	debug scope( failure ) writef("Backtrace xx "__FILE__"(",__LINE__,")\n");

		if (index!=-1)
		{	parent.children.remove(index);
			if (index < parent.children.length) // if not removed from the end.
				parent.children[index].index = index; // update external index.
		}// Add to new parent
		parent = _parent;
		index = parent.children.add(this);
		scene = parent.scene;
		setTransformDirty();
		return this;
	}

	Vec4f getColor()
	{	return color;
	}

	void setColor(Vec4f color)
	{	this.color = color;
	}

	/// Get the radius of this Node's culling sphere.
	float getRadius()
	{	return 1.414213562*scale.max();	// a value of zero would not be rendered since it's always smaller than the pixel threshold.
	}									// This is the radius of a 1x1x1 cube

	/// Get the scale of the Node.
	Vec3f getScale()
	{	return scale;
	}
	/**
	 * Set the scale of this Node in the x, y, and z directions.
	 * The default is (1, 1, 1) */
	void setScale(Vec3f scale)
	{	this.scale = scale;
	}
	/**
	 * Set the scale of this Node in the x, y, and z directions.
	 * The default is (1, 1, 1) */
	void setScale(float scale)
	{	this.scale.set(scale);
	}


	/// Is rendering enabled for this node?
	bool getVisible()
	{	return visible;
	}

	/** Set whether this Node will be renered.  This has nothing to do with frustum culling.
	 *  Setting a Node as invisible will not make its children invisible also. */
	void setVisible(bool visible)
	{	debug scope(failure) writef("Backtrace xx "__FILE__"(",__LINE__,")\n");
		this.visible = visible;
	}

	/** Get whether this node is inside the view frustum and large enough to be drawn by
	 *  the last camera that rendered it. */
	bool getOnscreen()
	{	return onscreen;
	}

	/** Set whether this node is inside the current camera's view frustum.
	 *  This function is used internally by the engine and should not be called manually or exported. */
	void setOnscreen(bool onscreen)
	{	this.onscreen = onscreen;
	}

	/// Return a pointer to the transformation Matrix of this Node.  This is faster than returning a copy.
	Matrix *getTransformPtr()
	{	return &transform;
	}

	/// Return a pointer to the linear velocity Vector of this node.
	Vec3f *getVelocityPtr()
	{	return &linear_velocity;
	}

	/**
	 * Return the relative transformation Matrix of this Node.  This Matrix stores the position
	 * and rotation relative to its parent. */
	Matrix getTransform()
	{	return transform;
	}
	/// Get the absolute transformation Matrix of this Node, calculating it if necessary.
	Matrix getAbsoluteTransform()
	{	if (transform_dirty)
			calcTransform();
		return transform_abs;
	}


	/**
	 * Get the position of this Node relative to its parent's location.
	 * Note that changing the values of the return vector will not affect the Node's position. */
	Vec3f getPosition()
	{	return Vec3f(transform.v[12..15]);
	}
	/**
	 * Get the absolute position of this Node, calculating it if necessary.
	 * Note that changing the values of the return vector will not affect the Node's position. */
	Vec3f getAbsolutePosition()
	{	return Vec3f(getAbsoluteTransform().v[12..15]);
	}


	/**
	 * Get the rotation of this Node relative to its parent's rotation.
	 * Note that changing the values of the return vector will not affect the Node's rotation. */
	Vec3f getRotation()
	{	return transform.toAxis();
	}
	/**
	 * Get the absolute rotation of this Node, calculating it if necessary.
	 * Note that changing the values of the return vector will not affect the Node's rotation. */
	Vec3f getAbsoluteRotation()
	{	return getAbsoluteTransform().toAxis();
	}


	/// Set this Node's relative transformation Matrix.
	void setTransform(Matrix transform)
	{	this.transform = transform;
		setTransformDirty();
	}


	/// Set the position of this node relative to its parent's position and rotation.
	void setPosition(float x, float y, float z)
	{	transform.v[12]=x;
		transform.v[13]=y;
		transform.v[14]=z;
		setTransformDirty();
	}
	/// Set the position of this Node relative to its parent's position and rotation.
	void setPosition(Vec3f position)
	{	setPosition(position.x, position.y, position.z);
	}


	/// Set the rotation of this Node relative to its parent's rotation, using an axis angle.
	void setRotation(float x, float y, float z)
	{	setRotation(Vec3f(x, y, z));
	}
	/// Set the rotation of this Node relative to its parent's rotation, using an axis angle.
	void setRotation(Vec3f axis)
	{	transform.set(axis);
		setTransformDirty();
	}
	/// Set the rotation of this Node relative to its parent's rotation, using a Quaternion.
	void setRotation(Quatrn rotation)
	{	transform.set(rotation);
		setTransformDirty();
	}


	/**
	 * Move and rotate by the transformation Matrix.
	 * In other words, apply t as a transformation Matrix. */
	void transformation(Matrix t)
	{	transform.postMultiply(t);
		setTransformDirty();
	}


	/// Move this Node relative to its current position and its parent.
	void move(float x, float y, float z)
	{	transform.v[12]+=x;
		transform.v[13]+=y;
		transform.v[14]+=z;
		setTransformDirty();
	}
	/// Move this Node relative to its parent.
	void move(Vec3f pos)
	{	transform.v[12]+=pos.x;
		transform.v[13]+=pos.y;
		transform.v[14]+=pos.z;
		setTransformDirty();
	}


	/// Move this Node relative to the direction it's pointing (relative to its rotation).
	void moveRelative(float x, float y, float z)
	{	moveRelative(Vec3f(x, y, z));
	}
	/// Move this Node relative to the direction it's pointing (relative to its rotation).
	void moveRelative(Vec3f direction)
	{	transform = transform.moveRelative(direction);
		setTransformDirty();
	}


	/// Rotate this Node relative to its current rotation axis, using an axis angle
	void rotate(float x, float y, float z)
	{	rotate(Vec3f(x, y, z));
	}
	/// Rotate this Node relative to its current rotation axis, using an axis angle
	void rotate(Vec3f axis)
	{	transform = transform.rotate(axis);
		setTransformDirty();
	}
	/// Rotate this Node relative to its current rotation axis, using a Quaternion
	void rotate(Quatrn rotation)
	{	transform = transform.rotate(rotation);
		setTransformDirty();
	}


	/// Rotate this Node around the absolute worldspace axis, using an axis angle.
	void rotateAbsolute(float x, float y, float z)
	{	rotateAbsolute(Vec3f(x, y, z));
	}
	/// Rotate this Node around the absolute worldspace axis, using an axis angle.
	void rotateAbsolute(Vec3f axis)
	{	transform = transform.rotateAbsolute(axis);
		setTransformDirty();
	}
	/// Rotate this Node around the absolute worldspace axis, using a Quaternion.
	void rotateAbsolute(Quatrn rotation)
	{	transform = transform.rotateAbsolute(rotation);
		setTransformDirty();
	}


	/// Get the velocity of this Node relative to its parent.
	Vec3f getVelocity()
	{	return linear_velocity;
	}

	/// Get the absolute velocity of this Node. TODO: this can be incorrect.
	Vec3f getAbsoluteVelocity()
	{	if (transform_dirty)
			calcTransform();
		return linear_velocity_abs;
	}


	/// Set the velocity of this node relative to its parent's linear and angular velocity.
	void setVelocity(float x, float y, float z)
	{	linear_velocity.set(x, y, z);
	}
	/// Set the velocity of this Node relative to its parent's linear and angular velocity.
	void setVelocity(Vec3f velocity)
	{	linear_velocity = velocity;
	}

	/**
	 * Return the angular velocity axis; the Node rotates around this axis and
	 * the length of this is the rotations per second in radians. */
	Vec3f getAngularVelocity()
	{	return angular_velocity;
	}
	/// Set the angular velocity axis relative to this Node's current rotation.
	void setAngularVelocity(float x, float y, float z)
	{	angular_velocity.set(x, y, z);
	}
	/// Set the angular velocity axis relative to this Node's current rotation.
	void setAngularVelocity(Vec3f axis)
	{	angular_velocity = axis;
	}
	/**
	 * Set the rate of rotation of this Node relative to its parent's rate of rotation, using a Quaternion.
	 * Note that a Quaternion can only store angular values between -2pi and 2pi. */
	void setAngularVelocity(Quatrn rotation)
	{	angular_velocity = rotation.toAxis();
	}

	/*
	/// Set the angular velocity axis relative to the absolute worldspace.
	void setAngularVelocityAbsolute(float x, float y, float z)
	{	setAngularVelocityAbsolute(Vec3f(x, y, z));
	}
	*/

	/// Accelerate the Node in this direction.
	void accelerate(float x, float y, float z)
	{	linear_velocity+=Vec3f(x, y, z);
	}
	/// Accelerate the Node in this direction.
	void accelerate(Vec3f v)
	{	linear_velocity += v;
	}


	/// Accelerate relative to the way this Node is rotated (pointed).
	void accelerateRelative(float x, float y, float z)
	{	accelerateRelative(Vec3f(x, y, z));
	}
	/// Accelerate relative to the way this Node is rotated (pointed).
	void accelerateRelative(Vec3f v)
	{	linear_velocity += v.rotate(transform);
	}


	/// Accelerate the angular velocity of the Node by this axis.
	void angularAccelerate(float x, float y, float z)
	{	angular_velocity += Vec3f(x, y, z);
	}
	/// Accelerate the angular velocity of the Node by this axis.
	void angularAccelerate(Vec3f axis)
	{	angular_velocity += axis;
	}
	/**
	 * Accelerate the angular velocity of the Node by this rotation Quaternion.
	 * Note that a Quaternion can only store angular values between -2pi and 2pi. */
	void angularAccelerate(Quatrn rotation)
	{	angular_velocity += rotation.toAxis();
	}


	/**
	 * Accelerate the rotation of this Node, interpreting the acceleration axis
	 * in terms of absolute worldspace coordinates. */
	void angularAccelerateAbsolute(float x, float y, float z)
	{	angularAccelerateAbsolute(Vec3f(x, y, z));
	}
	/**
	 * Accelerate the rotation of this Node, interpreting the acceleration axis
	 * in terms of absolute worldspace coordinates. */
	void angularAccelerateAbsolute(Vec3f axis)
	{	angular_velocity += axis.rotate(getAbsoluteTransform().inverse());
	}



	/**
	 * Render this Node as a cube.  Note that this Node type is invisible by default.
	 * This function is called automatically as needed by camera.toTexture().*/
	void render()
	{
		// Front Face
		glTexCoord2f(0, 1); glVertex3f(-1, -1, 1);
		glTexCoord2f(1, 1); glVertex3f( 1, -1, 1);
		glTexCoord2f(1, 0); glVertex3f( 1,  1, 1);
		glTexCoord2f(0, 0); glVertex3f(-1,  1, 1);
		// Back Face
		glTexCoord2f(1, 1); glVertex3f(-1, -1, -1);
		glTexCoord2f(1, 0); glVertex3f(-1,  1, -1);
		glTexCoord2f(0, 0); glVertex3f( 1,  1, -1);
		glTexCoord2f(0, 1); glVertex3f( 1, -1, -1);
		// Top Face
		glTexCoord2f(1, 1); glVertex3f(-1,  1, -1);
		glTexCoord2f(1, 0); glVertex3f(-1,  1,  1);
		glTexCoord2f(0, 0); glVertex3f( 1,  1,  1);
		glTexCoord2f(0, 1); glVertex3f( 1,  1, -1);
		// Bottom Face
		glTexCoord2f(0, 1); glVertex3f(-1, -1, -1);
		glTexCoord2f(1, 1); glVertex3f( 1, -1, -1);
		glTexCoord2f(1, 0); glVertex3f( 1, -1,  1);
		glTexCoord2f(0, 0); glVertex3f(-1, -1,  1);
		// Right face
		glTexCoord2f(1, 1); glVertex3f(1, -1, -1);
		glTexCoord2f(1, 0); glVertex3f(1,  1, -1);
		glTexCoord2f(0, 0); glVertex3f(1,  1,  1);
		glTexCoord2f(0, 1); glVertex3f(1, -1,  1);
		// Left Face
		glTexCoord2f(0, 1); glVertex3f(-1, -1, -1);
		glTexCoord2f(1, 1); glVertex3f(-1, -1,  1);
		glTexCoord2f(1, 0); glVertex3f(-1,  1,  1);
		glTexCoord2f(0, 0); glVertex3f(-1,  1, -1);
		glEnd();
	}

	/**
	 * Update the position and rotation of this node based on its velocity and angular velocity.
	 * This function is called automatically as a Scene's update() function recurses through Nodes. */
	void update(float delta)
	{	debug scope( failure ) writef("Backtrace xx "__FILE__"(",__LINE__,")\n");

		// Move by linear velocity if not zero.
		if (linear_velocity.length2() != 0)
			move(linear_velocity*delta);

		// Rotate if angular velocity is not zero.
		if (angular_velocity.length2() !=0)
			rotate(angular_velocity*delta);

		// Recurse through children
		super.update(delta);
	}


	/** Set the transform_dirty flag on this Node and all of its children, if they're not dirty already.
	 *  This should be called whenever a Node is moved or rotated
	 *  This function is used internally by the engine and normally doesn't need to be called. */
	void setTransformDirty()
	{	debug scope( failure ) writef("Backtrace xx "__FILE__"(",__LINE__,")\n");

		if (!transform_dirty)
		{	transform_dirty=true;
			Node[] a = children.array();
			foreach(Node c; children.array())
				c.setTransformDirty();
		}
	}


	/** Enable the lights that most affect this Node.
	 *  All lights that affect this Node can't be enabled, due to hardware and performance
	 *  reasons, so only the lights that affect the node the most are enabled.
	 *  This function is used internally by the engine and should not be called manually or exported.
	 *
	 *  TODO: Take into account a spotlight inside a Node that shines outward but doesn't shine
	 *  on the Node's center.  Need to test to see if this is even broken.
	 * Also perhaps use axis sorting for faster calculations. */
	synchronized void enableLights(ubyte number=8)
	{
		if (number>Device.getLimit(DEVICE_MAX_LIGHTS))
			number = Device.getLimit(DEVICE_MAX_LIGHTS);

		LightNode[] all_lights = scene.getLights();
		lights.length = maxi(number, all_lights.length);
		intensities.length = maxi(number, all_lights.length);
		for (int i=0; i<lights.length; i++)
		{	lights[i] = null;	// clear out old values
			intensities[i] = 0;
		}

		// Calculate the intensity of all lights on this node
		Vec3f position;

		for (int i=0; i<all_lights.length; i++)
		{	LightNode l = all_lights[i];

			// Add to the array of limited lights if bright enough
			position.set(transform_abs);
			float intensity = l.getBrightness(position, getRadius()).average();
			intensities[i] = intensity;
			if (intensity > 0.00390625) // smallest noticeable brightness for 8-bit per channel color (1/256).
			{	for (int j=0; j<number; j++)
				{	// If first light
					if (lights[j] is null)
					{	lights[j] = l;
						break;
					}else
					{	if (intensities[j] < intensity)
						{	// put this light at this spot in the array and shift the others
							for (int n=number-2; n>=j; n--)
								lights[n+1] = lights[n];
							lights[j] = l;
							break;
		}	}	}	}	}

		// Enable the apropriate lights
		for (int i=0; i<number; i++)
			glDisable(GL_LIGHT0+i);
		for (int i=0; i<number; i++)
		{	if (lights[i] !is null)
				lights[i].apply(i);
			else	// Make lights array just as long as it needs to be and no more.
			{	lights.length = i;
				break;
		}	}
	}
}
