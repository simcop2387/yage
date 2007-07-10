/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module demo1.gameobj;

import std.math;
import std.stdio;
import yage.core.timer;
import yage.node.base;
import yage.node.node;
import yage.resource.resource;
import yage.resource.model;
import yage.node.scene;
import yage.node.sprite;
import yage.node.model;
import yage.node.light;


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
		children[0].setScale(pow(mass, .33333)/2);
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
		flare.setScale(2);

		if (timer is null)
		{	timer = new Timer();
			timer.set(1);
		}

		// don't create a new light more than 5 times per second
		if (timer.get() > .2)
		{	timer.reset();
			LightNode light = new LightNode(this);
			light.setDiffuse(1, .5, 0);
			light.setLightRadius(96);
		}
	}
}