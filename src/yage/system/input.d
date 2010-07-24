/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel, Joe Pusdesris (deformative0@gmail.com)
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.input;

public import derelict.sdl.sdl;
import tango.stdc.time;
import yage.core.math.vector;
import yage.system.log;
import yage.system.system;
import yage.system.window;
import yage.gui.surface;

/**
 * A static class to handle keyboard, mouse, and eventually joystick input.
 * This polls SDL for input and passes it to the current surface.
 * 
 * TODO: Ditch SDL!  SDL requires input processing to be in the same thread as the renderer.
 */ 
abstract class Input
{
	public static int KEY_DELAY = 500; /// milliseconds before repeating a call to keyPress after holding a key down.
	public static int KEY_REPEAT = 30; /// milliseconds before subsequent calls to keyPress after KEY_DELAY occurs.
	
	protected static Vec2i mouse; // The current pixel location of the mouse cursor; (0, 0) is top left.
	protected static Surface currentSurface;	// Surface that the mouse is currently over

	protected static SDL_keysym lastKeyDown; // Used for manual key-repeat.
	protected static uint lastKeyDownTime = uint.max;
	
	/** 
	 * Process input, handle window resize and close events, and send the remaining events to surface,
	 * calling the surfaces's keyDown, keyUp, mouseDown, MouseUp, and mouseOver functions as appropriate. */
	static void processAndSendTo(Surface surface)
	{
		
		SDL_EnableUNICODE(1);
		auto focus = getFocusSurface(surface);
				
		SDL_Event event;
		while(SDL_PollEvent(&event))
		{	
			switch(event.type)
			{
				// Keyboard
				case SDL_KEYDOWN:
					if(focus) // keysym.sym gets all keys on the keyboard, including separate keys for numpad, keysym.unicde should be reserved for text.
					{	focus.keyDown(event.key.keysym.sym, event.key.keysym.mod);
					
						// Kepress will be called with the key repeat settings.
						focus.keyPress(event.key.keysym.sym, event.key.keysym.mod, event.key.keysym.unicode);
						lastKeyDown = event.key.keysym;
						lastKeyDownTime = clock()*1000 / CLOCKS_PER_SEC;
					}
					break;
				case SDL_KEYUP:	    			
					if(focus)
						focus.keyUp(event.key.keysym.sym, event.key.keysym.mod);
					lastKeyDownTime = uint.max;
					break;
				
				// Mouse
				case SDL_MOUSEBUTTONDOWN:
					auto over = getMouseSurface(surface);
					if(over) 
						over.mouseDown(event.button.button, mouse);
	
					break;
				case SDL_MOUSEBUTTONUP:
					auto over = getMouseSurface(surface);
					if(over)
						over.mouseUp(event.button.button, mouse);
	
					break;
				case SDL_MOUSEMOTION:			
					mouse.x = event.motion.x;
					mouse.y = event.motion.y;
					
					// Doing this before getMouseSurface() fixes the mouse leaving the surface while dragging.
					if(currentSurface)
						currentSurface.mouseMove(event.button.button, Vec2i(event.motion.xrel, event.motion.yrel));
	
					//if the surface that the mouse is in has changed
					auto over = getMouseSurface(surface);
					if(currentSurface !is over)
					{	
						if(currentSurface) //Tell it that the mouse left
							currentSurface.mouseOut(over, event.button.button, mouse);
						if(over) //Tell it that the mosue entered
							over.mouseOver(event.button.button, mouse);							
						
						currentSurface = over; //The new current surface
					}

					break;
	
				// System
				//case SDL_ACTIVEEVENT:
				//case SDL_VIDEOEXPOSE:
				case SDL_VIDEORESIZE:
					if (Window.getInstance())
						Window.getInstance().resizeWindow(event.resize.w, event.resize.h);
					break;
				case SDL_QUIT:
					System.abort("Yage aborted by window close");
					break;
				default:
					break;
			}
		}
		
		// Key repeat
		if (focus)
		{		
			uint now = clock()*1000/CLOCKS_PER_SEC;			
			if (now - KEY_DELAY > lastKeyDownTime)
			{	focus.keyPress(lastKeyDown.sym, lastKeyDown.mod, lastKeyDown.unicode);
				lastKeyDownTime += KEY_REPEAT;
			}
		}
	}
	
	/**
	 * Get the surface that is under the mouse. */
	private static Surface getMouseSurface(Surface surface) {
		if(Surface.getGrabbedSurface()) 
			return Surface.getGrabbedSurface();
		return surface.findSurface(mouse.x, mouse.y);
	}
	
	/**
	 * Get the surface that currently has focus, or the given surface if no surface has focus */
	private static Surface getFocusSurface(Surface surface) {
		if(Surface.getFocusSurface()) 
			return Surface.getFocusSurface();
		return surface;
	}
}