/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty:   none
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module demo1.ship;

import tango.math.Math;
import yage.all;
import demo1.gameobj;
import demo1.spring;

class Ship : GameObject
{
	Node pitch;			// attached to this node to look up and down
	ModelNode ship;		// attached to pitch and rolls left & right
	Spring spring;		// spring to attach camera
	SoundNode sound;
	
	struct Input
	{	bool up;
		bool right;
		bool down;
		bool left;
		bool shoot;
		bool hyper;
		
		Vec2i mouseDelta;	
	}
	Input input;
	
	
	bool acceptInput = false;

	float ldamp=.5, xdamp=2, ydamp=2;

	this()
	{
		super();

		pitch = addChild(new Node());

		ship = pitch.addChild(new ModelNode());
		ship.setModel("space/fighter.dae");
		ship.setSize(Vec3f(.25));

		spring = new Spring(ship, new Node());
		spring.setDistance(Vec3f(0, 4, 12));
		spring.setStiffness(1);

		sound = ship.addChild(new SoundNode());
		sound.setSound("sound/ship-engine.ogg");
		sound.volume = .3;
		sound.looping = true;
	}

	ModelNode getShip()
	{	return ship;
	}

	Node getCameraSpot()
	{	if (!(spring.getTail().getScene()))
			getScene().addChild(spring.getTail());
		
		
		
		return spring.getTail();
	}

	Spring getSpring()
	{	return spring;
	}

	void keyDown(dchar key)
	{	keyToggle(key, true);	
	}
	void keyUp(dchar key)
	{	keyToggle(key, false);
	}
	
	void keyToggle(dchar key, bool on)
	{
		if (key==SDLK_UP || key==SDLK_w)
			input.up = on;
		if (key==SDLK_LEFT || key==SDLK_a)
			input.left = on;
		if (key==SDLK_RIGHT || key==SDLK_d)
			input.right = on;
		if (key==SDLK_DOWN || key==SDLK_s)
			input.down = on;
		if (key==SDLK_SPACE)
			input.shoot = on;
		if (key==SDLK_q)
			input.hyper = on;
	}
	
	void update(float delta)
	{	super.update(delta);

		// Set the acceleration speed
		float speed = 50*delta;
		if (input.hyper)
			speed *= 40; // Hyperdrive

		// Accelerate forward
		if (input.up)
		{
			accelerate(Vec3f(0, 0, -speed).rotate(pitch.getTransform()).rotate(getTransform()));

			// Engine smoke
			GameObject puff = getScene().addChild(new GameObject());
			SpriteNode puffSprite = puff.addChild(new SpriteNode());
			Material smoke = ResourceManager.material("fx/smoke.dae", "smoke-material");
			puffSprite.material = smoke.dup();
			puff.lifetime = 5;
			puff.setScale(Vec3f(.3));
			puff.setVelocity(getVelocity() - Vec3f(0, 0, -10).rotate(ship.getWorldTransform()));
			puff.setPosition(ship.getWorldPosition()+Vec3f(.8, 0, 2.5).rotate(ship.getWorldTransform()));
			
			void fade(GameObject node, float delta)
			{	node.update(delta);
				auto sprite = (cast(SpriteNode)(node.getChildren[0]));
				sprite.material.getPass().diffuse.a = cast(ubyte)(node.lifetime * 51);
				node.setScale(Vec3f(5-node.lifetime + .3));
				node.setVelocity(node.getVelocity().scale(1-1/30f));
			}
			puff.onUpdate = curry(&fade, puff, delta);
		
			puff = cast(GameObject)puff.clone();
			getScene().addChild(puff);
			puff.setPosition(ship.getWorldPosition()+Vec3f(-.8, 0, 2.5).rotate(ship.getWorldTransform()));
			puff.onUpdate = curry(&fade, puff, delta);
			
			if (sound.paused())
				sound.play();
		}
		else
			if (!sound.paused())
				sound.stop();

		// Accelerate left, right, and backward
		if (input.left)
			accelerate(Vec3f(-speed/6, 0, 0).rotate(pitch.getTransform()).rotate(getTransform()));	
		if (input.right)
			accelerate(Vec3f(speed/6, 0, 0).rotate(pitch.getTransform()).rotate(getTransform()));
		if (input.down)
			accelerate(Vec3f(0, 0, speed/3).rotate(pitch.getTransform()).rotate(getTransform()));

		// Rotate
		if (acceptInput){
			angularAccelerate(Vec3f(0, -input.mouseDelta.x/16.0, 0));
			pitch.angularAccelerate(Vec3f(input.mouseDelta.y/24.0, 0, 0));
			input.mouseDelta.x = input.mouseDelta.y = 0;
		}

		// Bank on turn
		float turn = getAngularVelocity().y;
		float cur = ship.getRotation().z;
		if (cur > 1 || cur < -1)	// Prevent banking too far
			ship.setAngularVelocity(Vec3f(0, 0, -cur/32));
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
		if (input.shoot)
		{
			Flare flare = ship.getScene().addChild(new Flare());
			flare.setPosition(ship.getWorldPosition());
			flare.setVelocity(Vec3f(0, 0, -600).rotate(ship.getWorldTransform())+getVelocity());
			
			//input.shoot = false;
		}
	}
}
