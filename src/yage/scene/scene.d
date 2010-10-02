/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.scene;

import tango.core.Thread;
import tango.core.sync.Mutex;
import tango.time.Clock;
import yage.core.all;
import yage.system.system;
import yage.system.sound.soundsystem;
import yage.system.log;
import yage.scene.camera;
import yage.scene.light;
import yage.scene.node;
import yage.scene.sound;
import yage.scene.visible;

/**
 * A Scene is the root of a tree of Nodes, and threfore never has a parent.
 * Certain "global" variables are stored per Scene and affect all Nodes in that Scene. 
 * Examples include global ambient lighting and the speed of sound.
 * Scenes also maintain an array of all LightNodes in them.
 *
 * Each Scene updates its nodes in its own thread at a fixed frequencty, 
 * controlled by play(), pause() and other ITemporal methods.
 *
 * Example:
 * --------------------------------
 * Scene scene = new Scene();
 * scene.play();                          // Start the scene updater at 60 times per second.
 * scope(exit) scene.pause();             // Ensure it stops later.
 *
 * Scene skybox = new Scene();            // Create a skybox for the scene.
 * ModelNode sky = skybox.addChild(new ModelNode()); // A model with all faces pointing inward.
 * sky.setModel("sky/sanctuary.ms3d");    // Use this 3D model as geometry for the skybox.
 * scene.setSkybox(skybox);
 * --------------------------------
 */
class Scene : Node//, ITemporal
{
	protected Mutex mutex;
	protected int lockCount;
	public Thread owner;
	
	/**
	 * Scenes are often used by multiple threads at once.
	 * When a thread users a scene, it will first call lock() to acquire ownership and then unlock() when finished.
	 * This is done automatically by Node member functions.  However, if several operations need to be performed,
	 * an entire block of code can be nested between manual calls to lock() and unlock().  This will also perform
	 * better than the otherwise fine-grained synchronization.
	 * 
	 * For convenience, lock() and unlock() calls may be nested.  Subsequent lock() calls will still maintain the lock, 
	 * but unlocking will only occur after unlock() has been called an equal number of times. */
	void lock()
	{	if (Thread.getThis() !is owner) 
		{	mutex.lock();
			owner = Thread.getThis();
		}
		lockCount++;
	}	
	void unlock() /// ditto
	{	assert(Thread.getThis() is owner);
		lockCount--;
		if (!lockCount)
		{	mutex.unlock();
			owner = null;
		}
	}
	
	// Old:
	//---------------------------------------------
	
	Color ambient;				/// The color of the scene's global ambient light; defaults to black.
	Color backgroundColor;		/// Background color rendered for this Scene when no skybox is specified.  TODO: allow transparency.
	Color fogColor;				/// Color of global scene fog, when fog is enabled.
	float fogDensity = 0.1;		/// The thickness (density) of the Scene's global fog, when fog is enabled.
										/// Depending on the scale of your scene, decent values range between .001 and .1.
	bool  fogEnabled = false;	/// Get / set whether global distance fog is enabled for this scene.
								/// For best results, use no skybox and set the clear color the same as the fog color.
								/// For improved performance, set the cameras' max view distance to just beyond
								/// where objects become completely obscured by the fog. */
	float speedOfSound = 343f;	/// Speed of sound in units/second
	
	Scene skyBox;				/// A Scene can have another heirarchy of nodes that will be rendered as a skybox by any camera. 
	
	protected CameraNode[CameraNode] cameras;	
	protected LightNode[LightNode] lights;
	protected SoundNode[SoundNode] sounds;
	package Object cameras_mutex;
	package Object lights_mutex;
	package Object sounds_mutex;	
	package Object transform_mutex;			// Ensure that swapTransformRead and swapTransformWrite don't occur at the same time.

	protected Repeater update_thread;
	
	protected long timestamp[3];			// Used for timestamps of newest transform_read/write
	package int transform_read=0, transform_write=1;

	protected Timer delta; 					// time since the last time this Scene was updated.
	protected float delta_time;

	protected static Scene[Scene] all_scenes;
	
	
	/// Construct an empty Scene.
	this(float frequency = 60)
	{	mutex = new Mutex();
		
		super();
	
		delta = new Timer(true);
		scene = this;
		ambient	= Color("#333"); // OpenGL default global ambient light.
		backgroundColor = Color("black");	// OpenGL default clear color
		fogColor = Color("gray");
		
		update_thread = new Repeater();
		update_thread.setFrequency(frequency);
		update_thread.setFunction(&update);		
		update_thread.setErrorFunction(&defaultErrorFunction);
	
		cameras_mutex = new Object();
		lights_mutex = new Object();
		sounds_mutex = new Object();
		transform_mutex = new Object();
		
		all_scenes[this] = this;
	}
	
