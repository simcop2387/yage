/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel, Joe Pusdesris (deformative0@gmail.com)
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.system.input;

public import derelict.sdl.sdl;

import yage.core.math.vector;
import yage.system.system;
import yage.gui.surface;


/**
 * A class to handle keyboard, mouse, and eventually joystick input.
 * This polls SDL for input and passes it to the current surface.
 */ 
class Input
{
	static int mousex, mousey; // The current pixel location of the mouse cursor; (0, 0) is top left.

	protected static Surface currentSurface;	// Surface that the mouse is currently over


	/** This function fills the above fields with the current intput data.
	 *  See the descriptions of each field for more details.  If this function is not called,
	 *  then input can be handled manually.  See http://www.libsdl.org/cgi/docwiki.cgi/SDL_5fEvent
	 *  for details on manual SDL input processing. */
	static void processInput()
	{
		// Disable key repeating, we'll handle that manually.
		//SDL_EnableKeyRepeat(0, SDL_DEFAULT_REPEAT_INTERVAL);	// why doesn't this work? Need to try again since I have the latest version of SDL
				
		SDL_Event event;
		while(SDL_PollEvent(&event))
		{
			switch(event.type)
			{
				// Keyboard
				case SDL_KEYDOWN:
					
					auto surface = getMouseSurface(); // TODO: Change this to the surface that has focus
					if(surface) // keysym.sym gets all keys on the keyboard, including separate keys for numpad, keysym.unicde should be reserved for text.
					{	surface.keyDown(event.key.keysym.sym, event.key.keysym.mod);
						//surface.keyDown(event.key.keysym.unicode, event.key.keysym.mod);
						//surface.text ~= toUTF8([cast(dchar)(event.key.keysym.sym)]);
					}
					break;
				case SDL_KEYUP:
	    			
	    			auto surface = getMouseSurface();
					if(surface)
						surface.keyUp(event.key.keysym.sym, event.key.keysym.mod);
					//	surface.keyUp(event.key.keysym.unicode, event.key.keysym.mod);
					
					break;
				// Mouse
				case SDL_MOUSEBUTTONDOWN:
					auto surface = getMouseSurface();
	
					if(surface) 
						surface.mouseDown(event.button.button, Vec2i(mousex, mousey));
	
					break;
				case SDL_MOUSEBUTTONUP:
					auto surface = getMouseSurface();
	
					if(surface)
	 					surface.mouseUp(event.button.button, Vec2i(mousex, mousey));
	
					break;
				case SDL_MOUSEMOTION:					
					mousex = event.motion.x;
					mousey = event.motion.y;
					
					// Doing this before getMouseSurface() fixes the mouse leaving the surface while dragging.
					if(currentSurface) // [below] negative y because opengl y goes from bottom to top
						currentSurface.mouseMove(event.button.button, Vec2i(event.motion.xrel, -event.motion.yrel));
	
					//if the surface that the mouse is in has changed
					auto surface = getMouseSurface();
					if(currentSurface !is surface)
					{	
						if(currentSurface) //Tell it that the mouse left
							currentSurface.mouseOut(surface, event.button.button, Vec2i(mousex,mousey));
						if(surface) //Tell it that the mosue entered
							surface.mouseOver(event.button.button, Vec2i(mousex,mousey));							
						
						currentSurface = surface; //The new current surface
					}
					
					break;
	
				// System
				//case SDL_ACTIVEEVENT:
				//case SDL_VIDEOEXPOSE:
				case SDL_VIDEORESIZE:
					System.resizeWindow(event.resize.w, event.resize.h);
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
	static Surface getMouseSurface(){
		if(Surface.getGrabbedSurface()) 
			return Surface.getGrabbedSurface();
		return System.getSurface().findSurface(cast(float)mousex, cast(float)mousey);
	}
}
