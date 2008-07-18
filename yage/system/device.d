/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.system.device;

import std.stdio;
import std.string;
import derelict.openal.al;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;
import derelict.util.exception;
import derelict.sdl.sdl;
import derelict.sdl.image;
import derelict.ogg.vorbis;
import derelict.ogg.vorbisfile;
import derelict.freetype.ft;
import yage.gui.surface;
import yage.system.log;
import yage.system.constant;
import yage.core.vector;

import std.c.stdlib : exit;

// Enable specular highlights with textures.
const int LIGHT_MODEL_COLOR_CONTROL_EXT = 0x81F8;
const int SINGLE_COLOR_EXT = 0x81F9;
const int SEPARATE_SPECULAR_COLOR_EXT	= 0x81FA;

extern(C) {
	void _moduleDtor();
	void gc_term();
}

/**
 * The device class exists to group functions for initializing a window,
 * checking OpenGL extensions, and other utility and lower level tasks.*/
abstract class Device
{
	
	// Video
	protected static SDL_Surface* sdl_surface; // Holds a reference to the main (and only) SDL surface

	protected static Vec2i		size;			// The width/height of the window.
	protected static uint 		viewport_width; // The width of the current viewport
	protected static uint 		viewport_height;// The height of the current viewport
	protected static ubyte 		depth;
	protected static bool 		fullscreen;

	// Audio
	protected static ALCdevice	*al_device;
	protected static ALCcontext	*al_context;

	// Misc
	protected static bool initialized=0;			// true if init() has been called

	
	protected static Surface surface;
	
	
	//static Surface[] children;
	
	/// Unload SDL at exit.
	static ~this()
	{	if (initialized)
		{	try {	// Order of un-initialization is causing trouble here with OpenAL
				//writefln("Device destructor");
				SDL_Quit();
				//alcDestroyContext(al_context);
				//alcCloseDevice(al_device);
			}catch{ throw new Exception("Error in Device destructor."); }
		}
	}

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
	{
		this.size.x = width;
		this.size.y= height;
		this.depth = depth;
		this.fullscreen = fullscreen;

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
			throw new Exception ("Unable to initialize SDL: "~ .toString(SDL_GetError()));

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
			throw new Exception ("Unable to set " ~ .toString(size.x) ~ "x" ~ .toString(size.y) ~
			" video mode: : " ~ .toString(SDL_GetError()));
		SDL_LockSurface(sdl_surface);

		// Attempt to load multitexturing
		if (getSupport(DEVICE_MULTITEXTURE))
		{	if (!ARBMultitexture.load("GL_ARB_multitexture"))
				throw new Exception("GL_ARB_multitexture extension detected but it could not be loaded.");
			Log.write("GL_ARB_multitexture support enabled.");
		}else
			Log.write("GL_ARB_multitexture not supported.  This is ok, but graphical quality may be limited.");

		//ARBVertexShader.load("GL_ARB_vertex_shader");
		// Attempt to load shaders
		if (getSupport(DEVICE_SHADER))
		{	if (!ARBShaderObjects.load("GL_ARB_shader_objects"))
				throw new Exception("GL_ARB_shader_objects extension detected but it could not be loaded.");
			if (!ARBVertexShader.load("GL_ARB_vertex_shader"))
				throw new Exception("GL_ARB_vertex_shader extension detected but it could not be loaded.");
			Log.write("GL_ARB_shader_objects support enabled.");
		}else
			Log.write("GL_ARB_shader_objects not supported.  This is ok, but rendering will be limited to the fixed-function pipeline.");

		// Attempt to load vertex buffer object
		if (getSupport(DEVICE_VBO))
		{	if (!ARBVertexBufferObject.load("GL_ARB_vertex_buffer_object"))
				throw new Exception("GL_ARB_vertex_buffer_object extension detected but it could not be loaded.");
			Log.write("GL_ARB_vertex_buffer_object support enabled.");
		}else
			Log.write("GL_ARB_vertex_buffer_object not supported.  This is still ok.");
		
		// Attempt to load blend color extension
		if (getSupport(DEVICE_BLEND_COLOR))
		{	if (!EXTBlendColor.load("GL_EXT_blend_color"))
				throw new Exception("GL_EXT_blend_color extension detected but it could not be loaded.");
			Log.write("GL_EXT_blend_color support enabled.");
		}else
			Log.write("GL_EXT_blend_color not supported.  This is still ok.");

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

		glAlphaFunc(GL_GEQUAL, 0.5f); // If blending is disabled, any pixel less than 0.5 opacity will not be drawn

		// Environment Mapping (disabled by default)
		glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
		glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);

