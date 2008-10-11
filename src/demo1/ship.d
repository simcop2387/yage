/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty: none
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module demo1.ship;

import std.stdio;
import yage.all;
import demo1.gameobj;

class Ship : GameObject
{
	MovableNode pitch;			// attached to this node to look up and down
	ModelNode ship;		// attached to pitch and rolls left & right
	Spring spring;		// spring to attach camera
	SoundNode sound;
	
	Vec2i mouseDelta;
	bool input = false;

	float ldamp=.5, xdamp=2, ydamp=2;

	this()
	{
		super();
		new Material("fx/smoke.xml");
		new Material("fx/flare1.xml");

		pitch = addChild(new MovableNode());

		ship = pitch.addChild(new ModelNode());
		ship.setModel("scifi/fighter.ms3d");
		ship.setSize(Vec3f(.25));

		spring = new Spring(ship, new MovableNode());
		spring.setDistance(Vec3f(0, 4, 12));
		spring.setStiffness(1);

		sound = ship.addChild(new SoundNode());
		sound.setSound("sound/ship_eng.ogg");
		sound.setLooping(true);
	}

	ModelNode getShip()
	{	return ship;
	}

	MovableNode getCameraSpot()
	{	if (!(spring.getTail().getScene()))
			getScene().addChild(spring.getTail());
		
		
		
		return spring.getTail();
	}

	Spring getSpring()
	{	return spring;
	}

	void update(float delta)
	{	super.update(delta);

		// Set the acceleration speed
		float speed = 50*delta;
		if (Input.keyDown[SDLK_q])
			speed *= 20; // Hyperdrive

		// Accelerate forward
		if (Input.keyDown[SDLK_UP] || Input.keyDown[SDLK_w])
		{
			accelerate(Vec3f(0, 0, -speed).rotate(pitch.getTransform()).rotate(getTransform()));

			// Engine smoke
			SpriteNode puff = getScene().addChild(new SpriteNode());
			puff.setMaterial(Resource.material("fx/smoke.xml"));
			puff.setLifetime(5);
			puff.setSize(Vec3f(.4));
			//puff.setVelocity(getVelocity() - Vec3f(0, 0, -10).rotate(ship.getAbsoluteTransform()));
			puff.setPosition(ship.getAbsolutePosition()+Vec3f(.8, 0, 2.5).rotate(ship.getAbsoluteTransform()));
			
			void fade(Node self)
			{	SpriteNode node = cast(SpriteNode)self;
				node.setColor(Color(1, 1, 1, node.getLifetime()/5));
				float scale = std.math.sqrt(5.0f)-std.math.sqrt(node.getLifetime()) + .4;
				node.setSize(scale);
			}
			puff.onUpdate(&fade);

			puff = ship.getScene().addChild(puff.clone());
			puff.setPosition(ship.getAbsolutePosition()+Vec3f(-.8, 0, 2.5).rotate(ship.getAbsoluteTransform()));
			
			
			sound.play();
		}
		else
			sound.stop();

		// Accelerate left, right, and backward
		if (Input.keyDown[SDLK_LEFT] || Input.keyDown[SDLK_a])
			accelerate(Vec3f(-speed/6, 0, 0).rotate(pitch.getTransform()).rotate(getTransform()));
		if (Input.keyDown[SDLK_RIGHT] || Input.keyDown[SDLK_d])
			accelerate(Vec3f(speed/6, 0, 0).rotate(pitch.getTransform()).rotate(getTransform()));
		if (Input.keyDown[SDLK_DOWN] || Input.keyDown[SDLK_s])
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
		if (Input.keyDown[SDLK_SPACE])
		{
			Flare flare = ship.getScene().addChild(new Flare());
			flare.setPosition(ship.getAbsolutePosition());
			flare.setVelocity(Vec3f(0, 0, -600).rotate(ship.getAbsoluteTransform())+getVelocity());

			SoundNode zap = ship.addChild(new SoundNode());
			zap.setSound("sound/laser.wav");
			zap.setVolume(.3);
			zap.setLifetime(2);
			zap.play();
		}
	}
}
