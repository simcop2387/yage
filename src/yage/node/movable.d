/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.movable;

import std.stdio;
import yage.core.matrix;
import yage.core.vector;
import yage.node.base;
import yage.node.node;
import yage.core.misc;

/**
 * Nodes have numerous methods for changing position and velocity.
 * They are separated into this templated mixin to reduce the length of base.d and keep things better organized.
 * See_Also:
 * yage.node.Node
 * yage.node.BaseNode */
class MovableNode : BaseNode
{
	/**
	 * Move and rotate by the transformation Matrix.
	 * In other words, apply t as a transformation Matrix. */
	void transformation(Matrix t)
	{	transform.postMultiply(t);
		setTransformDirty();
	}

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
	
	/**
	 * Return the relative transformation Matrix of this Node.  This Matrix stores the position
	 * and rotation relative to its parent.
	 * Params:
	 * cached = Get the transformation Matrix cached after the last complete scenegraph update,
	 * instead of the current version.  This can be used to avoid working with a half-updated scenegraph.*/
	Matrix getTransform(bool cached = false)
	{	if (cached)
			return cache[getScene().transform_read].transform;
		return transform;
	}
	void setTransform(Matrix transform) /// Ditto
	{	this.transform = transform;
		setTransformDirty();
	}
	
	/**
	 * Get the absolute transformation Matrix of this Node, calculating it if necessary.
	 * Params:
	 * cached = Get the absolute transformation Matrix cached after the last complete scenegraph update,
	 * instead of the current version.  This can be used to avoid working with a half-updated scenegraph.*/
	Matrix getAbsoluteTransform(bool cached = false)
	{	if (cached) // the transform_abs cache is never dirty
			return cache[scene.transform_read].transform_abs;
		if (transform_dirty)
			calcTransform();
		return transform_abs;
	}
	
	/**
	 * Get / set the position of this Node relative to its parent's location.
	 * Note that changing the values of the return vector will not affect the Node's position. */
	Vec3f getPosition()
	{	return Vec3f(transform.v[12..15]);
	}
	void setPosition(Vec3f position)
	{	transform.v[12..15] = position.v[0..3];
		setTransformDirty();
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
	void setRotation(Vec3f axis) /// Ditto
	{	transform.set(axis);
		setTransformDirty();
	}
	
	/**
	 * Get the absolute rotation of this Node, calculating it if necessary.
	 * Note that changing the values of the return vector will not affect the Node's rotation. */
	Vec3f getAbsoluteRotation()
	{	return getAbsoluteTransform().toAxis();
	}

	/// Get / set the velocity of this Node relative to its parent's linear and angular velocity.
	void setVelocity(Vec3f velocity)
	{	linear_velocity = velocity; 
	} 
	Vec3f getVelocity() /// Ditto
	{	return linear_velocity;
	}

	/// Get the absolute velocity of this Node. TODO: this can be incorrect.
	Vec3f getAbsoluteVelocity()
	{	if (transform_dirty)
			calcTransform();
		return linear_velocity_abs;
	}

	/**
	 * Get/set this Node's angular velocity relative to it's parent's rotation and angular velocity.
	 * This is represented in an axis-angle vector where the direction is the axis of rotation and the 
	 * length is the rotation in radians. */
	Vec3f getAngularVelocity() 
	{	return angular_velocity;
	}	
	void setAngularVelocity(Vec3f axis) /// Ditto
	{	angular_velocity = axis; 
	}
	
	
	
	// Incomplete
	// Might also consider a function to return a rotation vector needed to rotate to look at target.
	void lookAt(Vec3f target, Vec3f up)
	{	Vec3f f = target.normalize();
		up = up.normalize();

		Vec3f s = f.cross(up).normalize();
		Vec3f u = s.cross(f);

		setRotation(Vec3f(0, 0, 0));
		rotate(u);
	}

	/// Move this Node relative to its parent.
	void move(Vec3f distance)
	{	transform.v[12]+=distance.x;
		transform.v[13]+=distance.y;
		transform.v[14]+=distance.z;
		setTransformDirty();
	}

	/// Move this Node relative to the direction it's pointing (relative to its rotation).
	void moveRelative(Vec3f direction) 
	{	transform = transform.moveRelative(direction);
		setTransformDirty();
	}

	/// Rotate this Node relative to its current rotation axis, using an axis angle
	void rotate(Vec3f axis)
	{	transform = transform.rotate(axis);
		setTransformDirty();
	}

	/// Rotate this Node around the absolute worldspace axis, using an axis angle.
	void rotateAbsolute(Vec3f axis) 
	{	transform = transform.rotateAbsolute(axis);
		setTransformDirty();
	}

	/// Accelerate the Node in the direction specified
	void accelerate(Vec3f v)
	{	linear_velocity += v; 
	}

	/// Accelerate relative to the way this Node is rotated (pointed).
	void accelerateRelative(Vec3f v)
	{	linear_velocity += v.rotate(transform); 
	}

	/// Accelerate the angular velocity of the Node by this axis.
	void angularAccelerate(Vec3f axis)
	{	angular_velocity += axis; 
	}

	/**
	 * Accelerate the rotation of this Node, interpreting the acceleration axis
	 * in terms of absolute worldspace coordinates. */
	void angularAccelerateAbsolute(Vec3f axis)
	{	angular_velocity += axis.rotate(getAbsoluteTransform().inverse()); 
	}
}
