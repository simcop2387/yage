/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty:   none
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module demo3.gameobj;

import tango.math.Math;

import yage.core.all;
import yage.resource.manager;
import yage.resource.model;
import yage.scene.all;

class GameObject : VisibleNode
{	float lifetime = float.infinity;
	float mass=0;

	this()
	{	super();		
	}
	
	override void update(float delta)
	{	super.update(delta);
		lifetime-= delta;
		if (lifetime <= 0)
		{	if (parent)
				parent.removeChild(this);
			lifetime = float.infinity;
		}
	}
	
	/**
	 * Make a duplicate of this node, unattached to any parent Node.
	 * Params:
	 *     children = recursively clone children (and descendants) and add them as children to the new Node.
	 * Returns: The cloned Node. */
	override Node clone(bool children=true, Node destination=null)
	{	assert (!destination || cast(GameObject)destination);
		auto result = cast(GameObject)super.clone(children, destination);
		result.lifetime = lifetime;
		//Log.write("sprite clone");
		return result;
	}

}

class Flare : GameObject
{
	static Timer timer;
	static Timer timer2;

	this ()
	{	super();
		lifetime = 5;

		auto flare = addChild(new SpriteNode("fx/flare1.dae", "flare-material"));
		flare.setScale(Vec3f(2));

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
			light.setLightRadius(200);
		}
		
		if (timer2.tell() > 1/20.0f)
		{	timer2.seek(0);			
			SoundNode zap = addChild(new SoundNode());
			zap.setSound("sound/laser3.ogg");
			zap.volume = .2;
			//zap.play();
		}
			
	}
}
