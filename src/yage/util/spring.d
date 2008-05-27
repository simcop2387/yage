/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.util.spring;

import std.stdio;
import yage.core.all;
import yage.node.all;


// Can be used to attach one node to another in a springy way.
// Good for third person cameras
// Totally wigs out if stiffness is greater than the framerate?
class Spring
{
	MovableNode		head;
	MovableNode		tail;
	Vec3f		distance;
	float		stiffness = 16; // arbitrary

	this(VisibleNode head)
	{	this.head = head;
		tail = new MovableNode(head.getScene());
		distance = Vec3f(0, 2, 6);
	}

	Vec3f getDistance()
	{	return distance;
	}

	void setDistance(Vec3f dist)
	{	distance = dist;
	}

	float getStiffness()
	{	return stiffness;
	}

	void setStiffness(float s)
	{	stiffness = s;
	}

	MovableNode getHead()
	{	return head;
	}

	MovableNode getTail()
	{	return tail;
	}


	/// Update the position of the floater relative to what it's attached to.
	void update(float delta){
		tail.setRotation(head.getAbsoluteRotation());

		Vec3f dist = head.getAbsolutePosition() - tail.getAbsolutePosition() + distance.rotate(head.getAbsoluteTransform());
		Vec3f vel = dist.scale(min(stiffness, 1/delta)); // scale by 1/delta when framerate is low to prevent jerkiness.

		if (vel.length*delta > dist.length)
			vel = dist;
		tail.setVelocity(vel);
	}
}
