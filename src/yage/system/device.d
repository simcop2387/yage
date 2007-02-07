/**
 * Copyright:  (c) 2006-2007 Eric Poggel
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
import yage.core.horde;
import yage.resource.texture;
import yage.node.camera;
import yage.system.log;
import yage.system.constant;

// Enable specular highlights with textures.
const int LIGHT_MODEL_COLOR_CONTROL_EXT = 0x81F8;
const int SINGLE_COLOR_EXT				= 0x81F9;
const int SEPARATE_SPECULAR_COLOR_EXT	= 0x81FA;

/** The device class exists to group functions for initializing a window,
 *  checking OpenGL extensions, and other utility and lower level tasks.*/
abstract class Device
{
	protected:
	// Video
	static SDL_Surface* sdl_surface; // Holds a reference to the main (and only) SDL surface
	static uint 		width;			// The width of the window.
	static uint 		height; 		// The heght of the window.
	static uint 		viewport_width; // The width of the current viewport
	static uint 		viewport_height;// The height of the current viewport
	static ubyte 		depth;
	static bool 		fullscreen;

	// Audio
	static ALCdevice	*al_device;
	static ALCcontext	*al_context;

	// Misc
	static bool initialized=0;			// true if init() has been called

	// The texture that is rendered to the screen.
	static CameraTexture texture;

	public:


	/// Unload SDL at exit.
	static ~this()
	{	if (initialized)
		{	try {	// Order of un-initialization is causing trouble here with OpenAL
				SDL_Quit();
				//alcDestroyContext(al_context);
				//alcCloseDevice(al_device);
			}catch{ throw new Exception("Error in Device destructor."); }
		}
	}

	/** This function creates a window with the specified width and height in pixels.
	 *  It also initializes an OpenAL context so that audio playback can occur.
	 *  It must be called before most other code.
	 *  \param width Width of the window in pixels
	 *  \param height Height of the window in pixels
	 *  \param depth Color depth of each pixel (should be 16, 24 or 32)
	 *  \param fullscreen The window is fullscreen if true; windowed otherwise.*/
	static void init(int width, int height, ubyte depth, bool fullscreen)
	in
	{	assert(depth==16 || depth==24 || depth==32);
		assert(width>0 && height>0);
	}
	body
	{
		this.width = width;
		this.height= height;
		this.depth = depth;
		this.fullscreen = fullscreen;

		// load shared libraries
		DerelictGL.load();
		DerelictGLU.load();
		DerelictSDL.load();
		DerelictSDLImage.load();
		DerelictAL.load();
		DerelictVorbis.load();
		DerelictVorbisFile.load();


		// Initialize SDL video
		if(SDL_Init(SDL_INIT_VIDEO) < 0)
			throw new Exception ("Unable to initialize SDL: "~ .toString(SDL_GetError()));

		// Create the screen surface (window)
		uint flags = SDL_HWSURFACE | SDL_GL_DOUBLEBUFFER | SDL_OPENGL | SDL_RESIZABLE | SDL_HWPALETTE | SDL_HWACCEL;
		if (fullscreen) flags |= SDL_FULLSCREEN;
		sdl_surface = SDL_SetVideoMode(width, height, depth, flags);
		if(sdl_surface is null)
			throw new Exception ("Unable to set " ~ .toString(width) ~ "x" ~ .toString(height) ~
			" video mode: : " ~ .toString(SDL_GetError()));
		SDL_LockSurface(sdl_surface);

		// Load functions for OpenGL past 1.1 as far as possible
		// Perhaps only load 1.1 and only load what's needed manually?
		GLVersion glv = DerelictGL.availableVersion();

		// Attempt to load vertex buffer object
		if (getSupport(DEVICE_SHADER))
		{	if (!ARBShaderObjects.load("GL_ARB_shader_objects"))
				throw new Exception("GL_ARB_shader_objects extension detected but it could not be loaded.");
			Log.write("GL_ARB_shader_objects support enabled.");
		}else
			Log.write("GL_ARB_shader_objects not supported.  This is ok, but rendering will be limited to the fixed-function pipelone.");

		// Attempt to load shaders
		if (getSupport(DEVICE_VBO))
		{	if (!ARBVertexBufferObject.load("GL_ARB_vertex_buffer_object"))
				throw new Exception("GL_ARB_vertex_buffer_object extension detected but it could not be loaded.");
			Log.write("GL_ARB_vertex_buffer_object support enabled.");
		}else
			Log.write("GL_ARB_vertex_buffer_object not supported.  This is still ok.");

		//if (getLimit(DEVICE_MAX_TEXTURE_UNITS) < 2)
		//	throw new Exception("No hardware support found for 2+ texture units.  " ~
		//	"This hardware supports only " ~.toString(getLimit(DEVICE_MAX_TEXTURE_UNITS)) ~ ".");

		// OpenGL options
		// These are the engine defaults.  Any function that
		// modifies these should reset them when done.
		glShadeModel(GL_SMOOTH);
		glClearDepth(1);
		glEnable(GL_DEPTH_TEST);
		glDepthFunc(GL_LEQUAL);

		glEnable(GL_CULL_FACE);
		glEnable(GL_NORMALIZE);
		glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
		glHint(GL_FOG_HINT, GL_FASTEST);
		glLightModeli(GL_LIGHT_MODEL_LOCAL_VIEWER, true); // [below] Specular highlights w/ textures.
		glLightModeli(LIGHT_MODEL_COLOR_CONTROL_EXT, SEPARATE_SPECULAR_COLOR_EXT);

		glEnable(GL_LIGHTING);
		glFogi(GL_FOG_MODE, GL_EXP); // Most realistic?

		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);
		glEnableClientState(GL_NORMAL_ARRAY);

