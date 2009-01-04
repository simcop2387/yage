/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.scene;

import std.date;
import std.stdio;
import derelict.opengl.gl;
import derelict.openal.al;
import yage.core.all;
import yage.system.alcontext;
import yage.system.device;
import yage.scene.light;
import yage.scene.node;
import yage.scene.sound;
import yage.scene.visible;

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
	protected SoundNode[SoundNode] sounds;

	protected Timer delta; 					// time since the last time this Scene was updated.
	protected float delta_time;
	protected Color ambient;				// scene ambient light color.
	protected Color background;				// scene background color.
	protected Color fog_color;
	protected float fog_density = 0.1;
	protected bool  fog_enabled = false;
	
	package Object transform_mutex;			// Ensure that swapTransformRead and swapTransformWrite don't occur at the same time.
	package Object lights_mutex;
	package Object sounds_mutex;

	protected long timestamp[3];			// Used for timestamps of newest transform_read/write
	package int transform_read=0, transform_write=1;

	Repeater update_thread;
	ALContext sound_thread;

	/// Construct an empty Scene.
	this()
	{	super();
		delta = new Timer();
		scene = this;
		ambient	= Color("333333"); // OpenGL default global ambient light.
		background = Color("black");	// OpenGL default clear color
		fog_color = Color("gray");
		
		update_thread = new Repeater();
		update_thread.setFunction(&update);		
		update_thread.setErrorFunction(&Device.abortException);
		
		sound_thread = new ALContext();
		sound_thread.setFunction(&updateSounds);
		sound_thread.setFrequency(30); // sound buffers are updated 30 times per second.
		sound_thread.setErrorFunction(&Device.abortException);
		
		transform_mutex = new Object();
		lights_mutex = new Object();
		sounds_mutex = new Object();
		
		all_scenes[this] = this;
	}
	
	/**
	 * Call finalize() on destruction. */
	~this()
	{	finalize();		
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
		result.setSpeedOfSound(getSpeedOfSound());
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
		// this no longer works since the scene constructor now requiores the openAl .dll/.so
		/*
		Scene a = new Scene();
		a.play();
		a.addChild(new VisibleNode());
		Scene b = a.clone(true);
		a.pause();
		*/
	}
	
	/**
	 * Overridden to pause the scene update and sound threads and to remove this instance from the array of all scenes. */
	override void finalize()
	{	if (this in all_scenes) // repeater will be null if finalize has already been called.
		{	writefln(this);
			pause();
			super.finalize(); // needs to occur before sound_thread finalize to free sound nodes.
			
			if (update_thread)
			{	update_thread.finalize();
				update_thread = null;
			}
			if (sound_thread)
			{	sound_thread.finalize();
				sound_thread = null;
			}
			all_scenes.remove(this);
		}
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
	
	/**
	 * Get / a function to call if the sound or update thread's update function throws an exception.
	 * If this is set to null (the default), then the exception will just be thrown. 
	 * */
	void setErrorFunction(void delegate(Exception e) on_error) /// ditto
	{	sound_thread.setErrorFunction(on_error);
		update_thread.setErrorFunction(on_error);
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
	
	/// Get / set the speed of sound (in game units per second) variable that will be passed to OpenAL.
	float getSpeedOfSound()
	{	return sound_thread.getDopplerVeloity();
	}	
	void setSpeedOfSound(float speed) /// ditto
	{	sound_thread.setDopplerVelocity(speed/343.3);
	}
	
	/**
	 * Get the Repeater that handles all sound playback for this scene. */
	Repeater getSoundThread()
	{	return sound_thread;		
	}

	/**
	 * Get the Repeater that calls update() in its own thread.
	 * This allows more advanced interaction than the shorthand functions implemented above.
	 * See:  yage.core.repeater  */
	Repeater getUpdateThread()
	{	return update_thread;		
	}

	/**
	 * Implement the time control functions of ITemporal.
	 * 
	 * When the scene's timer (implementd as a Repeater) runs, it updates
	 * the positions and rotations of all Nodes in this Scene.
	 * Each Scene is updated in its own thread.  
	 * If the updating thread gets behind, it will always attempt to catch up by updating more frequently.*/
	void play()
	{	update_thread.play();
		sound_thread.play();
	}
	void pause() /// ditto
	{	update_thread.pause();
		sound_thread.pause();
	}	
	bool paused() /// ditto
	{	return update_thread.paused();
	}	
	
	void seek(double seconds) /// ditto
	{	update_thread.seek(seconds);
		// no point in seeking the sound thread.
	}
	double tell() /// ditto
	{	return update_thread.tell();		
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
		{	timestamp[transform_write] = getUTCtime();
			transform_write = 3 - (transform_read+transform_write);
		}
	}

	/**
	 * Update all Nodes in the scene by delta seconds.
	 * This function is typically called automatically at a set interval from the scene's update_thread once scene.play() is called.
	 * Params:
	 *     delta = time in seconds.  If not set, defaults to the amount of time since the last time update() was called. */
	override void update(float delta = delta.tell())
	{	super.update(delta);
		delta_time = delta;
		this.delta.reset();
		scene.swapTransformWrite();
	}
	
	/**
	 * This is typically called automatically at a set interval from the scene's sound_thread. 
	 * Params:
	 *     delta = This is required to match the signature of Repeater's callback function, but is otherwise unused.*/
	void updateSounds(float delta=0)
	{	sound_thread.processQueue();
		synchronized(sounds_mutex)
			foreach (sound; sounds)
				sound.updateBuffers();
	}	

	/*
	 * Apply OpenGL options specific to this Scene.  This function is used internally by
	 * the engine and doesn't normally need to be called.
	 * TODO: Rename to bind */
	void apply()
	in
	{	assert(Device.isDeviceThread()); /// TODO: use closure queue or glcontext mutex to allow calling from anywhere.
	}
	body
	{	glLightModelfv(GL_LIGHT_MODEL_AMBIENT, ambient.vec4f.ptr);
		Vec4f color = background.vec4f;
		glClearColor(color.x, color.y, color.z, color.w);

		if (fog_enabled)
		{	glFogfv(GL_FOG_COLOR, fog_color.vec4f.ptr);
			glFogf(GL_FOG_DENSITY, fog_density);
			glEnable(GL_FOG);
		} else
			glDisable(GL_FOG);
	}

	
	/*
	 * Add/remove the light from the scene's list of lights.
	 * This function is used internally by the engine and doesn't normally need to be called.*/
	void addLight(LightNode light)
	{	synchronized (lights_mutex) lights[light] = light;
	}
	void removeLight(LightNode light) // ditto
	{	synchronized (lights_mutex) lights.remove(light);
	}
	
	/**
	 * Get all LightNodes that are currently a part of this scene.
	 * Returns: a self indexed array. */
	LightNode[LightNode] getAllLights()
	{	return lights;		
	}
	
	/*
	 * Add/remove the sound from the scene's list of sounds.
	 * This function is used internally by the engine and doesn't normally need to be called.*/
	void addSound(SoundNode sound)
	{	synchronized (sounds_mutex) sounds[sound] = sound;	
	}	
	void removeSound(SoundNode sound) // ditto
	{	synchronized (sounds_mutex) sounds.remove(sound);
	}
	
	/**
	 * Get all SoundNodes that are currently a part of this scene.
	 * Returns: a self indexed array. */
	SoundNode[SoundNode] getAllSounds()
	{	return sounds;		
	}

	/**
	 * Get a self-indexed array of all senes that are active (have been constructed but not finalized). */
	static Scene[Scene] getAllScenes()
	{	return all_scenes;		
	}
}
