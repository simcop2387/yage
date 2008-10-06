/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.util.spring;

import std.stdio;
import yage.core.all;
import yage.scene.all;


// Can be used to attach one node to another in a springy way.
// Good for third person cameras
// Totally wigs out if stiffness is greater than the framerate?
class Spring
{
	MovableNode		head;
	MovableNode		tail;
	Vec3f		distance;
	float		stiffness = 16; // arbitrary

	this(MovableNode head, MovableNode tail)
	{	this.head = head;
		this.tail = tail;
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
	
	//void setTail(MovableNode tail)
	//{	this.tail = tail;
	//}

	/// Update the position of the floater relative to what it's attached to.
	void update(float delta){
		tail.setRotation(head.getAbsoluteRotation());

		Vec3f dist = head.getAbsolutePosition() + distance.rotate(head.getAbsoluteTransform()) - tail.getAbsolutePosition();		
		Vec3f vel = dist.scale(stiffness); 

		if (vel.length*delta > dist.length)
			vel = dist;		
		tail.move(vel*delta);
	}
}