	/**
	 * Call dispose() on destruction. */
	~this()
	{	dispose();		
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
		result.speedOfSound = speedOfSound;
		result.backgroundColor = backgroundColor;
		result.fogColor = fogColor;
		result.fogDensity = fogDensity;
		result.fogEnabled = fogEnabled;
		result.skyBox = skyBox;
		
		// non-atomic operations
		synchronized (this)
		{	result.delta.seek(delta.tell());
			result.delta.pause();
		}
		
		return result;
	}
	unittest
	{	// Test duplication of a running scene.
		// this no longer works since the scene constructor now requires the openAl .dll/.so
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
	override void dispose()
	{	if (this in all_scenes) // repeater will be null if dispose has already been called.
		{	super.dispose(); // needs to occur before sound_thread dispose to free sound nodes.
			
			if (update_thread)
			{	update_thread.dispose();
				update_thread = null;
			}
			
			lights = null;
			sounds = null;
			all_scenes.remove(this);
		}
	}

	/// Return the amount of time since the last time update() was called for this Scene.
	float getDeltaTime()
	{	return delta_time;
	}
	
	/**
	 * Get all CameraNodes that are currently a part of this scene.
	 * Returns: a self indexed array. */
	CameraNode[CameraNode] getAllCameras()
	{	return cameras;		
	}
	
	/**
	 * Get all LightNodes that are currently a part of this scene.
	 * Returns:  A copy of the Lights array to avoid synchronization issues. */
	LightNode[] getAllLights()
	{	synchronized (lights_mutex) // crashes occur without this
			return lights.values;
	}
	
	/**
	 * Get all SoundNodes that are currently a part of this scene.
	 * Returns: a self indexed array. */
	SoundNode[SoundNode] getAllSounds()
	{	return sounds;		
	}

	/**
	 * Get / a function to call if the sound or update thread's update function throws an exception.
	 * If this is set to null (the default), then the exception will just be thrown. 
	 * Params:
	 *     on_error = Defaults to System.abortException.  If null, any errors from the Scene's 
	 *     sound or update threads will cause the threads to terminate silently. */
	void setErrorFunction(void delegate(Exception e) on_error)
	{	update_thread.setErrorFunction(on_error);
	}
	void setErrorFunction(void function(Exception e) on_error) /// ditto
	{	update_thread.setErrorFunction(on_error);
	}
	void defaultErrorFunction(Exception e)
	{	Log.error("The scene thread threw an uncaught exception:  %s", e.msg);
		System.abort("Yage is aborting due to scene exception.");
	}

	/*
	 * Get the Repeater that calls update() in its own thread.
	 * This allows more advanced interaction than the shorthand functions implemented below.
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
	}
	void pause() /// ditto
	{	update_thread.pause();
	}	
	bool paused() /// ditto
	{	return update_thread.paused();
	}	
	void seek(double seconds) /// ditto
	{	update_thread.seek(seconds);
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
		{	timestamp[transform_write] = Clock.now().ticks();
			transform_write = 3 - (transform_read+transform_write);
		}
	}

	/**
	 * Update all Nodes in the scene by delta seconds.
	 * This function is typically called automatically at a set interval from the scene's update_thread once scene.play() is called.
	 * Params:
	 *     delta = time in seconds.  If not set, defaults to the amount of time since the last time update() was called. */
	override void update(float delta = delta.tell())
	{	lock(); // new!
	
		super.update(delta);
		delta_time = delta;
		this.delta.seek(0);
		scene.swapTransformWrite();
		
		unlock(); // new!
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
	
	/*
	 * Add/remove the camera from the scene's list of cameras.
	 * This function is used internally by the engine and doesn't normally need to be called.*/
	void addCamera(CameraNode camera)
	{	synchronized (cameras_mutex) cameras[camera] = camera;
	}
	void removeCamera(CameraNode camera) // ditto
	{	synchronized (cameras_mutex) cameras.remove(camera);
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
	
	/*
	 * Used internally. */
	Object getSoundsMutex()
	{	return sounds_mutex;		
	}

	/**
	 * Get a self-indexed array of all senes that are active (have been constructed but not disposed). */
	static Scene[Scene] getAllScenes()
	{	return all_scenes;		
	}
	
	
}
