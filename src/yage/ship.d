/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.ship;

import yage.core.all;
import yage.node.basenode;
import yage.node.node;
import yage.node.light;
import yage.node.model;
import yage.node.sprite;
import yage.node.sound;
import yage.system.input;
import yage.resource.material;
import yage.resource.resource;
import yage.util.flyer;
import yage.util.spring;
import yage.universe;

class Ship
{
	Flyer flyer;
	Spring spring;
	Node attach;
	ModelNode ship;
	SoundNode sound;

	LightNode light;

	this(BaseNode parent)
	{	// Ship
		flyer = new Flyer(parent);
		attach = new ModelNode(flyer.getPivot());
		ship = new ModelNode(attach);
		ship.setModel("space/fighter.ms3d");
		spring = new Spring(attach);

		Material matl = new Material("fx/smoke.xml");

		ship.setScale(.25);
		spring.setDistance(Vec3f(0, 2, 6));
		spring.setStiffness(1);
		flyer.setDampening(.5);
		flyer.setAngularDampening(2, 2);

		sound = new SoundNode(ship);
		sound.setSound("sound/ship_eng.ogg");
		sound.setLooping(true);

		light = new LightNode(ship);
		light.setDiffuse(1, .5, 0);
		light.setLightRadius(0);
		light.setPosition(0, -3, 0);
	}

	ModelNode getShip()
	{	return ship;
	}

	Node getCameraSpot()
	{	return spring.getTail();
	}

	void setPosition(Vec3f pos)
	{	flyer.getBase.setPosition(pos);
	}

	void update(float delta)
	{
		if (spring.getStiffness()<24)
			spring.setStiffness(spring.getStiffness*(delta+1));

		flyer.update(delta);
		spring.update(delta);

		// Move the flyer
		float speed = 100*delta;
		if (Input.keydown[SDLK_UP] || Input.keydown[SDLK_w])
		{	// Engine smoke
			flyer.accelerate(0, 0, -speed);
			SpriteNode puff = new SpriteNode(ship.getScene());
			puff.setMaterial(Resource.material("fx/smoke.xml"));
			puff.setLifetime(.5);
			puff.setScale(.4);
			puff.setVelocity(flyer.getBase().getVelocity()*.9);
			puff.setPosition(ship.getAbsolutePosition()+Vec3f(.8, 0, 2.5).rotate(ship.getAbsoluteTransform()));

			puff = new SpriteNode(ship.getScene());
			puff.setMaterial("fx/smoke.xml");
			puff.setLifetime(.5);
			puff.setScale(.4);
			puff.setVelocity(flyer.getBase().getVelocity()*.9);
			puff.setPosition(ship.getAbsolutePosition()+Vec3f(-.8, 0, 2.5).rotate(ship.getAbsoluteTransform()));

			sound.play();
		}
		else
			sound.stop();


		if (Input.keydown[SDLK_DOWN] || Input.keydown[SDLK_s])
			flyer.accelerate(0, 0, speed/3);
		if (Input.keydown[SDLK_LEFT] || Input.keydown[SDLK_a])
			flyer.accelerate(-speed/6, 0, 0);
		if (Input.keydown[SDLK_RIGHT] || Input.keydown[SDLK_d])
			flyer.accelerate(speed/6, 0, 0);

		// Get mouse movement input to rotate camera
		if (Input.getGrabMouse())
			flyer.angularAccelerate(-Input.mousedx/16.0, Input.mousedy/24.0);

		// Maximum turning speed
		flyer.getBase().setAngularVelocity(flyer.getBase().getAngularVelocity().clamp(-3, 3));
		flyer.getPivot().setAngularVelocity(flyer.getPivot().getAngularVelocity().clamp(-3, 3));


		// Bank on turn
		float turn = flyer.getBase().getAngularVelocity().y;
		float cur = attach.getRotation().z;
		if (cur > 1 || cur < -1)	// Prevent banking too far
			attach.setAngularVelocity(0, 0, -cur/16);
		else
			attach.setAngularVelocity(0, 0, (turn-cur));

		// Fire a flare
		if (Input.keydown[SDLK_SPACE])
		{	light.setLightRadius(100);
			SpriteNode flare = new SpriteNode(ship.getScene());
			flare.setMaterial("fx/flare1.xml");

			flare.setPosition(ship.getAbsolutePosition());
			flare.setVelocity(Vec3f(0, 0, -100).rotate(ship.getAbsoluteTransform())+flyer.getBase().getVelocity());
			flare.setLifetime(5);

			SoundNode zap = new SoundNode(ship);
			zap.setSound("sound/laser.wav");
			zap.setLifetime(2);
			zap.play();

			LightNode light = new LightNode(flare);
			light.setDiffuse(1, .5, 0);
			light.setLightRadius(256);
		}
		else
			light.setLightRadius(0);
	}
}