		// Enable support for vertex arrays
		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_NORMAL_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);

		// Enable texture coordinate arrays for each texture unit
		// This crashes some machines.
		/*if (Device.getSupport(DEVICE_MULTITEXTURE))
			for (int i=Device.getLimit(DEVICE_MAX_TEXTURES)-1; i>=0; i--)
			{	glClientActiveTextureARB(GL_TEXTURE0_ARB + i);
				glEnableClientState(GL_TEXTURE_COORD_ARRAY);

				glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
				glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
			}
		*/
		
		// Input options
		SDL_EnableUNICODE(true);
		SDL_EnableKeyRepeat(1, 100);

		// Initialize OpenAL
		al_device = alcOpenDevice(null);
		al_context = alcCreateContext(al_device, null);
		alcMakeContextCurrent(al_context);
		if (alGetError()!=0)
			throw new Exception("There was an error when initializing OpenAL.");

		surface = new Surface();
		
		initialized = true;
		Log.write("Yage has been initialized.");
	}
	
	static void delegate() onExit;
	//Perhaps this needs to be improved, or maybe it will be added to the D runtime and no longer be needed
	static void exit(int code){
		if(onExit) onExit();
		
		_moduleDtor();
		gc_term();
		std.c.stdlib.exit(code);
	}
	
	/**
	 * Searches to see if the given extension is supported in hardware.*/
	static bool checkExtension(char[] name)
	{	char[] exts = std.string.toString(cast(char*)glGetString(GL_EXTENSIONS));
	    int result = find(tolower(exts), tolower(name)~" "); 
	    delete exts; // [above] append space to ensure we're not matching part of another extension.
		if (result>=0)
			return true;
	    return false;
	}

	/// Return an array of all supported OpenGL extensions.
	static char[][] getExtensions()
	{	char[] exts = std.string.toString(cast(char*)glGetString(GL_EXTENSIONS));
		return split(exts, " ");
	}

	/// Return the aspect ratio (width/height) of the rendering window.
	static float getAspectRatio()
	{	if (size.y==0) size.y=1;
		return size.x/cast(float)size.x;
	}

	/**
	 * Get the number from the hardware specified by constant.
	 * Params: constant is a DEVICE constant defined in yage.device.constant, can be
	 * DEVICE_MAX_LIGHTS, DEVICE_MAX_TEXTURE_SIZE, or DEVICE_MAX_TEXTURES. */
	static int getLimit(int constant)
	{	int result;
		switch (constant)
		{	case DEVICE_MAX_LIGHTS:
				glGetIntegerv(GL_MAX_LIGHTS, &result);
				break;
			case DEVICE_MAX_TEXTURE_SIZE:
				glGetIntegerv(GL_MAX_TEXTURE_SIZE, &result);
				break;
			case DEVICE_MAX_TEXTURES:
				glGetIntegerv(GL_MAX_TEXTURE_UNITS, &result);
				break;
			default:
				throw new Exception("Unknown Device.getLimit() constant: '" ~
									.toString(constant) ~ "'.");
		}
		return result;
	}

	/**
	 * Get whether the given opengl feature is supported by the hardware.
	 * Params: constant is a DEVICE_* constant defined in yage.device.constant.*/
	static bool getSupport(int constant)
	{	//return false;
		static int shader=-1, vbo=-1, mt=-1, np2=-1, bc=-1;	// so lookup only has to occur once.
		switch (constant)
		{	case DEVICE_SHADER:
				version(linux)		// Shaders often fail on linux due to poor driver support!  :(
					return false;	// ATI drivers will claim shader support but fail on shader compile.
									// This needs a better workaround.
				if (shader==-1)
					shader = checkExtension("GL_ARB_shader_objects") && checkExtension("GL_ARB_vertex_shader");
				return cast(bool)shader;
			case DEVICE_VBO: //return false; // true breaks custom vertex attributes
				if (vbo==-1)
					vbo = checkExtension("GL_ARB_vertex_buffer_object");
				return cast(bool)vbo;
			case DEVICE_MULTITEXTURE:
				if (mt==-1)
					mt = checkExtension("GL_ARB_multitexture");
				return cast(bool)mt;
			case DEVICE_NON_2_TEXTURE:
				if (np2==-1)
					np2 = checkExtension("GL_ARB_texture_non_power_of_two");
				return cast(bool)np2;
			case DEVICE_BLEND_COLOR:
				if (bc==-1)
					bc = checkExtension("GL_EXT_blend_color");
				return cast(bool)bc;
			default:
				throw new Exception("Unknown Device.getSupport() constant: '" ~
									.toString(constant) ~ "'.");
		}
		return false;
	}

	/**
	 * Get / Set the parent Surface that all others use. */
	static Surface getSurface()
	{	return surface;
	}
	static void setSurface(Surface s)
	{	surface = s;	
	}
	
	/// Return the current width of the window in pixels.
	static uint getWidth()
	{	return size.x;
	}
	/// return the current height of the window in pixels.
	static uint getHeight()
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

	/** Stores the dimensions of the current window size.
	 *  This is called by a resize event in Input.checkInput(). */
	static void resizeWindow(int width, int height)
	{	size.x = width;
		size.y = height;
		Vec2f dsize = Vec2f(size.x, size.y);
		
		surface.calculate();
		
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
				throw new Exception("Failed to resize the window!");
		}
	}
}

