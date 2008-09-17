/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module demo2.gameobj;

import std.math;
import std.stdio;
import yage.core.timer;
import yage.core.color;
import yage.core.vector;
import yage.resource.resource;
import yage.resource.model;
import yage.scene.all;


abstract class GameObject : VisibleNode
{
	float mass=0;

	this (Node parent)
	{	super(parent);
	}
}


class Asteroid : GameObject
{
	ModelNode rock;
	
	float radius; // cached

	this (Node parent)
	{	super(parent);
		rock = new ModelNode(this);
		rock.setModel(Resource.model("space/asteroid1.ms3d"));
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


	this (Node parent)
	{	super(parent);
		this.setLifetime(4);

		SpriteNode flare = new SpriteNode(this);
		flare.setMaterial("fx/flare1.xml");
		flare.setSize(Vec3f(2));

		if (timer is null)
		{	timer = new Timer();
			timer.set(1);
		}

		// don't create a new light more than 5 times per second
		if (timer.get() > .2)
		{	timer.reset();
			LightNode light = new LightNode(this);
			light.setDiffuse(Color("orange"));
			light.setLightRadius(96);
		}
	}
}
