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
import yage.resource.texture;
import yage.gui.surface;
import yage.system.log;
import yage.system.constant;
import yage.system.input;

// Enable specular highlights with textures.
const int LIGHT_MODEL_COLOR_CONTROL_EXT = 0x81F8;
const int SINGLE_COLOR_EXT				= 0x81F9;
const int SEPARATE_SPECULAR_COLOR_EXT	= 0x81FA;

/**
 * The device class exists to group functions for initializing a window,
 * checking OpenGL extensions, and other utility and lower level tasks.*/
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
	//static CameraTexture texture;
	
	public:
	
	static Surface[] subs;
	
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
	static void init(int width, int height, ubyte depth, bool fullscreen, ubyte samples=32)
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

		// Anti-aliasing
		if (samples > 1)
		{	SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
			SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, samples);
		}

		// Create the screen surface (window)
		uint flags = SDL_HWSURFACE | SDL_GL_DOUBLEBUFFER | SDL_OPENGL | SDL_RESIZABLE | SDL_HWPALETTE | SDL_HWACCEL;
		if (fullscreen) flags |= SDL_FULLSCREEN;
		sdl_surface = SDL_SetVideoMode(width, height, depth, flags);
		if(sdl_surface is null)
			throw new Exception ("Unable to set " ~ .toString(width) ~ "x" ~ .toString(height) ~
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

		// Enable Vertex arrays
		glEnableClientState(GL_VERTEX_ARRAY);
		glEnableClientState(GL_NORMAL_ARRAY);
		glEnableClientState(GL_TEXTURE_COORD_ARRAY);

		// Enable texture coordinate arrays for each texture unit
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
		Input.setGrabMouse(true);

		// Initialize OpenAL
		al_device = alcOpenDevice(null);
		al_context = alcCreateContext(al_device, null);
		alcMakeContextCurrent(al_context);
		if (alGetError()!=0)
			throw new Exception("There was an error when initializing OpenAL.");

		initialized = true;
		Log.write("Yage has been initialized.");
	}

	/**
	 * Searches to see if the given extension is supported in hardware.*/
	static bool checkExtension(char[] name)
	{	char[] exts = std.string.toString(cast(char*)glGetString(GL_EXTENSIONS));
	    int result = find(toupper(exts), toupper(name)~" ");
	    delete exts;
		if (result>=0)
			return true;
	    return false;
	}

	/// Return an array of all supported OpenGL extensions.
	static char[][] getExtensions()
	{	char[] exts = std.string.toString(cast(char*)glGetString(GL_EXTENSIONS));
		return split(exts, " ");
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
		static int shader=-1, vbo=-1, mt=-1, np2=-1;	// so support only has to be found once
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
			default:
				throw new Exception("Unknown Device.getSupport() constant: '" ~
									.toString(constant) ~ "'.");
		}
		return false;
	}

	/// Draw the current material to the screen.
	static void render(){
		glPushAttrib(0xFFFFFFFF);	// all attribs

		// Setup the viewport in orthogonal mode,
		// with dimensions 0..width, 0..height
		// with 0,0 being at the top left.
		glViewport(0, 0, width, height);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0, 1, 1, 0, -1, 1);
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();

		glDisable(GL_DEPTH_TEST);
		glDisable(GL_LIGHTING);
		
		glEnable(GL_TEXTURE_2D);
		
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		foreach(sub; this.subs)
			sub.draw();

		SDL_GL_SwapBuffers();

		//Texture(texture, true, TEXTURE_FILTER_BILINEAR).bind();
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

	}

	/** Stores the dimensions of the current window size.
	 *  This is called by a resize event in Input.checkInput(). */
	static void resizeWindow(int _width, int _height)
	{	width = _width;
		height = _height;
		
		foreach(sub ;this.subs)	sub.recalculate(width, height);
		
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

