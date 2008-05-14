/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module demo1.ship;

import std.stdio;
import yage.all;
import demo1.gameobj;

class Ship : GameObject
{
	Node pitch;			// attached to this node to look up and down
	ModelNode ship;		// attached to pitch and rolls left & right
	Spring spring;		// spring to attach camera
	SoundNode sound;
	
	Vec2i mouseDelta;
	bool input = false;

	float ldamp=.5, xdamp=2, ydamp=2;

	synchronized this(BaseNode parent)
	{
		super(parent);
		new Material("fx/smoke.xml");
		new Material("fx/flare1.xml");

		pitch = new Node(this);

		ship = new ModelNode(pitch);
		ship.setModel("scifi/fighter.ms3d");
		ship.scale = Vec3f(.25);

		spring = new Spring(ship);
		spring.setDistance(Vec3f(0, 4, 12));
		spring.setStiffness(1);

		sound = new SoundNode(ship);
		sound.setSound("sound/ship_eng.ogg");
		sound.setLooping(true);
	}

	ModelNode getShip()
	{	return ship;
	}

	Node getCameraSpot()
	{	return spring.getTail();
	}

	Spring getSpring()
	{	return spring;
	}

	void update(float delta)
	{	debug scope(failure) writef("Backtrace xx ",__FILE__,"(",__LINE__,")\n");

		super.update(delta);

		// Set the acceleration speed
		float speed = 50*delta;
		if (Input.keydown[SDLK_q])
			speed *= 20; // Hyperdrive

		// Accelerate forward
		if (Input.keydown[SDLK_UP] || Input.keydown[SDLK_w])
		{
			accelerate(Vec3f(0, 0, -speed).rotate(pitch.getTransform()).rotate(getTransform()));
			Vec3f vel = Vec3f(0, 0, -.8).rotate(pitch.getAbsoluteRotation()).scale(getVelocity().length());

			// Engine smoke
			SpriteNode puff = new SpriteNode(ship.getScene());
			puff.setMaterial(Resource.material("fx/smoke.xml"));
			puff.setLifetime(1);
			puff.scale = Vec3f(.4);
			//puff.setVelocity(vel);
			puff.setPosition(ship.getAbsolutePosition()+Vec3f(.8, 0, 2.5).rotate(ship.getAbsoluteTransform()));

			puff = new SpriteNode(ship.getScene(), puff);
			puff.setPosition(ship.getAbsolutePosition()+Vec3f(-.8, 0, 2.5).rotate(ship.getAbsoluteTransform()));

			sound.play();
		}
		else
			sound.stop();

		// Accelerate left, right, and backward
		if (Input.keydown[SDLK_LEFT] || Input.keydown[SDLK_a])
			accelerate(Vec3f(-speed/6, 0, 0).rotate(pitch.getTransform()).rotate(getTransform()));
		if (Input.keydown[SDLK_RIGHT] || Input.keydown[SDLK_d])
			accelerate(Vec3f(speed/6, 0, 0).rotate(pitch.getTransform()).rotate(getTransform()));
		if (Input.keydown[SDLK_DOWN] || Input.keydown[SDLK_s])
			accelerate(Vec3f(0, 0, speed/3).rotate(pitch.getTransform()).rotate(getTransform()));

		// Rotate
		if (input){
			angularAccelerate(Vec3f(0, -mouseDelta.x/16.0, 0));
			pitch.angularAccelerate(Vec3f(mouseDelta.y/24.0, 0, 0));
			mouseDelta.x = mouseDelta.y = 0;
		}

		// Bank on turn
		float turn = getAngularVelocity().y;
		float cur = ship.getRotation().z;
		if (cur > 1 || cur < -1)	// Prevent banking too far
			ship.setAngularVelocity(Vec3f(0, 0, -cur/16));
		else
			ship.setAngularVelocity(Vec3f(0, 0, (turn-cur)));

		// Clamp turning speed
		setAngularVelocity(getAngularVelocity().clamp(-3, 3));
		pitch.setAngularVelocity(pitch.getAngularVelocity().clamp(-3, 3));

		// Apply linear and angular dampening
		setVelocity(getVelocity().scale(max(1-delta*ldamp, 0.0f)));
		pitch.setAngularVelocity(pitch.getAngularVelocity().scale(max(1-delta*xdamp, 0.0f)));
		setAngularVelocity(getAngularVelocity().scale(max(1-delta*ydamp, 0.0f)));

		// Update the spring
		if (spring.getStiffness()<50)
			spring.setStiffness(spring.getStiffness*(delta+1));
		// Fire a flare
		if (Input.keydown[SDLK_SPACE])
		{
			Flare flare = new Flare(ship.getScene());
			flare.setPosition(ship.getAbsolutePosition());
			flare.setVelocity(Vec3f(0, 0, -600).rotate(ship.getAbsoluteTransform())+getVelocity());

			SoundNode zap = new SoundNode(ship);
			zap.setSound("sound/laser.wav");
			zap.setVolume(.3);
			zap.setLifetime(2);
			zap.play();
		}
	}
}
