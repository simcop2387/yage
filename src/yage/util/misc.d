/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.util.misc;

// Utility functions to generate fun things.

import std.math;
import std.random;
import yage.resource.resource;
import yage.system.input;
import yage.node.all;
import yage.core.all;


void createArray(Node instance, float spacing, float x, float y=1, float z=1)
{
	Vec3f position = instance.getPosition();
	for(int i=0; i<x; i++)
		for(int j=0; j<y; j++)
			for(int k=0; k<z; k++)
			{	Node a;

				if (instance.getType() == "SoundNode")
					a = new SoundNode(instance.getParent(), cast(SoundNode)instance);
				if (instance.getType() == "yage.node.model.ModelNode")
					a = new ModelNode(instance.getParent(), cast(ModelNode)instance);
				if (instance.getType() == "LightNode")
					a = new LightNode(instance.getParent(), cast(LightNode)instance);
				if (instance.getType() == "SpriteNode")
					a = new SpriteNode(instance.getParent(), cast(SpriteNode)instance);
				a.setPosition(Vec3f(i*spacing+position[0], j*spacing+position[1], k*spacing+position[2]));

			}
}


void asteroidBelt(int number, float radius, BaseNode scene)
{
	for (int i=0; i<number; i++)
	{	float value = rand()/4294967296.0f;
		float value2 = rand()/4294967296.0f;
		float value3 = rand()/4294967296.0f;
		float value4 = rand()/4294967296.0f;
		float value5 = rand()/4294967296.0f;

		ModelNode a = new ModelNode(scene);
		a.setPosition(Vec3f(
						sin(value*6.282)*radius + pow(value2*2-1, 3.0)*radius/4,
						pow(value3*2-1, 3.0)*radius/16,
						cos(value*6.282)*radius + pow(value4*2-1, 3.0)*radius/4));
		
		a.setModel(Resource.model("space/asteroid1.ms3d"));
		a.scale = Vec3f(value5*value5*value5*value5*value5*value5*value5*1.1 + .2);
		a.rotate(Vec3f(value4*12, value2*12, value3*12));
		a.setAngularVelocity(Vec3f(random(-.2, .2), random(-.2, .2), random(-.2, .2)));
	}
}

void asteroidField(int number, float radius, Node scene)
{
	for (int i=0; i<number; i++)
	{	float value = rand()/4294967296.0f;
		float value2 = rand()/4294967296.0f;
		float value3 = rand()/4294967296.0f;
		float value4 = rand()/4294967296.0f;
		float value5 = rand()/4294967296.0f;

		ModelNode a = new ModelNode(scene);
		a.setPosition(Vec3f((value-.5)*radius, (value2-.5)*radius, (value3-.5)*radius));

		a.setModel(Resource.model("../media/planet/phobos.ms3d"));
		a.scale = Vec3f(value5*value5*.4 + .2);
		a.rotate(Vec3f(value4*12, value2*7, value3*11));
	}
}

void asteroidPlane(int number, float radius, Node scene)
{
	for (int i=0; i<number; i++)
	{	float value = rand()/4294967296.0f;
		float value2 = rand()/4294967296.0f;
		float value4 = rand()/4294967296.0f;
		float value5 = rand()/4294967296.0f;

		ModelNode a = new ModelNode(scene);
		a.setPosition(Vec3f((value-.5)*radius, 0, (value2-.5)*radius));

		a.setModel(Resource.model("../media/planet/phobos.ms3d"));
		a.scale = Vec3f(value5*value5*.4 + .2);
		a.rotate(Vec3f(value4*12, value2*7, value*11));
	}

}