		// Input options
		SDL_EnableUNICODE(true);
		SDL_EnableKeyRepeat(1, 100);

		// Initialize OpenAL
		al_device = alcOpenDevice(null);
		al_context = alcCreateContext(al_device, null);
		alcMakeContextCurrent(al_context);
		if (alGetError()!=0)
			throw new Exception("There was an error when initializing OpenAL.");

		initialized = true;
		Log.write("Yage has been initialized.");
	}

	/// Return an array of all supported OpenGL extensions.
	static char[][] getExtensions()
	{	char[] exts = std.string.toString(cast(char*)glGetString(GL_EXTENSIONS));
		return split(exts, " ");
	}


	/** Searches to see if the given extension is supported in hardware.
	 *  Spaces are pre and postpended to name because extension names can be
	 *  prefixes of other extension names. */
	static bool checkExtension(char[] name)
	{	char[] exts = std.string.toString(cast(char*)glGetString(GL_EXTENSIONS));
	    int result = find(toupper(exts), toupper(name)~" ");
	    delete exts;
		if (result>=0)
			return true;
	    return false;
	}

	/**
	 * Get the number from the hardware specified by constant.
	 * Params: constant is a DEVICE constant defined in yage.device.constant.*/
	static int getLimit(int constant)
	{	int result;
		switch (constant)
		{	case DEVICE_MAX_LIGHTS:
				glGetIntegerv(GL_MAX_LIGHTS, &result);
				break;
			case DEVICE_MAX_TEXTURE_SIZE:
				glGetIntegerv(GL_MAX_TEXTURE_SIZE, &result);
				break;
			case DEVICE_MAX_TEXTURE_UNITS:
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
	{	switch (constant)
		{	case DEVICE_SHADER:
				version(linux)	// Shaders often fail on linux due to poor driver support!  :(
				{	return false;
				}
				static int s = -1;
				if (s==-1)
					s = checkExtension("GL_ARB_shader_objects");
				return cast(bool)s;
			case DEVICE_VBO:
				static int s = -1;
				if (s==-1)
					s = checkExtension("GL_ARB_vertex_buffer_object");
				return cast(bool)s;
			case DEVICE_NON_2_TEXTURE:
				static int s = -1;
				if (s==-1)
					s = checkExtension("GL_ARB_texture_non_power_of_two");
				return cast(bool)s;
			default:
				throw new Exception("Unknown Device.getSupport() constant: '" ~
									.toString(constant) ~ "'.");
		}
		return false;
	}

	/// Draw the current material to the screen.
	static void render()
	{	glPushAttrib(0xFFFFFFFF);	// all attribs

		// Setup the viewport in orthogonal mode,
		// with dimensions 0..width, 0..height
		// with 0,0 being at the top left.
		glViewport(0, 0, width, height);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0, 1, 1, 0, -1, 1);
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		glEnable(GL_TEXTURE_2D);
		glDisable(GL_DEPTH_TEST);
		glDisable(GL_LIGHTING);

		// If our texture is larger than the viewport, set the size of the quad to adjust.
		if (texture !is null)
		{	float x = texture.requested_width/cast(float)texture.getWidth();
			float y = texture.requested_height/cast(float)texture.getHeight();

			// Draw a textured quad of our current material
			texture.bind(true, TEXTURE_FILTER_BILINEAR);
			glBegin(GL_QUADS);
			glTexCoord2f(0, 0); glVertex2f(0, 1);
			glTexCoord2f(x, 0); glVertex2f(1, 1);
			glTexCoord2f(x, y); glVertex2f(1, 0);
			glTexCoord2f(0, y); glVertex2f(0, 0);
			glEnd();
		}

		SDL_GL_SwapBuffers();
		glPopAttrib();
	}

	/// Return the aspect ratio (width/height) of the rendering window.
	static float getAspectRatio()
	{	if (height==0) height=1;
		return width/cast(float)height;
	}

	/// Return the current width of the window in pixels.
	static uint getWidth()
	{	return width;
	}
	/// return the current height of the window in pixels.
	static uint getHeight()
	{	return height;
	}

	/** Resize the viewport to the given size.  Special values of
	 *  zero scale the viewport to the window size. */
	static void resizeViewport(int _width, int _height, float near, float far, float fov, float aspect)
	{	viewport_width = _width;
		viewport_height = _height;

		// special values of 0 means stretch to window size
		if (viewport_width ==0) viewport_width  = width;
		if (viewport_height==0) viewport_height = height;

		// Ensure our new resolution is less than the window size
		// This might no longer be an issue once framebufferobjects are used.
		if (viewport_width  > width)  viewport_width  = width;
		if (viewport_height > height) viewport_height = height;

		glViewport(0, 0, viewport_width, viewport_height);

		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		if (aspect==0) aspect = getAspectRatio();
		gluPerspective(fov, aspect, near, far);

		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
	}

	/** Stores the dimensions of the current window size.
	 *  This is called by a resize event in Input.checkInput(). */
	static void resizeWindow(int _width, int _height)
	{	width = _width;
		height = _height;

		// For some reason, SDL Linux requires a call to SDL_SetVideoMode for a screen resize that's
		// larger than the current screen. (need to try this with latest version of SDL, alsy try SDL lock surface)
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

