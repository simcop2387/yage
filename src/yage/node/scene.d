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
	protected LightNode[LightNode] lights;

	protected Timer delta; 					// time since the last time this Scene was updated.
	protected float delta_time;
	protected Color ambient;				// scene ambient light color.
	protected Color background;				// scene background color.
	protected Color fog_color;
	protected float fog_density = 0.1;
	protected bool  fog_enabled = false;
	protected float speed_of_sound = 343;	// 343m/s is the speed of sound in air at sea level.
	
	package Object transform_mutex;		// Ensure that swapTransformRead and swapTransformWrite don't occur at the same time.
	package Object lights_mutex;

	protected long timestamp[3];
	package int transform_read=0, transform_write=1;

	Repeater repeater;

	/// Construct an empty Scene.
	this()
	{	delta	= new Timer();
		scene	= this;
		ambient	= Color("333333"); // OpenGL default global ambient light.
		background = Color("black");	// OpenGL default clear color
		fog_color = Color("gray");
		repeater = new Repeater(&update);
		
		transform_mutex = new Object;
		lights_mutex = new Object;
	}

	/// Destroctor, stops the Scene's thread.
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
	LightNode[LightNode] getLights()
	{	return lights;
	}

	/// Get / set the background color when no skybox is specified.
	Color getClearColor()
	{	return background;
	}	
	void setClearColor(Color color) /// Ditto
	{	this.background = background;
	}

	/// Return the amount of time since the last time update() was called for this Scene.
	float getDeltaTime()
	{	return delta_time;
	}

	/// Get / set the color of global scene fog, when fog is enabled.
	Color getFogColor()
	{	return fog_color;
	}	
	void setFogColor(Color fog_color) /// Ditto
	{	this.fog_color = fog_color;
	}
	
	/**
	 * Get / set the thickness (density) of the Scene's global fog, when fog is enabled.
	 * Depending on the scale of your scene, decent values range between .001 and .1.*/
	float getFogDensity()
	{	return fog_density;
	}
	void setFogDensity(float density) /// Ditto
	{	fog_density = density;
	}

	/**
	 * Get / set whether global distance fog is enabled for this scene.
	 * For best results, use no skybox and set the clear color the same as the fog color.
	 * For improved performance, set the cameras' max view distance to just beyond
	 * where objects become completely obscured by the fog. */
	bool getFogEnabled()
	{	return fog_enabled;
	}
	void setFogEnabled(bool enabled) /// Ditto
	{	fog_enabled = enabled;
	}
	
	/// Get / set the color of the scene's global ambient light.
	Color getGlobalAmbient()
	{	return ambient;
	}	
	void setGlobalAmbient(Color ambient) /// Ditto
	{	this.ambient = ambient;
	}

	/**
	 * Get / set skybox.
	 * A Scene can have another heirarchy of nodes that will be
	 * rendered as a skybox by any camera. */
	Scene getSkybox()
	{	return skybox;
	}	
	void setSkybox(Scene _skybox) /// Ditto
	{	skybox = _skybox;
	}
	
	/// Get / set the speed of sound (in game units) variable that will be passed to OpenAL.
	float getSpeedOfSound()
	{	return speed_of_sound;
	}	
	void setSpeedOfSound(float speed) /// Ditto
	{	speed_of_sound = speed;
		alDopplerVelocity(speed/343.3);
	}

	/// Get the the number of seconds since the last time start() was called.
	real getStartTime()
	{	return repeater.getStartTime();
	}

	/**
	 * Get / set the target for update the number of updates.
	 * A number higher than the current count will cause the Updater to pause until
	 * enough time has passed that the update counter should be at that count.
	 * A number smaller than the current count will cause the updater to repeatedly
	 * update until the count is back to what it should be. */
	int getUpdateCount()
	{	return repeater.getCallCount();
	}
	void setUpdateCount(int count) /// Ditto
	{	repeater.setCallCount(count);
	}

	/**
	 * Start updating the positions and rotations of all Nodes in this Scene.
	 * Each Scene is updated in its own thread.  If the updating thread
	 * gets behind, it will always attempt to catch up.
	 * Params:
	 * frequency = The scene will be updated this many times per second.*/
	void start(float frequency=90)
	{	repeater.start(frequency);
	}

	/// Stop updating the Scene.
	void stop(){
		repeater.stop();
	}

	/**
	 * Swap the transform buffer cache for each Node to the latest that's not currently
	 * being written to.*/
	void swapTransformRead()
	out
	{	assert(transform_read < 3);
		assert(transform_read != transform_write);
	}body
	{	synchronized (transform_mutex)
		{	int next = 3-(transform_read+transform_write);
			if (timestamp[next] > timestamp[transform_read])
				transform_read = 3 - (transform_read+transform_write);
		}
	}

	/// Start writing to the transform buffer cache that's not currently being read.
	void swapTransformWrite()
	out
	{	assert(transform_read < 3);
		assert(transform_read != transform_write);
	}body
	{	synchronized (transform_mutex)
		{	timestamp[transform_write] = getCPUCount();
			transform_write = 3 - (transform_read+transform_write);
		}
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
	{	synchronized (lights_mutex) lights[light] = light;	
	}

	/*
	 * Remove the light with the given light index.
	 * This function is used internally by the engine and doesn't normally need to be called.*/
	synchronized void removeLight(LightNode light)
	{	synchronized (lights_mutex) lights.remove(light);
	}

}
