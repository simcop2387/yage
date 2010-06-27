/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.window;

import tango.stdc.stringz;
import tango.io.Stdout;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;
import derelict.util.exception;
import derelict.sdl.sdl;
import derelict.sdl.image;
import yage.gui.surface;

import yage.core.all;
import yage.core.object2;
import yage.core.math.vector;
import yage.resource.image;
import yage.scene.scene;
import yage.system.log;
import yage.system.graphics.all;
import yage.system.system;

import yage.core.math.vector;
import yage.core.object2;


//OpenGL constants to enable specular highlights with textures (why aren't these in Derelict?).
const int LIGHT_MODEL_COLOR_CONTROL_EXT = 0x81F8;
const int SINGLE_COLOR_EXT = 0x81F9;
const int SEPARATE_SPECULAR_COLOR_EXT	= 0x81FA;


/**
 * This class is for creating and managing the Window that Yage uses for rendering.
 * Due to the same limitation in SDL, Yage only supports one Window at a time.
 * Example:
 * --------
 * System.init(); // required
 * auto window = Window.getInstance();
 * window.setResolution(640, 480); // window is created/recreated here
 * --------
 */
class Window : IRenderTarget
{
	enum Buffer
	{	COLOR,
		DEPTH,
		STENCIL
	}
	
	protected SDL_Surface* sdlSurface;	
	protected Vec2i	size; // size of the window
	protected Vec2i viewportPosition;
	protected Vec2i viewportSize;
	protected char[] title, taskbarName;
	
	protected static Window instance;	

	private this()
	{	
		DerelictGL.load();
		DerelictGLU.load();
		
		// Initialize SDL video
		if(SDL_Init(SDL_INIT_VIDEO) < 0)
			throw new YageException ("Unable to initialize SDL: "~ fromStringz(SDL_GetError()));
	}

	
	void dispose()
	{	if (instance)
		{	SDL_FreeSurface(sdlSurface);
			DerelictGL.unload();
			DerelictGLU.unload();
			instance = null;
		}
	}
	
	/// Get the width/height of this Window's display area (not including title/borders) in pixels.
	override int getWidth()
	{	return size.x;		
	}
	override int getHeight() /// ditto
	{	return size.y;		
	}
	
	///
	Vec2i getViewportPosition()
	{	return viewportPosition;
	}
	///
	Vec2i getViewportSize()
	{	return viewportSize;
	}
	
	/**
	 * Minimize the Window. */
	void minimize()
	{	SDL_WM_IconifyWindow();
	}
	
	/**
	 * Set the caption for the Window.
	 * Params:
	 *     title = The caption shown on top of the window
	 *     taskbarName = The caption shown on the window's taskbar entry.  Defaults to title. */
	void setCaption(char[] title, char[] taskbarName=null)
	{	if (!taskbarName)
			taskbarName = title;		
		SDL_WM_SetCaption(toStringz(title), toStringz(taskbarName));
	}

