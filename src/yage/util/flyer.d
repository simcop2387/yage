/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.util.flyer;

import yage.core.matrix;
import yage.core.misc;
import yage.core.vector;
import yage.node.base;
import yage.node.camera;
import yage.node.node;
import yage.system.input;

/**
 * A class to quickly allow a camera to navigate a scene via keyboard and mouse input. */
class Flyer
{

	Node base;
	Node pivot;
	float ldamp, xdamp, ydamp;


	this(BaseNode parent)
	{	base = new Node(parent);
		pivot = new Node(base);
		ldamp = 16;
		xdamp = ydamp = 24;
	}

	void setBase(Node base)
	{	base = this.base;
	}

	Node getBase()
	{	return base;
	}

	Node getPivot()
	{	return pivot;
	}

	void setParent(Node parent)
	{	base.setParent(parent);
	}

	void accelerate(Vec3f acc)
	{	accelerate(acc.x, acc.y, acc.z);
	}

	void accelerate(float x, float y, float z)
	{	Vec3f acc = Vec3f(x, y, z).rotate(pivot.getTransform()).rotate(base.getTransform());
		base.accelerate(acc);
	}

	void angularAccelerate(float x, float y)
	{	base.angularAccelerate(Vec3f(0, x, 0));
		pivot.angularAccelerate(Vec3f(y, 0, 0));
	}

	void setPosition(Vec3f pos)
	{	base.setPosition(pos);
	}

	void setPosition(float x, float y, float z)
	{	base.setPosition(x, y, z);
	}

	void setRotation(float x, float y)
	{	base.setRotation(Vec3f(0, x, 0));
		pivot.setRotation(Vec3f(y, 0, 0));
	}

	void setDampening(float percent)
	{	ldamp = percent;
	}

	void setAngularDampening(float xpercent, float ypercent)
	{	xdamp = xpercent;
		ydamp = ypercent;
	}

	/// Accept input and apply dampening to the FloatingCamera.
	void update(float delta)
	{
		base.setVelocity(base.getVelocity().scale(max(1-delta*ldamp, 0.0f)));
		pivot.setAngularVelocity(pivot.getAngularVelocity().scale(max(1-delta*xdamp, 0.0f)));
		base.setAngularVelocity(base.getAngularVelocity().scale(max(1-delta*ydamp, 0.0f)));

		float speed = 2000*delta;

		if (Input.keydown[SDLK_w] || Input.keydown[SDLK_UP])
			accelerate(0, 0, -speed);
		if (Input.keydown[SDLK_s] || Input.keydown[SDLK_DOWN])
			accelerate(0, 0, speed);
		if (Input.keydown[SDLK_a] || Input.keydown[SDLK_LEFT])
			accelerate(-speed, 0, 0);
		if (Input.keydown[SDLK_d] || Input.keydown[SDLK_RIGHT])
			accelerate(speed, 0, 0);

// 		if (Input.getGrabMouse())
// 		{	Vec2f movement = Input.getMouseDelta();
// 			angularAccelerate(-movement.x/12.0, movement.y/16.0);
// 		}
	}

}
