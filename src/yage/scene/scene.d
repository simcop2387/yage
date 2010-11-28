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
class Scene : Node//, ITemporal, IDisposable
{
	Color ambient;				/// The color of the scene's global ambient light; defaults to black.
	Color backgroundColor;		/// Background color rendered for this Scene when no skybox is specified.  TODO: allow transparency.
	Color fogColor;				/// Color of global scene fog, when fog is enabled.
	float fogDensity = 0.1;		/// The thickness (density) of the Scene's global fog, when fog is enabled.  Depending on the scale of your scene, decent values range between .001 and .1.
	bool  fogEnabled = false;	/// Get / set whether global distance fog is enabled for this scene.
								/// For best results, use no skybox and set the clear color the same as the fog color.
								/// For improved performance, set the cameras' max view distance to just beyond
								/// where objects become completely obscured by the fog. */
	float speedOfSound = 343f;	/// Speed of sound in units/second
	
	Scene skyBox;				/// A Scene can have another heirarchy of nodes that will be rendered as a skybox by any camera. 
	
	
	protected CameraNode[CameraNode] cameras;	
	protected LightNode[LightNode] lights;
	protected SoundNode[SoundNode] sounds;
	protected FastLock mutex;
	protected Mutex camerasMutex;
	protected Mutex lightsMutex; // Having a separate mutex prevents render from watiing for the start of the next update loop.
	protected Object soundsMutex;	

	protected Repeater updateThread;

	float updateTime;
	
	protected static Scene[Scene] all_scenes; // TODO: Prevents old scenes from being removed!

	/// Construct an empty Scene.
	this(float frequency = 60)
	{	mutex = new FastLock();
		
		super();
	
		scene = this;
		ambient	= Color("#333"); // OpenGL default global ambient light.
		backgroundColor = Color("black");	// OpenGL default clear color
		fogColor = Color("gray");
		
		updateThread = new Repeater(&internalUpdate);
		updateThread.frequency = frequency;
	
		camerasMutex = new Mutex();
		lightsMutex = new Mutex();
		soundsMutex = new Object();
		
		all_scenes[this] = this;
	}
	
	private void internalUpdate() // release build fails to get frame pointer if this is nested.
	{	update(1f/updateThread.frequency);
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
	/*override*/ Scene clone(bool children=false, Scene destination=null)
	{	
		mixin(Sync!("this"));
		
		auto result = cast(Scene)super.clone(children, destination);				
		result.ambient = ambient;
		result.speedOfSound = speedOfSound;
		result.backgroundColor = backgroundColor;
		result.fogColor = fogColor;
		result.fogDensity = fogDensity;
		result.fogEnabled = fogEnabled;
		result.skyBox = skyBox;
		
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
			
			if (updateThread)
			{	updateThread.dispose();
				updateThread = null;
			}
			cameras = null;
			lights = null;
			sounds = null;
			all_scenes.remove(this);
		}
	}

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
	{	mutex.lock();
	}	
	void unlock() /// ditto
	{	mutex.unlock();
	}
	
	/*
	 * Get the Repeater that calls update() in its own thread.
	 * This allows more advanced interaction than the shorthand functions implemented below.
	 * See:  yage.core.repeater  */
	Repeater getUpdateThread()
	{	return updateThread;		
	}
	
	/**
	 * Implement the time control functions of ITemporal.
	 * 
	 * When the scene's timer (implementd as a Repeater) runs, it updates
	 * the positions and rotations of all Nodes in this Scene.
	 * Each Scene is updated in its own thread.  
	 * If the updating thread gets behind, it will always attempt to catch up by updating more frequently.*/
	void play()
	{	updateThread.play();
	}
	void pause() /// ditto
	{	updateThread.pause();
	}	
	bool paused() /// ditto
	{	return updateThread.paused();
	}	
	void seek(double seconds) /// ditto
	{	updateThread.seek(seconds);
	}
	double tell() /// ditto
	{	return updateThread.tell();		
	}

	/**
	 * Update all Nodes in the scene by delta seconds.
	 * This function is typically called automatically at a set interval from the scene's updateThread once scene.play() is called.
	 * Params:
	 *     delta = time in seconds.  If not set, defaults to the amount of time since the last time update() was called. */
	override void update(float delta)
	{
		mixin(Sync!("this"));
		
		Timer a = new Timer(true);
	
		// Update all nodes recursively
		super.update(delta); 
		
		//Log.write(a.tell());
		
		Timer b = new Timer(true);
		
		// Cull and create render commands for each camera
		camerasMutex.lock();
		foreach (camera; cameras) 
		{	camera.updateRenderCommands();
			if (CameraNode.getListener() is camera)
				camera.updateSoundCommands();
		}
		//Log.write("cull ", b.tell()); // Culling is 5x slower than updating!!!
		
		camerasMutex.unlock();
		updateTime = a.tell();
	}

	/*
	 * Add/remove the light from the scene's list of lights.
	 * This function is used internally by the engine and doesn't normally need to be called.*/
	package void addLight(LightNode light)
	{	mixin(Sync!("lightsMutex"));
		lights[light] = light;
	}
	package void removeLight(LightNode light) // ditto
	{	mixin(Sync!("lightsMutex"));
		lights.remove(light); 
	}
	
	/**
	 * Get all LightNodes that are currently a part of this scene. */
	LightNode[LightNode] getAllLights()
	{	mixin(Sync!("lightsMutex"));
		return lights;
	}
	
	/*
	 * Add/remove the camera from the scene's list of cameras.
	 * This function is used internally by the engine and doesn't normally need to be called.*/
	package void addCamera(CameraNode camera)
	{	mixin(Sync!("camerasMutex"));
		cameras[camera] = camera;
	}
	package void removeCamera(CameraNode camera) // ditto
	{	mixin(Sync!("camerasMutex"));
		cameras.remove(camera);
	}

	/**
	 * Get all CameraNodes that are currently a part of this scene.
	 * Returns: a self indexed array. */
	CameraNode[CameraNode] getAllCameras()
	{	mixin(Sync!("camerasMutex"));
		return cameras;		
	}
	
	/*
	 * Add/remove the sound from the scene's list of sounds.
	 * This function is used internally by the engine and doesn't normally need to be called.*/
	package void addSound(SoundNode sound)
	{	synchronized (soundsMutex) // Why does this cause a deadlock?
			sounds[sound] = sound;	
	}	
	package void removeSound(SoundNode sound) // ditto
	{	synchronized (soundsMutex) 
			sounds.remove(sound);
	}	
	
	/**
	 * Get all SoundNodes that are currently a part of this scene.
	 * Returns: a self indexed array. */
	SoundNode[SoundNode] getAllSounds()
	{	return sounds;		
	}
	
	/*
	 * Used internally. */
	Object getSoundsMutex()
	{	return soundsMutex;		
	}

	/**
	 * Get a self-indexed array of all senes that are active (have been constructed but not disposed). */
	static Scene[Scene] getAllScenes()
	{	return all_scenes;		
	}
}


/// Add this as the first line of a function to synchronize the entire body using the name of a Tango mutex.
template Sync(char[] T)
{	const char[] Sync = 
		"typeof("~T~") tempT;" ~
		"if ("~T~")" ~
		"{	tempT = "~T~";" ~
		"	tempT.lock();" ~
		"}"~
		"scope(exit)" ~
		"	if (tempT)" ~
		" 		tempT.unlock();";	
}