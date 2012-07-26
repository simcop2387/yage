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
 * For best performance:
 * 1.  Minimize the number of cameras in the scene, since each always generate render commands for the render thread.
 * 2.  Nodes without onUpdate set can be processed much faster, since otherwise all updates are in contiguous cache-friendly memory.
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
	// TODO: move these to a struct
	Color ambient;				/// The color of the scene's global ambient light; defaults to black.
	Color backgroundColor;		/// Background color rendered for this Scene when no skybox is specified.  TODO: allow transparency.
	Color fogColor;				/// Color of global scene fog, when fog is enabled.
	float fogDensity = 0.1;		/// The thickness (density) of the Scene's global fog, when fog is enabled.  Depending on the scale of your scene, decent values range between .001 and .1.
	bool  fogEnabled = false;	/// Get / set whether global distance fog is enabled for this scene.
								/// For best results, use no skybox and set the clear color the same as the fog color.
								/// For improved performance, set the cameras' max view distance to just beyond
								/// where objects become completely obscured by the fog. */
	float speedOfSound = 343f;	/// Speed of sound in units/second
	

	//ArrayBuilder!(Node.Transform) nodeTransforms;
	package ContiguousTransforms nodeTransforms;
	
	
	protected CameraNode[CameraNode] cameras;	
	protected LightNode[LightNode] lights;
	protected SoundNode[SoundNode] sounds;
	protected FastLock mutex;
	protected Mutex camerasMutex;
	protected Mutex lightsMutex; // Having a separate mutex prevents render from watiing for the start of the next update loop.
	protected Object soundsMutex;	

	protected Repeater updateThread; // deprecated

	float updateTime;
	
	protected static Scene[Scene] all_scenes; // TODO: Prevents old scenes from being removed!

	package float increment;



	/**
	 * Construct an empty Scene.
	 * The update frequency cannot be changed after the scene is started. */
	this(float frequency = 60)
	{	mutex = new FastLock();

		super();
		scene = this;
		transformIndex = nodeTransforms.addNew(this);
		
		assert(transform().node.transformIndex == transformIndex);

		ambient	= Color("#333"); // OpenGL default global ambient light.
		backgroundColor = Color("black");	// OpenGL default clear color
		fogColor = Color("gray");
		
		// TODO: move threading control to main.
		updateThread = new Repeater(&internalUpdate);
		updateThread.frequency = frequency;
		this.increment = 1/frequency;
	
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
		
		return result;
	}
	
	/**
	 * Overridden to pause the scene update and sound threads and to remove this instance from the array of all scenes. */
	override void dispose()
	{	if (this in all_scenes) // repeater will be null if dispose has already been called.
		{	super.dispose();
			
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
	void update(float delta)
	{
		scope a = new Timer(true);

		mixin(Sync!("this"));
	

		foreach (camera; cameras)
		{	camera.resetRenderCommands();
			if (CameraNode.getListener() is camera)
				camera.updateSoundCommands();
		}
		scope camerasArray = cameras.values; // because looping through an aa inside another loop is much slower

		camerasMutex.lock();
		
		//foreach (inout Transform t; nodeTransforms.data)
		for (int i=0; i<nodeTransforms.length; i++)
		{
			Transform* t = &nodeTransforms.transforms[i];

			bool dirty = false;
			if (t.velocityDelta != Vec3f.ZERO)
			{	t.position += t.velocityDelta;
				dirty = true;
			}

			// Rotate if angular velocity is not zero.
			float angle = t.angularVelocityDelta.w - 3.1415927/4;
			if (angle < -0.0001 || angle > 0.001)
			{	t.rotation = t.rotation * t.angularVelocityDelta;
				dirty = true;
			}

			if (t.onUpdateSet)
				t.node.onUpdate();

			if (dirty)
				t.node.setWorldDirty();

			// Add render commands from node, if it's on screen.
			foreach (camera; camerasArray)
			{	
				// only calculate the world position if the node has a parent
				Vec3f worldPosition = t.parent is null ? t.position : t.node.getWorldPosition(); // also calc's worldScale used below.

				if (camera.isVisible(worldPosition, t.cullRadius * t.worldScale.max()))
				{	VisibleNode vnode = cast(VisibleNode)t.node;					
					if (vnode)
						vnode.getRenderCommands(camera, camera.currentRenderList.lights.data, camera.currentRenderList.commands);	
				}
			}
		}
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