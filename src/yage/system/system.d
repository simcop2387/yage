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
import derelict.opengl3.gl;
import derelict.opengl3.ext;
import derelict.util.exception;
import derelict.sdl2.sdl;
import derelict.sdl2.image;
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
import yage.system.window;
import yage.system.libraries;

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
		// Currently DerelictGL is loaded in Window's constructor.
		DerelictSDL.load();
		DerelictSDLImage.load();
		DerelictAL.load();
		Libraries.loadVorbis();
		Libraries.loadFreeType();

		// Create OpenAL device, context, and start sound processing thread.
		SoundContext.init();

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

		SoundContext.deInit(); // stop the sound thread

		foreach_reverse (s; Scene.getAllScenes().values)
			s.dispose();

		Render.cleanup(0); // textures, vbo's, and other OpenGL resources

		ResourceManager.dispose();

		if (Window.getInstance())
			Window.getInstance().dispose();

		// TODO: This shouldn't be needed to force any calls to dispose.
		//GC.collect(); // Crashes when called in debug mode

		SDL_Quit();
		DerelictSDL.unload();
		DerelictSDLImage.unload();
		DerelictAL.unload();
		Libraries.loadVorbis(false);
		Libraries.loadFreeType(false);
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

	struct Credit
	{	string name;
		string handle;
		string code;
		string license;
		static Credit opCall(string name, char[] handle, char[] code, char[] license)
		{	Credit result;
			result.name=name;
			result.handle=handle;
			result.code=code;
			result.license=license;
			return result;
		}
	}

	static Credit[] getCredits()
	{
		return [
		    Credit("Joe Pusderis", "Deformative", "The first versions of yage.gui.surface, initial version of terrain support, .obj model file format loader, linux fixes", "LGPL v3"),
		    Credit("Brandon Lyons", "Etherous", "Ideas and interface for a second version of the Terrain engine", "Boost 1.0"),
		    Credit("Ludovic Angot", "anarky", "Linux fixes", "Boost 1.0"),
		    Credit("William V. Baxter III", "", "yage.resource.dds", "Zlib/LibPng"),
		    Credit("Michael Parker and Others", "Aldacron", "Derelict", "BSD"),
		    Credit("Walter Bright and others", "", "The D Programming Language", ""),
		    Credit("Tango Developers", "", "The Tango Library", "Academic Free License v3.0 or BSD License"),
		    Credit("FreeType Developers", "", "FreeType Project", "FreeType License or GPL"),
		    Credit("Xiph Foundation", "", "Ogg/Vorbis", "BSD"),
		    Credit("Jean-Loup Gailly and Mark Adler", "", "ZLib", "Zlib/LibPng"),
		    Credit("LibPng Developers", "", "LibPng", "Zlib/LibPng"),
		    Credit("Independent JPEG Group", "", "Jpeg", "This software is based in part on the work of the Independent JPEG Group."),
		    Credit("Sam Lantiga and others", "", "SDL", "LGPL"),
		    Credit("Sam Lantinga and Mattias Engdegård", "", "SDL_Image", "LGPL"),
			Credit("Eric Poggel", "JoeCoder", "everything else", "LGPL v3")
		];
	}
}
