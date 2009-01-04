/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.system.window;

import std.string;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.util.exception;
import derelict.sdl.sdl;

import yage.core.vector;
import yage.core.exceptions;
import yage.core.interfaces;


// TODO: Have Device use this code.
// Note that SDL supports only one window at a time.
// Should this extend Repeater and put all rendering in its own thread?
class Window : IRenderTarget
{
	protected SDL_Surface* sdl_surface;
	protected Vec2i		size;
	protected Vec2i 	viewport_size;
	protected ubyte 	depth;
	protected bool 		fullscreen;
	
	this()
	{
		// Create the screen surface (window)
		uint flags = SDL_HWSURFACE | SDL_GL_DOUBLEBUFFER | SDL_OPENGL | SDL_RESIZABLE | SDL_HWPALETTE | SDL_HWACCEL;
		if (fullscreen) 
			flags |= SDL_FULLSCREEN;
		sdl_surface = SDL_SetVideoMode(size.x, size.y, depth, flags);
		if(sdl_surface is null)
			throw new YageException("Unable to set " ~ .toString(size.x) ~ "x" ~ .toString(size.y) ~
			" video mode: : " ~ .toString(SDL_GetError()));
		SDL_LockSurface(sdl_surface);
	}
	
	/// Return the aspect ratio (width/height) of the window.
	float getAspectRatio()
	{	if (size.y==0) 
			size.y=1;
		return size.x/cast(float)size.y;
	}
	
	/// Return the current width of the window in pixels.
	int getWidth()
	{	return size.x;		
	}
	/// return the current height of the window in pixels.
	int getHeight()
	{	return size.y;
	}
	
	void bindRenderTarget()
	{		
	}
	
	void unbindRenderTarget()
	{		
	}
	
	/** 
	 * Resize the viewport to the given size.  
	 * Special values of zero scale the viewport to the window size. 
	 * This is usually called by Camera. */
	void resizeViewport(int width, int height, float near, float far, float fov, float aspect)
	{	viewport_size.x = width;
		viewport_size.y = height;

		// special values of 0 means stretch to window size
		if (viewport_size.x ==0) viewport_size.x  = size.x;
		if (viewport_size.y==0) viewport_size.y = size.y;

		// Ensure our new resolution is less than the window size
		// This might no longer be an issue once framebufferobjects are used.
		if (viewport_size.x > size.x)  viewport_size.x  = size.x;
		if (viewport_size.y > size.y) viewport_size.y = size.y;

		glViewport(0, 0, viewport_size.x, viewport_size.y);

		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		if (aspect==0) aspect = getAspectRatio();
		gluPerspective(fov, aspect, near, far);

		glMatrixMode(GL_MODELVIEW);

	}

	/** 
	 * Stores the dimensions of the current window size.
	 *  his is called by a resize event in Input.checkInput(). */
	void resizeWindow(int width, int height)
	{	size.x = width;
		size.y = height;
		
		//surface.update();
		
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