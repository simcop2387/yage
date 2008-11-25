/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 * 
 * This probably doesn't need to be a part of yage itself.
 */

module demo1.misc;

// Utility functions to generate fun things.

import std.math;
import std.random;
import yage.resource.manager;
import yage.system.input;
import yage.scene.all;
import yage.core.all;


void asteroidBelt(int number, float radius, Node scene)
{
	for (int i=0; i<number; i++)
	{	float value = rand()/4294967296.0f;
		float value2 = rand()/4294967296.0f;
		float value3 = rand()/4294967296.0f;
		float value4 = rand()/4294967296.0f;
		float value5 = rand()/4294967296.0f;

		ModelNode a = scene.addChild(new ModelNode());
		a.setPosition(Vec3f(
						sin(value*6.282)*radius + pow(value2*2-1, 3.0)*radius/4,
						pow(value3*2-1, 3.0)*radius/16,
						cos(value*6.282)*radius + pow(value4*2-1, 3.0)*radius/4));
		
		a.setModel(ResourceManager.model("space/asteroid1.ms3d"));
		a.setSize(Vec3f(value5*value5*value5*value5*value5*value5*value5*1.1 + .2));
		a.rotate(Vec3f(value4*12, value2*12, value3*12));
	//	a.setAngularVelocity(Vec3f(random(-.2, .2), random(-.2, .2), random(-.2, .2)));
	}
}

void asteroidField(int number, float radius, VisibleNode scene)
{
	for (int i=0; i<number; i++)
	{	float value = rand()/4294967296.0f;
		float value2 = rand()/4294967296.0f;
		float value3 = rand()/4294967296.0f;
		float value4 = rand()/4294967296.0f;
		float value5 = rand()/4294967296.0f;

		ModelNode a = scene.addChild(new ModelNode());
		a.setPosition(Vec3f((value-.5)*radius, (value2-.5)*radius, (value3-.5)*radius));

		a.setModel(ResourceManager.model("../media/planet/phobos.ms3d"));
		a.setSize(Vec3f(value5*value5*.4 + .2));
		a.rotate(Vec3f(value4*12, value2*7, value3*11));
	}
}

void asteroidPlane(int number, float radius, VisibleNode scene)
{
	for (int i=0; i<number; i++)
	{	float value = rand()/4294967296.0f;
		float value2 = rand()/4294967296.0f;
		float value4 = rand()/4294967296.0f;
		float value5 = rand()/4294967296.0f;

		ModelNode a = scene.addChild(new ModelNode());
		a.setPosition(Vec3f((value-.5)*radius, 0, (value2-.5)*radius));

		a.setModel(ResourceManager.model("../media/planet/phobos.ms3d"));
		a.setSize(Vec3f(value5*value5*.4 + .2));
		a.rotate(Vec3f(value4*12, value2*7, value*11));
	}

}

