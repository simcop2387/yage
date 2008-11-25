/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty: none
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module demo1.gameobj;

import std.math;
import std.stdio;
import yage.core.timer;
import yage.core.color;
import yage.core.vector;
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
		rock.setModel(ResourceManager.model("space/asteroid1.ms3d"));
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

	this ()
	{	super();
		this.setLifetime(4);

		auto flare = addChild(new SpriteNode());
		flare.setMaterial("fx/flare1.xml");
		flare.setSize(Vec3f(2));

		if (timer is null)
		{	timer = new Timer();
			timer.set(1);			
		}

		// don't create a new light more than 5 times per second
		if (timer.get() > .2)
		{	timer.reset();
			LightNode light = addChild(new LightNode());
			light.setDiffuse(Color("orange"));
			light.setLightRadius(96);
		}
	}
}
