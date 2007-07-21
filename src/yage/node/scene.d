/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.scene;

import derelict.opengl.gl;
import derelict.openal.al;
import yage.core.all;
import yage.node.node;
import yage.node.light;
import yage.node.base;


/**
 * A Scene is the root of a tree of Nodes, and obviously, a Scene never has a parent.
 * Certain "global" variables are stored per Scene and affect all Nodes in that
 * Scene.  Examples include global ambient lighting and the speed of sound.
 * Scenes also maintain an array of all lights in them.
 *
 * Each Scene can also be thought to exist in its own thread.  start() and stop()
 * control the updating of all child nodes at a fixed frequency.
 *
 * Example:
 * --------------------------------
 * Scene scene = new Scene();
 * scene.start(90);                       // Start the scene updater at 90 times per second.
 * scope(exit)scene.stop();               // Ensure it stops later.
 *
 * Scene skybox = new Scene();            // Create a skybox for the scene.
 * ModelNode sky = new ModelNode(skybox); // A model with all faces pointing inward.
 * sky.setModel("sky/sanctuary.ms3d");    // Use this 3D model as geometry for the skybox.
 * scene.setSkybox(skybox);
 * --------------------------------
 */
class Scene : BaseNode
{
	protected Scene skybox;
	protected LightNode[] lights;

	protected Timer delta; 					// time since the last time this Scene was updated.
	protected float delta_time;
	protected Color ambient;				// scene ambient light color.
	protected Color background;				// scene background color.
	protected Color fog_color;
	protected float fog_density = 0.1;
	protected bool  fog_enabled = false;
	protected float speed_of_sound = 343;	// 343m/s is the speed of sound in air at sea level.

	protected long timestamp[3];
	package int transform_read=0, transform_write=1;

	protected Repeater repeater;

	/// Construct an empty Scene.
	this()
	{	delta	= new Timer();
		scene	= this;
		ambient	= Color("333333"); // OpenGL default global ambient light.
		background = Color("black");	// OpenGL default clear color
		fog_color = Color("gray");
		repeater = new Repeater(&update);
	}

	~this()
	{	try { // since order of destruction is unpredictable.
			repeater.stop();
		} catch {}
	}

	/*
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
	{	return lights;
	}

	///
	Color getClearColor()
	{	return background;
	}

	/// Return the amount of time since the last time update() was called for this Scene.
	float getDeltaTime()
	{	return delta_time;
	}

	///
	Color getFogColor()
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
	Color getGlobalAmbient()
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

	/// Get the the number of seconds since the last time start() was called.
	real getStartTime()
	{	return repeater.getStartTime();
	}

	/// Get the number of times the Scene has been updated since start() was called.
	int getUpdateCount()
	{	return repeater.getCallCount();
	}


	/// Set the background color when no skybox is specified.
	void setClearColor(Color color)
	{	this.background = background;
	}

	/// Set the color of fog, when fog is enabled.
	void setFogColor(Color fog_color)
	{	this.fog_color = fog_color;
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
	void setGlobalAmbient(Color ambient)
	{	this.ambient = ambient;
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

	/**
	 * Set the target for update the number of updates.
	 * A number higher than the current count will cause the Updater to pause until
	 * enough time has passed that the update counter should be at that count.
	 * A number smaller than the current count will cause the updater to repeatedly
	 * update until the count is back to what it should be. */
	void setUpdateCount(int count)
	{	repeater.setCallCount(count);
	}

	/**
	 * Start updating the positions and rotations of all Nodes in this Scene.
	 * Each Scene is updated in its own thread.  If the updating thread
	 * gets behind, it will always attempt to catch up.
	 * Params:
	 * frequency = The scene will be updated this many times per second.*/
	synchronized void start(float frequency=90)
	{	repeater.start(frequency);
	}

	/// Stop updating the Scene.
	synchronized void stop()
	{	repeater.stop();
	}

	/**
	 * Swap the transform buffer cache for each Node to the latest that's not currently
	 * being written to.*/
	synchronized void swapTransformRead()
	out
	{	assert(transform_read < 3);
		assert(transform_read != transform_write);
	}body
	{	int next = 3-(transform_read+transform_write);
		if (timestamp[next] > timestamp[transform_read])
			transform_read = 3 - (transform_read+transform_write);
	}

	/// Start writing to the transform buffer cache that's not currently being read.
	synchronized void swapTransformWrite()
	out
	{	assert(transform_read < 3);
		assert(transform_read != transform_write);
	}body
	{	timestamp[transform_write] = getCPUCount();
		transform_write = 3 - (transform_read+transform_write);
	}

	/// Update all Nodes by the time that has passed since update() was last called.
	void update()
	{	update(delta.get());
	}

	/// Update all Nodes in the scene by delta seconds.
	void update(float delta)
	{	super.update(delta);
		delta_time = delta;
		this.delta.reset();
		scene.swapTransformWrite();
	}
	

	/*
	 * Apply OpenGL options specific to this Scene.  This function is used internally by
	 * the engine and doesn't normally need to be called.*/
	void apply()
	{	glLightModelfv(GL_LIGHT_MODEL_AMBIENT, ambient.vec4f.ptr);
		glClearColor(background.r, background.g, background.b, background.a);

		if (fog_enabled)
		{	glFogfv(GL_FOG_COLOR, fog_color.vec4f.ptr);
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
	{	lights ~= light;
		light.setLightIndex(lights.length-1);
	}

	/*
	 * Remove the light with the given light index.
	 * This function is used internally by the engine and doesn't normally need to be called.*/
	synchronized void removeLight(int light_index)
	{	if (light_index != -1)
		{	LightNode goodbye = lights[light_index];
			lights.remove(light_index, false);
			if (light_index < lights.length) // set the index of the light that was moved over the one just deleted.
				lights[light_index].setLightIndex(light_index);
			goodbye.setLightIndex(-1); // prevent multiple removals.
		}
	}

}
