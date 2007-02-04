/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module yage.ship;

import std.stdio;
import yage.core.all;
import yage.node.basenode;
import yage.node.node;
import yage.node.model;
import yage.node.sprite;
import yage.node.sound;
import yage.system.input;
import yage.resource.material;
import yage.resource.resource;
import yage.util.flyer;
import yage.util.spring;
import yage.universe;
import yage.gameobj;

class Ship : GameObject
{
	Node pitch;			// attached to this node to look up and down
	ModelNode ship;		// attached to pitch and rolls left & right
	Spring spring;		// spring to attach camera
	SoundNode sound;

	float ldamp=.5, xdamp=2, ydamp=2;

	this(BaseNode parent)
	{	// Ship
		super(parent);

		pitch = new Node(this);

		ship = new ModelNode(pitch);
		ship.setModel("scifi/fighter.ms3d");
		ship.setScale(.25);

		spring = new Spring(ship);
		spring.setDistance(Vec3f(0, 2, 6));
		spring.setStiffness(1);

		sound = new SoundNode(ship);
		sound.setSound("sound/ship_eng.ogg");
		sound.setLooping(true);

		// Preload
		new Material("fx/smoke.xml");
		new Material("fx/flare1.xml");
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
	{
		super.update(delta);

		// Set the acceleration speed
		float speed = 100*delta;
		if (Input.keydown[SDLK_q])
			speed *= 20; // Hyperdrive

		if (Input.keydown[SDLK_j])
			angularAccelerate(Vec3f(0, -0.001, 0));
		if (Input.keydown[SDLK_k])
			angularAccelerate(Vec3f(0, 0.001, 0));

		// Accelerate forward
		if (Input.keydown[SDLK_UP] || Input.keydown[SDLK_w])
		{
			accelerate(Vec3f(0, 0, -speed).rotate(pitch.getTransform()).rotate(getTransform()));
			sound.play();

			//Vec3f vel = Vec3f(0, 0, -1).rotate(pitch.getAbsoluteRotation()).scale(getVelocity().length()).s;

			// Engine smoke
			SpriteNode puff = new SpriteNode(ship.getScene());
			puff.setMaterial(Resource.material("fx/smoke.xml"));
			puff.setLifetime(1);
			puff.setScale(.4);
			//puff.setVelocity(vel);
			puff.setPosition(ship.getAbsolutePosition()+Vec3f(.8, 0, 2.5).rotate(ship.getAbsoluteTransform()));

			puff = new SpriteNode(ship.getScene());
			puff.setMaterial("fx/smoke.xml");
			puff.setLifetime(1);
			puff.setScale(.4);
			//puff.setVelocity(vel);
			puff.setPosition(ship.getAbsolutePosition()+Vec3f(-.8, 0, 2.5).rotate(ship.getAbsoluteTransform()));
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
		if (Input.getGrabMouse())
		{	angularAccelerate(Vec3f(0, -Input.mousedx/16.0, 0));
			pitch.angularAccelerate(Vec3f(Input.mousedy/24.0, 0, 0));
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
		setVelocity(getVelocity().scale(maxf(1-delta*ldamp, 0.0f)));
		pitch.setAngularVelocity(pitch.getAngularVelocity().scale(maxf(1-delta*xdamp, 0.0f)));
		setAngularVelocity(getAngularVelocity().scale(maxf(1-delta*ydamp, 0.0f)));

		// Update the spring
		if (spring.getStiffness()<24)
			spring.setStiffness(spring.getStiffness*(delta+1));

		// Fire a flare
		if (Input.keydown[SDLK_SPACE])
		{
			Flare flare = new Flare(ship.getScene());
			flare.setPosition(ship.getAbsolutePosition());
			flare.setVelocity(Vec3f(0, 0, -400).rotate(ship.getAbsoluteTransform())+getVelocity());

			SoundNode zap = new SoundNode(ship);
			zap.setSound("sound/laser.wav");
			zap.setVolume(.3);
			zap.setLifetime(2);
			zap.play();
		}


	}
}
