/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.system;

import tango.stdc.stringz;
import tango.core.Memory;
import tango.core.Thread;
import derelict.openal.al;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;
import derelict.util.exception;
import derelict.sdl.sdl;
import derelict.sdl.image;
import derelict.ogg.vorbis;
import derelict.freetype.ft;
import yage.core.all;
import yage.gui.surface;
import yage.system.log;
import yage.system.sound.soundsystem;
import yage.system.graphics.all;
import yage.core.object2;
import yage.core.math.vector;
import yage.scene.scene;
import yage.resource.manager;
import yage.resource.resource;
import yage.system.window;

// OpenGL constants to enable specular highlights with textures.
const int LIGHT_MODEL_COLOR_CONTROL_EXT = 0x81F8;
const int SINGLE_COLOR_EXT = 0x81F9;
const int SEPARATE_SPECULAR_COLOR_EXT	= 0x81FA;

/**
 * The System class exists to initilize/deinitialize Yage and provide a place for
 * common, lower-level, yage-specific functions. */
abstract class System
{	
	protected static bool active = false;		// true if between a call to init and deinit, inclusive
	protected static bool initialized=false;	// true if between a call to init and deinit, exclusive
	protected static bool aborted = false; 		// this flag is set when the engine is ready to exit.
	
	protected static Thread self_thread; 		// reference to thread that called init, typically the main thread
	
	/**
	 * This function creates a window with the specified width and height in pixels.
	 * It also initializes an OpenAL context so that audio playback can occur.
	 * It must be called before most other code.
	 * Params:
	 * width = Width of the window in pixels
	 * height = Height of the window in pixels
	 * depth = Color depth of each pixel (should be 16, 24 or 32)
	 * fullscreen = The window is fullscreen if true; windowed otherwise.
	 * samples = The level of anti-aliasing. */
	static void init()
	{	
		active = true;
		this.self_thread = Thread.getThis();

		// load shared libraries (should these be loaded lazily?)
		DerelictSDL.load();
		DerelictSDLImage.load();
		DerelictFT.load();
		DerelictAL.load();
		DerelictVorbis.load();
		DerelictVorbisFile.load();
	
		// Input options
		SDL_EnableUNICODE(true);
		SDL_EnableKeyRepeat(1, 100);
				
		// Load embedded resources.
		ResourceManager.init();
		
		// Create OpenAL device, context, and start sound processing thread.
		SoundContext.getInstance();
				
		initialized = true;
		Log.info("Yage has been initialized successfully.");
	}
	
	/**
	 * Release all Yage Resources.  
	 * If System.init() is called, this must be called for cleanup before the program closes.
	 * After calling this function, many Yage functions can no longer be called safely. */
	static void deInit()
	{	assert(isSystemThread());
		
		initialized = false;
		
		SDL_WM_GrabInput(SDL_GRAB_OFF);
		SDL_ShowCursor(true);
		
		foreach_reverse (s; Scene.getAllScenes().values)
			s.dispose();
		foreach (item; ExternalResource.getAll().values)
			item.dispose();
		
		Render.cleanup(); // textures, vbo's, etc.
		
		SoundContext.getInstance().dispose();		
		ResourceManager.dispose();
		
		if (Window.getInstance())
			Window.getInstance().dispose();
	
		GC.collect();
		
		SDL_Quit();
		
		DerelictSDL.unload();
		DerelictSDLImage.unload();
		DerelictFT.unload();
		DerelictAL.unload();
		DerelictVorbis.unload();
		DerelictVorbisFile.unload();
		
		active = false;
		Log.info("Yage has been de-initialized successfully.");
	}

	/**
	 * Returns true if called from the same thread as what System.init() was called.
	 * This is useful to ensure that rendering functions aren't called from other threads. 
	 * Always returns false if called before System.init() */
	static bool isSystemThread()
	{	if (self_thread)
			return !!(Thread.getThis() == self_thread);
		return false;
	}
	
	/**
	 * Set the abort flag signalling that the application is ready for exit.
	 * This may be called manually or automatically on an error.
	 * abortException provides a good exception callback for any asynchronous code that may throw an exception. */
	static void abort(char[] message)
	{	if (message.length)
			Log.info(message);
		aborted = true;
	}
	static void abortException(Exception e) /// ditto
	{	abort(e.toString());
	}
	
	/// Has the abort flag been set?
	static bool isAborted()
	{	return aborted;
	}
}