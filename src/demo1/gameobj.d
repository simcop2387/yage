/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty:   none
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module demo1.gameobj;

import tango.math.Math;

import yage.core.all;
import yage.resource.manager;
import yage.resource.model;
import yage.scene.all;


abstract class GameObject : VisibleNode
{
	float mass=0;

	this()
	{	super();		
	}
}


class Asteroid : GameObject
{
	ModelNode rock;
	
	float radius; // cached
	
	this()
	{	super();
		rock = addChild(new ModelNode());
		rock.setModel(ResourceManager.model("space/asteroid1.dae"));
	}

	float getRadius()
	{	return radius;
	}

	void setMass(float mass)
	{	this.mass = mass;
		rock.setSize(Vec3f(pow(mass, .33333)/2));
		radius = pow(mass, .3333)*.75*4;
	}
}

class Flare : GameObject
{
	static Timer timer;
	static Timer timer2;

	this ()
	{	super();
		this.setLifetime(5);

		auto flare = addChild(new SpriteNode());
		flare.setMaterial("fx/flare1.dae", "flare-material");
		flare.setSize(Vec3f(2));

		if (timer is null)
		{	timer = new Timer(true);
			timer.seek(1);
			timer2 = new Timer(true);
			timer2.seek(1);
		}

		// don't create a new light more than 5 times per second
		if (timer.tell() > .2)
		{	timer.seek(0);
			LightNode light = addChild(new LightNode());
			light.diffuse = light.specular = Color.ORANGE;
			light.setLightRadius(96);
		}
		
		if (timer2.tell() > 1/20.0f)
		{	timer2.seek(0);			
			SoundNode zap = addChild(new SoundNode());
			zap.setSound("sound/laser3.ogg");
			zap.setVolume(.2);
			zap.play();
		}
			
	}
}



void asteroidBelt(int number, float radius, Node scene)
{
	for (int i=0; i<number; i++)
	{	float value = random(0,1);
		float value2 = random(0,1);
		float value3 = random(0,1);
		float value4 = random(0,1);
		float value5 = random(0,1);

		ModelNode a = scene.addChild(new ModelNode());
		a.setPosition(Vec3f(
						sin(value*6.282)*radius + pow(value2*2-1, 3.0)*radius/4,
						pow(value3*2-1, 3.0)*radius/16,
						cos(value*6.282)*radius + pow(value4*2-1, 3.0)*radius/4));
		
		a.setModel(ResourceManager.model("space/asteroid1.dae"));
		a.setSize(Vec3f(value5*value5*value5*value5*value5*value5*value5 + .2));
		a.rotate(Vec3f(value4*12, value2*12, value3*12));
	//	a.setAngularVelocity(Vec3f(random(-.2, .2), random(-.2, .2), random(-.2, .2)));
	}
}

void asteroidField(int number, float radius, VisibleNode scene)
{
	for (int i=0; i<number; i++)
	{	float value = random(0,1);
		float value2 = random(0,1);
		float value3 = random(0,1);
		float value4 = random(0,1);
		float value5 = random(0,1);

		ModelNode a = scene.addChild(new ModelNode());
		a.setPosition(Vec3f((value-.5)*radius, (value2-.5)*radius, (value3-.5)*radius));

		a.setModel(ResourceManager.model("space/asteroid1.dae"));
		a.setSize(Vec3f(value5*value5*.4 + .2));
		a.rotate(Vec3f(value4*12, value2*7, value3*11));
	}
}

void asteroidPlane(int number, float radius, VisibleNode scene)
{
	for (int i=0; i<number; i++)
	{	float value = random(0,1);
		float value2 = random(0,1);
		float value4 = random(0,1);
		float value5 = random(0,1);

		ModelNode a = scene.addChild(new ModelNode());
		a.setPosition(Vec3f((value-.5)*radius, 0, (value2-.5)*radius));

		a.setModel(ResourceManager.model("../media/planet/phobos.ms3d"));
		a.setSize(Vec3f(value5*value5*.4 + .2));
		a.rotate(Vec3f(value4*12, value2*7, value*11));
	}

}

