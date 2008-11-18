/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel, Joe Pusdesris (deformative0@gmail.com)
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.system.input;

public import derelict.sdl.sdl;

import std.stdio;
import std.utf;
import yage.core.vector;
import yage.system.device;
import yage.gui.surface;


/// A class to handle keyboard, mouse, and eventually joystick input.
class Input
{

	static bool[1024] keyUp;		/// The key was down and has been released TODO: replace with something else.
	static bool[1024] keyDown;		/// The key is currently being held down.
	static int mousex, mousey;		/// The current pixel location of the mouse cursor; (0, 0) is top left.

	static bool grabbed=false;		/// The window grabs the mouse.
	static bool previously_grabbed = false;

	static Surface surfaceLock;		// Surface that is grabbing all input.
	static Surface currentSurface;
	
	bool shift;
	bool ctrl;
	bool alt;
	
	// With multiple keydowns, SDL sends keydowns only when they first occur.
	// This keeps track of all keys that are being held down.
	//protected static ushort key_down[ushort];

	/** This function fills the above fields with the current intput data.
	 *  See the descriptions of each field for more details.  If this function is not called,
	 *  then input can be handled manually.  See http://www.libsdl.org/cgi/docwiki.cgi/SDL_5fEvent
	 *  for details on manual SDL input processing. */
	static void processInput()
	{
		// Disable key repeating, we'll handle that manually.
		//SDL_EnableKeyRepeat(0, SDL_DEFAULT_REPEAT_INTERVAL);	// why doesn't this work? Need to try again since I have the latest version of SDL
		SDL_EnableUNICODE(1);
				
		SDL_Event event;
		while(SDL_PollEvent(&event))
			processEvent(event);		
	}
	
	static void processEvent(SDL_Event event){
		switch(event.type)
		{
			// Standard keyboard
			case SDL_KEYDOWN:
				keyDown[event.key.keysym.sym] = true;
				keyUp[event.key.keysym.sym] = false;
				
				auto surface = getSurface();
				if(surface)
				{	surface.keyDown(event.key.keysym.sym, event.key.keysym.mod);		
					//surface.text ~= toUTF8([cast(dchar)(event.key.keysym.sym)]);
				}
				break;
			case SDL_KEYUP:
    			keyUp[event.key.keysym.sym] = true;
    			keyDown[event.key.keysym.sym] = false;
    			
    			auto surface = getSurface();
				if(surface)
					surface.keyUp(event.key.keysym.sym, event.key.keysym.mod);
				
				break;
				// Mouse
			case SDL_MOUSEBUTTONDOWN:
				auto surface = getSurface();

				if(surface !is null) 
					surface.mouseDown(event.button.button, Vec2i(mousex,mousey));

				break;
			case SDL_MOUSEBUTTONUP:
				auto surface = getSurface();

				if(surface !is null)
 					surface.mouseUp(event.button.button, Vec2i(mousex,mousey));

				break;
			case SDL_MOUSEMOTION:
				auto surface = getSurface();
					
				if(grabbed) {				
					
					if(event.motion.x != mousex || event.motion.y != mousey)
					{	mousex = cast(ushort)(surface.width()/2);
						mousey = cast(ushort)(surface.height()/2);						
						SDL_WarpMouse(mousex, mousey); // warp back to where it was before.
					}
					else 
						break;								
				}
				else{
					mousex = event.motion.x;
					mousey = event.motion.y;				
				}

				//if the surface that the mouse is in has changed
				if(currentSurface !is surface)
				{	
					if(currentSurface) //Tell it that the mouse left
						currentSurface.mouseOut(surface, event.button.button, Vec2i(mousex,mousey));
					if(surface) //Tell it that the mosue entered
						surface.mouseOver(event.button.button, Vec2i(mousex,mousey));
						
					//The new current surface
					currentSurface = surface;
				}
				if(surface && previously_grabbed==grabbed)
					surface.mouseMove(event.button.button, Vec2i(event.motion.xrel, event.motion.yrel));
				previously_grabbed = grabbed;				
				
				break;

				// System
				//case SDL_ACTIVEEVENT:
				//case SDL_VIDEOEXPOSE:
			case SDL_VIDEORESIZE:
				Device.resizeWindow(event.resize.w, event.resize.h);
				break;
			case SDL_QUIT:
				Device.running = false; // not the most organized way.
				break;
			default:
				break;
		}
	}

	static bool getGrabMouse()
	{	return grabbed;
	}
	
	static Surface getSurface(){
		if(surfaceLock) 
			return surfaceLock;
		return Device.getSurface().findSurface(cast(float)mousex, cast(float)mousey);
	}
	//Releases the locked surface, now the appropriate surface will recieve events rather than the locked
	void unlock(){
		Input.surfaceLock = null;
	}
	
	void ungrab(){
		Input.unlock();
		SDL_WM_GrabInput(SDL_GRAB_OFF);
		SDL_ShowCursor(true);
		grabbed = false;
	}
}