	/**
	 * Create (or recreate) the window singleton at this resolution.
	 * Unfortunately this resets the OpenGL context on Windows, which currently causes a crash on subsequent calls.
	 * Params:
	 *     width = Width of the window in pixels
	 *     height = Height of the window in pixels
	 *     depth = Color depth of each pixel.  Should be 16, 24, 32, or 0 for auto.
	 *     fullscreen = The window is fullscreen if true; windowed otherwise.
	 *     samples = The number of samples to use for anti-aliasing (1 for no aa).
	 */
	void setResolution(int width, int height, ubyte depth=0, bool fullscreen=false, ubyte samples=1)
	{
		assert(depth==0 || depth==16 || depth==24 || depth==32); // 0 for current screen depth
		assert(width>0 && height>0);

		// Anti-aliasing
		if (samples > 1)
			SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
		else
			SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 0);
		SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, samples);
		
		size.x = width;
		size.y = height;

		// If SDL ever decouples window creation from initialization, we can move these to System.init().
		// Create the screen surface (window)
		uint flags = SDL_HWSURFACE | SDL_GL_DOUBLEBUFFER | SDL_OPENGL | SDL_RESIZABLE | SDL_HWPALETTE | SDL_HWACCEL;
		if (fullscreen) flags |= SDL_FULLSCREEN;
		sdlSurface = SDL_SetVideoMode(size.x, size.y, depth, flags);
		if(sdlSurface is null)
			throw new YageException("Unable to set %dx%d video mode: %s ", size.x, size.y, SDL_GetError());
		SDL_LockSurface(sdlSurface);
		
		// These have to be set after window creation.
		SDL_EnableUNICODE(1);
		SDL_EnableKeyRepeat(1, 100);
		
		// Attempt to load multitexturing		
		if (Probe.feature(Probe.Feature.MULTITEXTURE))
		{	if (!ARBMultitexture.load("GL_ARB_multitexture"))
				throw new YageException("GL_ARB_multitexture extension detected but it could not be loaded.");
			Log.info("GL_ARB_multitexture support enabled.");
		}else
			Log.info("GL_ARB_multitexture not supported.  This is ok, but graphical quality may be limited.");
		
		// Texture Compression
		if (Probe.feature(Probe.Feature.TEXTURE_COMPRESSION))
		{	if (!ARBTextureCompression.load("GL_ARB_texture_compression"))
				throw new YageException("GL_ARB_texture_compression extension detected but it could not be loaded.");
			Log.info("GL_ARB_texture_compression support enabled.");
		}else
			Log.info("GL_ARB_multitexture not supported.  This is ok, but graphical quality may be limited.");

		// Attempt to load shaders
		if (Probe.feature(Probe.Feature.SHADER))
		{	if (!ARBShaderObjects.load("GL_ARB_shader_objects"))
				throw new YageException("GL_ARB_shader_objects extension detected but it could not be loaded.");
			if (!ARBVertexShader.load("GL_ARB_vertex_shader"))
				throw new YageException("GL_ARB_vertex_shader extension detected but it could not be loaded.");
			Log.info("GL_ARB_shader_objects support enabled.");
		}else
			Log.info("GL_ARB_shader_objects not supported.  This is ok, but rendering will be limited to the fixed-function pipeline.");

		// Attempt to load vertex buffer object
		if (Probe.feature(Probe.Feature.VBO))
		{	if (!ARBVertexBufferObject.load("GL_ARB_vertex_buffer_object"))
				throw new YageException("GL_ARB_vertex_buffer_object extension detected but it could not be loaded.");
			Log.info("GL_ARB_vertex_buffer_object support enabled.");
		}else
			Log.info("GL_ARB_vertex_buffer_object not supported.  This is still ok.");
		
		// Frame Buffer Object
		if (Probe.feature(Probe.Feature.FBO))
		{	if (!EXTFramebufferObject.load("GL_EXT_framebuffer_object"))
				throw new YageException("GL_EXT_framebuffer_object extension detected but it could not be loaded.");
			Log.info("GL_EXT_framebuffer_object support enabled.");
		}else
			Log.info("GL_EXT_framebuffer_object not supported.  This is still ok.");
		
		
				
		// OpenGL options
		// These are the engine defaults.  Any function that modifies these should reset them when done.
		// TODO: Move these to OpenGL.reset()
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
		
		setViewport();
	}
	
	/**
	 * Set the viewport position and size
	 * Params:
	 *     topLeft = Top left coordinates of the viewport in pixels.
	 *     widthHeight = Width and height of the viewport in pixels.  If zero, defaults to window width/height. */
	void setViewport(Vec2i topLeft=Vec2i(0), Vec2i widthHeight=Vec2i(0))
	{	if (widthHeight.x <= 0)
			widthHeight.x = size.x;
		if (widthHeight.y <= 0)
			widthHeight.y = size.y;
		glViewport(topLeft.x, topLeft.y, widthHeight.x, widthHeight.y);
		viewportPosition = topLeft;
		viewportSize = widthHeight;
	}
	
	/** 
	 * Stores the dimensions of the current window size.
	 * This is called by a resize event in Input.checkInput(). */
	void resizeWindow(int width, int height)
	{	size.x = width;
		size.y = height;
		//Vec2f dsize = Vec2f(size.x, size.y);
		
		//System.surface.updateDimensions();
		
		// Seems to do nothing.
		SDL_UpdateRect(sdlSurface, 0, 0, 0, 0);

		
		// For some reason, SDL Linux requires a call to SDL_SetVideoMode for a screen resize that's
		// larger than the current screen. (need to try this with latest version of SDL, also try SDL lock surface)
		// This same code would crash the engine on windows.
		// This code may now be un-needed and needs to be retested.
		// See http://www.libsdl.org/cgi/docwiki.cgi/SDL_5fResizeEvent
		version (linux)
		{	uint flags = SDL_HWSURFACE | SDL_GL_DOUBLEBUFFER | SDL_OPENGL | SDL_RESIZABLE | SDL_HWPALETTE | SDL_HWACCEL;
			if (fullscreen)
				flags |= SDL_FULLSCREEN;
			sdlSurface = SDL_SetVideoMode(width, height, 0, flags);
			if (sdlSurface is null)
				throw new YageException("Failed to resize the window!");
		}
	}

	/**
	 * Get an image from the Window's back-buffer (where image operations take place).
	 * Params:
	 *     buffer = Can be COLOR, DEPTH, or STENCIL to get the corresponding buffer.
	 * Returns: Image1ub for the stencil buffer, Image1ui for the depth buffer, or Image3ub for the color buffer.
	 * Example:
	 * --------
	 * IImage image = Window.getInstance().toImage(Window.Buffer.DEPTH);
	 * ubyte[] data = image.convert!(ubyte, 1).getBytes();  // convert image from 32-bit grayscale to 8-bit grayscale
	 * File file = new File("depth.raw", File.WriteCreate); // Photoshop can open raw files
	 * file.write(image.convert!(ubyte, 1).getBytes());
	 * file.close();
	 * --------
	 */
	ImageBase toImage(Buffer buffer=Buffer.COLOR)
	{
		if (buffer==Buffer.STENCIL)		{
			Image1ub result = new Image1ub(size.x, size.y);			
			glReadPixels(0, 0, size.x, size.y, GL_STENCIL_INDEX, GL_UNSIGNED_BYTE, result.data.ptr);
			return result;
		}
		else if (buffer==Buffer.DEPTH)
		{	Image2!(int, 1) result = new Image2!(int, 1)(size.x, size.y);			
			glReadPixels(0, 0, size.x, size.y, GL_DEPTH_COMPONENT, GL_UNSIGNED_INT, result.data.ptr);
			return result;
		} else // color
		{	Image3ub result = new Image3ub(size.x, size.y);			
			glReadPixels(0, 0, size.x, size.y, GL_RGB, GL_UNSIGNED_BYTE, result.data.ptr);
			return result;
		}
	}
	
	
	/**
	 * Returns: The singleton Window instance. */
	static Window getInstance()
	{	if (instance)
			return instance;
		return instance = new Window();
	}
}


/**
 * This class is the unimplemented successor to Window.
 * It will use native system calls instead of SDL.
 * All windows should share the same OpenGL context, created and destroyed in System.init/deInit
 */
class Window2
{
	protected uint handle;
	
	struct Mode
	{	ushort width;
		ushort height;
		ubyte depth;
		ubyte defaultFrequency;
		ubyte[] frequencies;
	}
	
	struct Screen
	{	ushort number;
		Mode currentMode;
		Mode[] availableModes;		
	}
	
	this(uint handle) 
	{		
	}
	
	this(short width, short height, short x, short y, byte depth, bool fullscreen=false, ushort screen=0) 
	{ 		
	}
	
	bool resize(short width, short height, short x, short y, byte depth, bool fullscreen=false, ushort screen=0)
	{	return true;
	}
	
	uint getHandle()
	{	return handle;
	}
	
	void setVisible(bool visible) 
	{		
	}
	
	static Screen[] getScreens()
	{	Screen[] result;
		return result;
	}
}
