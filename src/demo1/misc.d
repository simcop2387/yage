/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty:   none
 * 
 * This module is not part of the engine, but merely uses it.
 */

module demo1.misc;

// Utility functions to generate fun things.

import tango.math.Math;
import yage.resource.manager;
import yage.system.input;
import yage.scene.all;
import yage.core.all;


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
		
		a.setModel(ResourceManager.model("space/asteroid1.ms3d"));
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

		a.setModel(ResourceManager.model("../media/planet/phobos.ms3d"));
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

