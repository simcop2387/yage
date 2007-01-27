/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module yage.gameobj;

import std.math;
import std.stdio;
import yage.node.basenode;
import yage.node.node;
import yage.resource.resource;
import yage.resource.model;
import yage.node.scene;
import yage.node.sprite;
import yage.node.model;
import yage.node.light;
import yage.universe;


abstract class GameObject : Node
{
	int universe_index;
	float mass=0;

	this (BaseNode parent)
	{	super(parent);
	}
}

abstract class GravityObject : GameObject
{
	Universe parent;

	this (BaseNode parent)
	{	super(parent);
	}
}

class Asteroid : GravityObject
{
	this (BaseNode parent)
	{	super(parent);
		ModelNode rock = new ModelNode(this);
		rock.setModel(Resource.model("space/asteroid1.ms3d"));
	}

	float getRadius()
	{	return pow(mass, .3333)*.75*4;
	}

	void setMass(float mass)
	{	this.mass = mass;
		children[0].setScale(pow(mass, .33333)/2);
	}
}

class Flare : GameObject
{
	this (BaseNode parent)
	{	super(parent);

		SpriteNode flare = new SpriteNode(this);
		flare.setMaterial("fx/flare1.xml");
		flare.setLifetime(5);
		flare.setScale(2);

		LightNode light = new LightNode(this);
		light.setDiffuse(1, .5, 0);
		light.setLightRadius(100);
	}
}
