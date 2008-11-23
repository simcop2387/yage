/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.scene;

import derelict.opengl.gl;
import derelict.openal.al;
import yage.core.all;
import yage.system.device;
import yage.scene.visible;
import yage.scene.light;
import yage.scene.node;


/**
 * A Scene is the root of a tree of Nodes, and obviously, a Scene never has a parent.
 * Certain "global" variables are stored per Scene and affect all Nodes in that Scene. 
 * Examples include global ambient lighting and the speed of sound.
 * Scenes also maintain an array of all LightNodes in them.
 *
 * Each Scene updates its nodes in its own thread.  play() and pause()
 * control the updating of all child nodes at a fixed frequency.
 *
 * Example:
 * --------------------------------
 * Scene scene = new Scene();
 * scene.play();                          // Start the scene updater at 60 times per second.
 * scope(exit)scene.pause();              // Ensure it stops later.
 *
 * Scene skybox = new Scene();            // Create a skybox for the scene.
 * ModelNode sky = skybox.addChild(new ModelNode()); // A model with all faces pointing inward.
 * sky.setModel("sky/sanctuary.ms3d");    // Use this 3D model as geometry for the skybox.
 * scene.setSkybox(skybox);
 * --------------------------------
 */
class Scene : Node//, ITemporal
{
	protected static Scene[Scene] all_scenes;
	
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
	{	super();
		delta	= new Timer();
		scene	= this;
		ambient	= Color("333333"); // OpenGL default global ambient light.
		background = Color("black");	// OpenGL default clear color
		fog_color = Color("gray");
		repeater = new Repeater();
		repeater.setFunction(&update);
		
		transform_mutex = new Object();
		lights_mutex = new Object();
		
		all_scenes[this] = this;
	}
	
	/**
	 * Overridden to pause scene updates and to remove this instance from the array of all scenes. */
	override void finalize()
	{	pause();
		all_scenes.remove(this);
		super.finalize();
	}
	
	/**
	 * Make a duplicate of this scene.
	 * The duplicate will always start with its update thread paused.
	 * Params:
	 *     children = recursively clone children (and descendants) and add them as children to the new Node.
	 * Returns: The cloned Node. */
	override Scene clone(bool children=false)
	{	auto result = cast(Scene)super.clone(children);
				
		result.ambient = ambient;
		result.speed_of_sound = speed_of_sound;
		result.background = background;
		result.fog_color = fog_color;
		result.fog_density = fog_density;
		result.fog_enabled = fog_enabled;
		
		// non-atomic operations
		synchronized (this)
		{	result.delta.set(delta.tell());
			result.delta.pause();
			result.setSkybox(skybox);
		}
		
		return result;
	}
	unittest
	{	// Test duplication of a running scene.
		// Causes an access violation on exit.
		Scene a = new Scene();
		a.play();
		a.addChild(new VisibleNode());
		Scene b = a.clone(true);
		a.pause();
	}


	/// Get an array that contains all LightNodes that are contained within this Scene.
	LightNode[LightNode] getLights()
	{	return lights;
	}

	/// Get / set the background color rendered for this Scene when no skybox is specified.  TODO: allow transparency.
	Color getClearColor()
	{	return background;
	}	
	void setClearColor(Color color) /// ditto
	{	this.background = color;
	}

	/// Return the amount of time since the last time update() was called for this Scene.
	float getDeltaTime()
	{	return delta_time;
	}

	/// Get / set the color of global scene fog, when fog is enabled.
	Color getFogColor()
	{	return fog_color;
	}	
	void setFogColor(Color fog_color) /// ditto
	{	this.fog_color = fog_color;
	}
	
	/**
	 * Get / set the thickness (density) of the Scene's global fog, when fog is enabled.
	 * Depending on the scale of your scene, decent values range between .001 and .1.*/
	float getFogDensity()
	{	return fog_density;
	}
	void setFogDensity(float density) /// ditto
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
	void setFogEnabled(bool enabled) /// ditto
	{	fog_enabled = enabled;
	}
	
	/// Get / set the color of the scene's global ambient light.
	Color getGlobalAmbient()
	{	return ambient;
	}	
	void setGlobalAmbient(Color ambient) /// ditto
	{	this.ambient = ambient;
	}

	/**
	 * Get / set skybox.
	 * A Scene can have another heirarchy of nodes that will be
	 * rendered as a skybox by any camera. */
	Scene getSkybox()
	{	return skybox;
	}	
	void setSkybox(Scene _skybox) /// ditto
	{	skybox = _skybox;
	}
	
	/// Get / set the speed of sound (in game units) variable that will be passed to OpenAL.
	float getSpeedOfSound()
	{	return speed_of_sound;
	}	
	void setSpeedOfSound(float speed) /// ditto
	{	speed_of_sound = speed;
		alDopplerVelocity(speed/343.3);
	}
	/**
	 * Implement the time control functions of ITemporal.
	 * 
	 * When the scene's timer (implementd as a Repeater) runs, it updates
	 * the positions and rotations of all Nodes in this Scene.
	 * Each Scene is updated in its own thread.  If the updating thread
	 * gets behind, it will always attempt to catch up by updating more frequently.*/
	void play()
	{	repeater.play();
	}
	void pause() /// ditto
	{	repeater.pause();		
	}	
	bool paused() /// ditto
	{	return repeater.paused();
	}	
	
	void seek(double seconds) /// ditto
	{	repeater.seek(seconds);		
	}
	double tell() /// ditto
	{	return repeater.tell();		
	}
	
	override void remove()
	{	repeater.remove(); // ensures repeater's thread terminates.
		super.remove();
	}

	/**
	 * Get the Repeater that calls update() in its own thread.
	 * This allows more advanced interaction than the shorthand functions implemented above.
	 * See:  yage.core.repeater  */
	Repeater getRepeater()
	{	return repeater;		
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

	/**
	 * Update all Nodes in the scene by delta seconds.
	 * This function is typically called automatically at a set interval once scene.play() is called.
	 * Params:
	 *     delta = time in seconds.  If not set, defaults to the amount of time since the last time update() was called. */
	void update(double delta = delta.tell())
	{	super.update(delta);
		delta_time = delta;
		this.delta.reset();
		scene.swapTransformWrite();
	}
	

	/*
	 * Apply OpenGL options specific to this Scene.  This function is used internally by
	 * the engine and doesn't normally need to be called.
	 * TODO: Rename to bind? */
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
	void removeLight(LightNode light)
	{	synchronized (lights_mutex) lights.remove(light);
	}

	/**
	 * Get a self-indexed array of all senes that have been constructed but not finalized. */
	static Scene[Scene] getAllScenes()
	{	return all_scenes;		
	}
}
