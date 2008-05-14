/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module demo2.gameobj;

import std.math;
import std.stdio;
import yage.core.timer;
import yage.core.types;
import yage.core.vector;
import yage.resource.resource;
import yage.resource.model;
import yage.node.all;


abstract class GameObject : Node
{
	float mass=0;

	this (BaseNode parent)
	{	super(parent);
	}
}


class Asteroid : GameObject
{
	float radius; // cached

	this (BaseNode parent)
	{	super(parent);
		ModelNode rock = new ModelNode(this);
		rock.setModel(Resource.model("space/asteroid1.ms3d"));
	}

	float getRadius()
	{	return radius;
	}

	void setMass(float mass)
	{	this.mass = mass;
		children[0].scale = Vec3f(pow(mass, .33333)/2);
		radius = pow(mass, .3333)*.75*4;
	}
}

class Flare : GameObject
{
	static Timer timer;


	this (BaseNode parent)
	{	super(parent);
		this.setLifetime(4);

		SpriteNode flare = new SpriteNode(this);
		flare.setMaterial("fx/flare1.xml");
		flare.scale = Vec3f(2);

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
