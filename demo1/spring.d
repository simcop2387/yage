/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty:   none
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module demo1.spring;

import yage.core.all;
import yage.scene.all;


// Can be used to attach one node to another in a springy way.
// Good for third person cameras
// Totally wigs out if stiffness is greater than the framerate?
class Spring
{
	Node		head;
	Node		tail;
	Vec3f		distance;
	float		stiffness = 16; // arbitrary

	this(Node head, Node tail)
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

	Node getHead()
	{	return head;
	}

	Node getTail()
	{	return tail;
	}
	
	//void setTail(MovableNode tail)
	//{	this.tail = tail;
	//}

	/// Update the position of the floater relative to what it's attached to.
	void update(float delta){
		tail.setRotation(head.getWorldRotation());

		Vec3f dist = head.getWorldPosition() + distance.rotate(head.getWorldTransform()) - tail.getWorldPosition();		
		Vec3f vel = dist.scale(stiffness); 

		if (vel.length*delta > dist.length)
			vel = dist;		
		tail.move(vel*delta);
	}
}
