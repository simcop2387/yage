/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.moveable;

import std.stdio;
import yage.core.matrix;
import yage.core.vector;
import yage.node.basenode;
import yage.node.node;



/**
 * Nodes have numerous methods for changing position and velocity.
 * They are separated into this abstract class.
 * See_Also:
 * yage.node.Node
 * yage.node.BaseNode */
abstract class MoveableNode : BaseNode
{
	/// Return a pointer to the transformation Matrix of this Node.  This is faster than returning a copy.
	Matrix *getTransformPtr()
	{	return &transform;
	}

	/// Return a pointer to the transformation Matrix of this Node.  This is faster than returning a copy.
	Matrix *getAbsoluteTransformPtr()
	{	if (transform_dirty)
			calcTransform();
		return &transform_abs;
	}

	/// Return a pointer to the linear velocity Vector of this node.
	Vec3f *getVelocityPtr()
	{	return &linear_velocity;
	}

	/// Return a pointer to the angular velocity Vector of this node.
	Vec3f *getAngularVelocityPtr()
	{	return &angular_velocity;
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
	/// Ditto
	void setPosition(Vec3f position)
	{	setPosition(position.x, position.y, position.z);
	}


	/// Set the rotation of this Node relative to its parent's rotation, using an axis angle.
	void setRotation(float x, float y, float z)
	{	setRotation(Vec3f(x, y, z));
	}
	/// Ditto
	void setRotation(Vec3f axis)
	{	transform.set(axis);
		setTransformDirty();
	}


	/**
	 * Move and rotate by the transformation Matrix.
	 * In other words, apply t as a transformation Matrix. */
	void transformation(Matrix t)
	{	transform.postMultiply(t);
		setTransformDirty();
	}

	/// Move this Node relative to its parent.
	void move(float x, float y, float z)
	{	move(Vec3f(x, y, z));
	}
	/// Ditto
	void move(Vec3f distance)
	{	transform.v[12]+=distance.x;
		transform.v[13]+=distance.y;
		transform.v[14]+=distance.z;
		setTransformDirty();
	}

	/// Move this Node relative to the direction it's pointing (relative to its rotation).
	void moveRelative(float x, float y, float z)
	{	moveRelative(Vec3f(x, y, z));
	}
	/// Ditto
	void moveRelative(Vec3f direction)
	{	transform = transform.moveRelative(direction);
		setTransformDirty();
	}

	/// Rotate this Node relative to its current rotation axis, using an axis angle
	void rotate(float x, float y, float z)
	{	rotate(Vec3f(x, y, z));
	}
	/// Ditto
	void rotate(Vec3f axis)
	{	transform = transform.rotate(axis);
		setTransformDirty();
	}

	/// Rotate this Node around the absolute worldspace axis, using an axis angle.
	void rotateAbsolute(float x, float y, float z)
	{	rotateAbsolute(Vec3f(x, y, z));
	}
	/// Ditto
	void rotateAbsolute(Vec3f axis)
	{	transform = transform.rotateAbsolute(axis);
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

	/// Set the velocity of this Node relative to its parent's linear and angular velocity.
	void setVelocity(float x, float y, float z)
	{	linear_velocity.set(x, y, z);
	}
	/// Ditto
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
	/// Ditto
	void setAngularVelocity(Vec3f axis)
	{	angular_velocity = axis;
	}

	/// Accelerate the Node in the direction specified
	void accelerate(float x, float y, float z)
	{	accelerate(Vec3f(x, y, z));
	}
	/// Ditto
	void accelerate(Vec3f v)
	{	linear_velocity += v;
	}

	/// Accelerate relative to the way this Node is rotated (pointed).
	void accelerateRelative(float x, float y, float z)
	{	accelerateRelative(Vec3f(x, y, z));
	}
	/// Ditto
	void accelerateRelative(Vec3f v)
	{	linear_velocity += v.rotate(transform);
	}

	/// Accelerate the angular velocity of the Node by this axis.
	void angularAccelerate(float x, float y, float z)
	{	angularAccelerate(Vec3f(x, y, z));
	}
	/// Ditto
	void angularAccelerate(Vec3f axis)
	{	angular_velocity += axis;
	}

	/**
	 * Accelerate the rotation of this Node, interpreting the acceleration axis
	 * in terms of absolute worldspace coordinates. */
	void angularAccelerateAbsolute(float x, float y, float z)
	{	angularAccelerateAbsolute(Vec3f(x, y, z));
	}
	/// Ditto
	void angularAccelerateAbsolute(Vec3f axis)
	{	angular_velocity += axis.rotate(getAbsoluteTransform().inverse());
	}

	/** Set the transform_dirty flag on this Node and all of its children, if they're not dirty already.
	 *  This should be called whenever a Node is moved or rotated
	 *  This function is used internally by the engine usually doesn't need to be called manually. */
	void setTransformDirty()
	{	debug scope( failure ) writef("Backtrace xx "__FILE__"(",__LINE__,")\n");

		if (!transform_dirty)
		{	transform_dirty=true;
			foreach(Node c; children.array())
				c.setTransformDirty();
		}
	}

}
