/**
 * Copyright:  (c) 2006 Eric Poggel
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
	Node		head;
	Node		tail;
	Vec3f		distance;
	float		stiffness = 16; // arbitrary

	this(Node head)
	{	this.head = head;
		tail = new Node(head.getScene());
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

	Node getHead()
	{	return head;
	}

	Node getTail()
	{	return tail;
	}


	/// Update the position of the floater relative to what it's attached to.
	void update(float delta)
	{	Vec3f dist = (head.getAbsolutePosition() + distance.rotate(head.getAbsoluteTransform())) - tail.getAbsolutePosition();
		Vec3f vel = dist.scale(stiffness);
		if (vel.scale(delta).length2 >= dist.length2)
			vel = dist.scale(1/delta);
		tail.setVelocity(vel);
		tail.setRotation(head.getAbsoluteRotation());
	}
}
