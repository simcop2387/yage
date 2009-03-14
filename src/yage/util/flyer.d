/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.util.flyer;

import tango.math.Math;

import yage.core.all;
import yage.scene.node;
import yage.scene.camera;
import yage.scene.movable;
import yage.system.input;

/**
 * A class to quickly allow a camera to navigate a scene via keyboard and mouse input. 
 * This is out of date and needs to be updated for the new input system. */
class Flyer
{

	MovableNode base;
	MovableNode pivot;
	float ldamp, xdamp, ydamp;


	this(Node parent)
	{	base = parent.addChild(new MovableNode());
		pivot = base.addChild(new MovableNode());
		ldamp = 16;
		xdamp = ydamp = 24;
	}

	void setBase(MovableNode base)
	{	base = this.base;
	}

	MovableNode getBase()
	{	return base;
	}

	MovableNode getPivot()
	{	return pivot;
	}

	void accelerate(Vec3f acc)
	{	Vec3f acc2 = acc.rotate(pivot.getTransform()).rotate(base.getTransform());
		base.accelerate(acc2);
	}

	void angularAccelerate(float x, float y)
	{	base.angularAccelerate(Vec3f(0, x, 0));
		pivot.angularAccelerate(Vec3f(y, 0, 0));
	}

	void setPosition(Vec3f pos)
	{	base.setPosition(pos);
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

		/*// TODO: update for the new input system.
		if (Input.keyDown[SDLK_w] || Input.keyDown[SDLK_UP])
			accelerate(Vec3f(0, 0, -speed));
		if (Input.keyDown[SDLK_s] || Input.keyDown[SDLK_DOWN])
			accelerate(Vec3f(0, 0, speed));
		if (Input.keyDown[SDLK_a] || Input.keyDown[SDLK_LEFT])
			accelerate(Vec3f(-speed, 0, 0));
		if (Input.keyDown[SDLK_d] || Input.keyDown[SDLK_RIGHT])
			accelerate(Vec3f(speed, 0, 0));
		
 		if (Input.getGrabMouse())
 		{	Vec2f movement = Input.getMouseDelta();
 			angularAccelerate(-movement.x/12.0, movement.y/16.0);
 		}
		*/
	}

}
