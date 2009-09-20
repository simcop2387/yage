/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel, Joe Pusdesris (deformative0@gmail.com)
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.input;

public import derelict.sdl.sdl;

import yage.core.math.vector;
import yage.system.system;
import yage.system.window;
import yage.gui.surface;


/**
 * A class to handle keyboard, mouse, and eventually joystick input.
 * This polls SDL for input and passes it to the current surface.
 */ 
class Input
{
	protected static Vec2i mouse; // The current pixel location of the mouse cursor; (0, 0) is top left.
	protected static Surface currentSurface;	// Surface that the mouse is currently over

	/** 
	 * Process input, handle window resize and close events, and send the remaining events to surface,
	 * calling the surfaces's keyDown, keyUp, mouseDown, MouseUp, and mouseOver functions as appropriate. */
	static void processAndSendTo(Surface surface)
	{
		// Disable key repeating, we'll handle that manually.
		//SDL_EnableKeyRepeat(0, SDL_DEFAULT_REPEAT_INTERVAL); // why doesn't this work? Need to try again since I have the latest version of SDL
				
		SDL_Event event;
		while(SDL_PollEvent(&event))
		{
			switch(event.type)
			{
				// Keyboard
				case SDL_KEYDOWN:
					
					auto focus = getFocusSurface(surface);
					if(focus) // keysym.sym gets all keys on the keyboard, including separate keys for numpad, keysym.unicde should be reserved for text.
					{	focus.keyDown(event.key.keysym.sym, event.key.keysym.mod);
						//focus.keyDown(event.key.keysym.unicode, event.key.keysym.mod);
						//focus.text ~= toUTF8([cast(dchar)(event.key.keysym.sym)]);
					}
					break;
				case SDL_KEYUP:
	    			
	    			auto focus = getFocusSurface(surface);
					if(focus)
						focus.keyUp(event.key.keysym.sym, event.key.keysym.mod);
						//focus.keyUp(event.key.keysym.unicode, event.key.keysym.mod);
					
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
					if(currentSurface) // [below] negative y because opengl y goes from bottom to top
						currentSurface.mouseMove(event.button.button, Vec2i(event.motion.xrel, -event.motion.yrel));
	
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
	}
	
	/**
	 * Get the surface that is under the mouse. */
	private static Surface getMouseSurface(Surface surface) {
		if(Surface.getGrabbedSurface()) 
			return Surface.getGrabbedSurface();
		return surface.findSurface(mouse.x, mouse.y);
	}
	
	/**
	 * Get the surface that currently has focus. */
	private static Surface getFocusSurface(Surface surface) {
		if(Surface.getFocusSurface()) 
			return Surface.getFocusSurface();
		return surface;
	}
}