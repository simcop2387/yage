/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
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
import yage.gui.surface;
import yage.system.log;
import yage.system.sound.soundsystem;
import yage.system.graphics.all;
import yage.core.object2;;
import yage.core.math.vector;
import yage.scene.scene;
import yage.resource.lazyresource;
import yage.resource.manager;
import yage.resource.texture;
import yage.resource.geometry;

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
	static void init(int width, int height, ubyte depth, bool fullscreen, ubyte samples=1)
	in
	{	assert(depth==16 || depth==24 || depth==32);
		assert(width>0 && height>0);
	}
	body
	{	active = true;
		this.size.x = width;
		this.size.y= height;
		this.depth = depth;
		this.fullscreen = fullscreen;
		
		this.self_thread = Thread.getThis();

		// load shared libraries
		DerelictGL.load();
		DerelictGLU.load();
		DerelictSDL.load();
		DerelictSDLImage.load();
		DerelictFT.load();
		DerelictAL.load();
		DerelictVorbis.load();
		DerelictVorbisFile.load();


		// Initialize SDL video
		if(SDL_Init(SDL_INIT_VIDEO) < 0)
			throw new YageException ("Unable to initialize SDL: "~ fromStringz(SDL_GetError()));

		// Anti-aliasing
		if (samples > 1)
		{	SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
			SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, samples);
		}

		// Create the screen surface (window)
		uint flags = SDL_HWSURFACE | SDL_GL_DOUBLEBUFFER | SDL_OPENGL | SDL_RESIZABLE | SDL_HWPALETTE | SDL_HWACCEL;
		if (fullscreen) flags |= SDL_FULLSCREEN;
		sdl_surface = SDL_SetVideoMode(size.x, size.y, depth, flags);
		if(sdl_surface is null)
			throw new YageException("Unable to set %dx%d video mode: %s ", size.x, size.y, SDL_GetError());
		SDL_LockSurface(sdl_surface);

		// Attempt to load multitexturing		
		if (Probe.openGL(Probe.OpenGL.MULTITEXTURE))
		{	if (!ARBMultitexture.load("GL_ARB_multitexture"))
				throw new YageException("GL_ARB_multitexture extension detected but it could not be loaded.");
		}else
			Log.write("GL_ARB_multitexture not supported.  This is ok, but graphical quality may be limited.");

		//ARBVertexShader.load("GL_ARB_vertex_shader");
		// Attempt to load shaders
		if (Probe.openGL(Probe.OpenGL.SHADER))
		{	if (!ARBShaderObjects.load("GL_ARB_shader_objects"))
				throw new YageException("GL_ARB_shader_objects extension detected but it could not be loaded.");
			if (!ARBVertexShader.load("GL_ARB_vertex_shader"))
				throw new YageException("GL_ARB_vertex_shader extension detected but it could not be loaded.");
			Log.write("GL_ARB_shader_objects support enabled.");
		}else
			Log.write("GL_ARB_shader_objects not supported.  This is ok, but rendering will be limited to the fixed-function pipeline.");

		// Attempt to load vertex buffer object
		if (Probe.openGL(Probe.OpenGL.VBO))
		{	if (!ARBVertexBufferObject.load("GL_ARB_vertex_buffer_object"))
				throw new YageException("GL_ARB_vertex_buffer_object extension detected but it could not be loaded.");
			Log.write("GL_ARB_vertex_buffer_object support enabled.");
		}else
			Log.write("GL_ARB_vertex_buffer_object not supported.  This is still ok.");

		// OpenGL options
		// These are the engine defaults.  Any function that
		// modifies these should reset them when done.
		glShadeModel(GL_SMOOTH);
		glClearDepth(1);
		glEnable(GL_DEPTH_TEST);
		glDepthFunc(GL_LEQUAL);

		glEnable(GL_CULL_FACE);
		glEnable(GL_NORMALIZE);  // GL_RESCALE_NORMAL is faster but does not work for non-uniform scaling
		glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
		glHint(GL_FOG_HINT, GL_FASTEST); // per vertex fog
		glLightModeli(GL_LIGHT_MODEL_LOCAL_VIEWER, true); // [below] Specular highlights w/ textures.
		glLightModeli(LIGHT_MODEL_COLOR_CONTROL_EXT, SEPARATE_SPECULAR_COLOR_EXT);

		glEnable(GL_LIGHTING);
		glFogi(GL_FOG_MODE, GL_EXP); // Most realistic?

		// Environment Mapping (disabled by default)
		glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
		glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);

		// Enable support for vertex arrays
		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_NORMAL_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
		
		// Input options
		SDL_EnableUNICODE(true);
		SDL_EnableKeyRepeat(1, 100);

		surface = new Surface();
		
		// Not used yet
		GLContext glc = new GLContext();
		
		// Create OpenAL device, context, and start sound proessing thread.
		SoundContext.getInstance();
		
		initialized = true;
		Log.write("Yage has been initialized successfully.");
	}
	
	/**
	 * Release all Yage Resources.  
	 * If System.init() is called, this must be called for cleanup before the program closes.
	 * After calling this function, many Yage functions can no longer be called safely. */
	static void deInit()
	in {
		assert(isSystemThread());
	} body
	{	initialized = false;
	
		SDL_WM_GrabInput(SDL_GRAB_OFF);
		SDL_ShowCursor(true);
	
		foreach_reverse (s; Scene.getAllScenes().values)
			s.finalize();
			
		SoundContext.getInstance().finalize();
		ResourceManager.finalize();
		
		// Clean up resources not managed by the ResourceManager.
		
		foreach (item; GPUTexture.getAll().values)
			item.finalize();
		// Forces cleanup of any other resources
		GC.collect();
		GraphicsResource.finalize();
		
		LazyResourceManager.processQueue(); // required for any pending lazyresource destroys
		
		SDL_Quit();
		
		active = false;
		Log.write("Yage has been de-initialized successfully.");
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
	 * abourtException provides a good exception callback for any asynchronous code that may throw an exception. */
	static void abort(char[] message)
	{	if (message.length)
			Log.write(message);
		aborted = true;
	}
	static void abortException(Exception e) /// ditto
	{	abort(e.toString());
	}
	
	/// Has the abort flag been set?
	static bool isAborted()
	{	return aborted;
	}
	
	
	
	
	
	
	
	
	// --- Everything below here should eventually be moved into Window ---
	
	protected static SDL_Surface* sdl_surface; // Holds a reference to the main (and only) SDL surface
	protected static Vec2i	size;			// The width/height of the window.
	protected static uint 	viewport_width; // The width of the current viewport
	protected static uint 	viewport_height;// The height of the current viewport
	protected static ubyte 	depth;
	protected static bool 	fullscreen;
	protected static Surface surface;

	/**
	 * Return the aspect ratio (width/height) of the rendering window. */
	static float getAspectRatio()
	{	if (size.y==0) 
			size.y=1;
		return size.x/cast(float)size.y;
	}

	/**
	 * Get / Set the parent Surface that all others use. */
	static Surface getSurface()
	{	return surface;
	}
	static void setSurface(Surface s)
	{	surface = s;	
	}
	
	/**
	 * Get the current width/height of the window in pixels. */
	static uint getWidth()
	{	return size.x;
	}	
	static uint getHeight() /// ditto
	{	return size.y;
	}
	
	/** 
	 * Resize the viewport to the given size.  
	 * Special values of zero scale the viewport to the window size. 
	 * This is usually called by Camera. */
	static void resizeViewport(int _width, int _height, float near, float far, float fov, float aspect)
	{	viewport_width = _width;
		viewport_height = _height;

		// special values of 0 means stretch to window size
		if (viewport_width ==0) viewport_width  = size.x;
		if (viewport_height==0) viewport_height = size.y;

		// Ensure our new resolution is less than the window size
		// This might no longer be an issue once framebufferobjects are used.
		if (viewport_width  > size.x)  viewport_width  = size.x;
		if (viewport_height > size.y) viewport_height = size.y;

		glViewport(0, 0, viewport_width, viewport_height);

		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		if (aspect==0) aspect = getAspectRatio();
		gluPerspective(fov, aspect, near, far);

		glMatrixMode(GL_MODELVIEW);

	}

	/** 
	 * Stores the dimensions of the current window size.
	 * This is called by a resize event in Input.checkInput(). */
	static void resizeWindow(int width, int height)
	{	size.x = width;
		size.y = height;
		//Vec2f dsize = Vec2f(size.x, size.y);
		
		surface.updateDimensions();
		
		// For some reason, SDL Linux requires a call to SDL_SetVideoMode for a screen resize that's
		// larger than the current screen. (need to try this with latest version of SDL, also try SDL lock surface)
		// This same code would crash the engine on windows.
		// This code may now be un-needed and needs to be retested.
		// See http://www.libsdl.org/cgi/docwiki.cgi/SDL_5fResizeEvent
		version (linux)
		{	uint flags = SDL_HWSURFACE | SDL_GL_DOUBLEBUFFER | SDL_OPENGL | SDL_RESIZABLE | SDL_HWPALETTE | SDL_HWACCEL;
			if (fullscreen)
				flags |= SDL_FULLSCREEN;
			sdl_surface = SDL_SetVideoMode(width, height, 0, flags);
			if (sdl_surface is null)
				throw new YageException("Failed to resize the window!");
		}
	}
}