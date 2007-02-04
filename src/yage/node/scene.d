/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.scene;

import derelict.opengl.gl;
import derelict.openal.al;
import yage.core.all;
import yage.node.node;
import yage.node.light;
import yage.node.basenode;


/**
 * A Scene is the root of a tree of Nodes, and obviously, a Scene never has a parent.
 * Certain "global" variables are stored per Scene and affect all Nodes in that
 * Scene.  Examples include global ambient lighting and the speed of sound.
 * Scenes also maintain a Horde (array) of all lights in them. */
class Scene : BaseNode
{
	protected Scene skybox;
	protected Horde!(LightNode) lights;

	protected Timer delta; 					// time since the last time this Scene was updated.
	protected Vec4f ambient;				// scene ambient light color.
	protected Vec4f color;					// scene background color.
	protected Vec4f fog_color;
	protected float fog_density = 0.1;
	protected bool  fog_enabled = false;
	protected float speed_of_sound = 343;	// 343m/s is the speed of sound in air at sea level.

	/// Constructor.
	this()
	{	delta	= new Timer();
		lights 	= new Horde!(LightNode);
		scene	= this;
		ambient	= Vec4f(.2, .2, .2, 1); // OpenGL default global ambient light.
		color   = Vec4f(0, 0, 0, 1);	// OpenGL default clear color
		fog_color = Vec4f(.5, .5, .5, 1);
	}

	/**
	 * Construct this Scene as an exact copy original and make copies of all
	 * children.*/
	this (Scene original)
	{	this();
		setSkybox(original.skybox);
		delta.set(original.delta.get());
		//delta.setPaused(original.delta.getPaused());
		ambient = original.ambient;
		speed_of_sound = original.speed_of_sound;

		// Copy children, unfinished!
		//foreach (Node c; children.array())
	}



	/// Get an array that contains all lights that are children of this Scene.
	LightNode[] getLights()
	{	return cast(LightNode[])lights.array();
	}

	///
	Vec4f getClearColor()
	{	return color;
	}

	/// Return the amount of time since the last time update() was called for this Scene.
	float getDeltaTime()
	{	return delta.get();
	}

	///
	Vec4f getFogColor()
	{	return fog_color;
	}

	///
	float getFogDensity()
	{	return fog_density;
	}

	///
	bool getFogEnabled()
	{	return fog_enabled;
	}

	///
	Vec4f getGlobalAmbient()
	{	return ambient;
	}

	/// Get the Scene that is used as the skybox.
	Scene getSkybox()
	{	return skybox;
	}

	///
	float getSpeedOfSound()
	{	return speed_of_sound;
	}


	/// Set the background color when no skybox is specified.
	void setClearColor(Vec4f color)
	{	this.color = color;
	}
	/// Ditto
	void setClearColor(float r, float g, float b)
	{	color = Vec4f(r, g, b, 1);
	}

	/// Set the color of fog, when fog is enabled.
	void setFogColor(Vec4f fog_color)
	{	this.fog_color = fog_color;
	}
	/// Ditto
	void setFogColor(float r, float g, float b)
	{	fog_color = Vec4f(r, g, b, 1);
	}

	/**
	 * Set the thickness (density) of the Scene's global fog, when fog is enabled.
	 * Depending on the scale of your scene, decent values range between .001 and .1.*/
	void setFogDensity(float density)
	{	fog_density = density;
	}

	/**
	 * Enable global distance fog for this scene.
	 * For best results, use no skybox and set the clear color the same as the fog color.
	 * For improved performance, set the cameras' max view distance to just beyond
	 * where objects become completely obscured by the fog. */
	void setFogEnabled(bool enabled)
	{	fog_enabled = enabled;
	}

	/// Set the color of the scene's global ambient light.
	void setGlobalAmbient(Vec4f ambient)
	{	this.ambient = ambient;
	}
	/// Ditto
	void setGlobalAmbient(float r, float g, float b)
	{	ambient = Vec4f(r, g, b, 1);
	}

	/**
	 * A Scene can have another heirarchy of nodes that will be
	 * rendered as a skybox by any camera. */
	void setSkybox(Scene _skybox)
	{	skybox = _skybox;
	}

	/// Set the speed of sound variable that will be passed to OpenAL.
	void setSpeedOfSound(float speed)
	{	speed_of_sound = speed;
		alDopplerVelocity(speed/343.3);
	}

	/// Update all Nodes by the time that has passed since update() was last called.
	void update()
	{	super.update(delta.get());
		delta.reset();
	}
	/// Update all Nodes in the scene by delta seconds.
	void update(float delta)
	{	super.update(delta);
	}

	/**
	 * Apply OpenGL options specific to this Scene.  This function is used internally by
	 * the engine and doesn't normally need to be called.*/
	void apply()
	{	glLightModelfv(GL_LIGHT_MODEL_AMBIENT, ambient.v.ptr);
		glClearColor(color.a, color.b, color.c, color.d);

		if (fog_enabled)
		{	glFogfv(GL_FOG_COLOR, fog_color.v.ptr);
			glFogf(GL_FOG_DENSITY, fog_density);
			glEnable(GL_FOG);
		} else
			glDisable(GL_FOG);
	}

	/*
	 * Add a light to this Scene's list of lights.
	 * Only add lights that already exist as one of this node's children.
	 * A list of lights in the scene are mainained here only for faster lookups.
	 * This function is used internally by the engine and doesn't normally need to be called.*/
	void addLight(LightNode light)
	{	light.setLightIndex(lights.add(light));
	}

	/*
	 * Remove the light with the given light index.
	 * This function is used internally by the engine and doesn't normally need to be called.*/
	synchronized void removeLight(int light_index)
	{
		lights.remove(light_index);
		if (light_index < lights.length) // set the index of the light that was moved over the one just deleted.
			lights[light_index].setLightIndex(light_index);
	}

}
