/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel, Joe Pusdesris (deformative0@gmail.com)
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.system.input;

public import derelict.sdl.sdl;

import std.stdio;
import yage.core.vector;
import yage.system.device;
import yage.gui.surface;


/// A class to handle keyboard, mouse, and eventually joystick input.
class Input
{

	static bool[1024] keyup;		/// The key was down and has been released.
	static bool[1024] keydown;		/// The key is currently being held down.
//	static uint keymod;				/// Modifier key (currently unused)

	static int mousex, mousey;		/// The current pixel location of the mouse cursor; (0, 0) is top left.
	
	/// A structure to track various state variables associated with each mouse button.
	struct Buttons
	{	bool down;					/// True if the button is currently down.
		bool up;					/// True if the button was pressed and is now up.
		int xdown;					/// The x location of the mouse when this button was last pressed.
		int ydown;					/// The y location of the mouse when this button was last pressed.
		int xup;					/// The x location of the mouse when this button was last released.
		int yup;					/// The y location of the mouse when this button was last released.
	}
	static Buttons[8] button;		/// An array to track the state of the mouse buttons
	//static wchar[] stream;		/// Recently typed text (unicode)
	static bool grabbed=false;		/// The window grabs the mouse.

	static Surface surfaceLock;
	static Surface currentSurface;

	/** This function fills the above fields with the current intput data.
	 *  See the descriptions of each field for more details.  If this function is not called,
	 *  then input can be handled manually.  See http://www.libsdl.org/cgi/docwiki.cgi/SDL_5fEvent
	 *  for details on manual SDL input processing. */
	static void processInput()
	{
		//SDL_EnableKeyRepeat(100, 100);	// why doesn't this work? Need to try again since I have the latest version of SDL

		SDL_Event event;
		while(SDL_PollEvent(&event))
		{
			processEvent(event);
		}
	}
	
	static void processEvent(SDL_Event event){
		switch(event.type){
			// Standard keyboard
			case SDL_KEYDOWN:
				keydown[event.key.keysym.sym] = true;
				keyup[event.key.keysym.sym] = false;

				auto surface = getSurface();
				
				if(surface !is null)
 					surface.keydown(event.key.keysym.sym);
				
				break;
			case SDL_KEYUP:
    				keyup[event.key.keysym.sym] = true;
    				keydown[event.key.keysym.sym] = false;
					
				auto surface = getSurface();

				if(surface !is null)
					surface.keyup(event.key.keysym.sym);
				
				break;
				// Mouse
			case SDL_MOUSEBUTTONDOWN:
				button[event.button.button].down = true;
				button[event.button.button].up = false;
				button[event.button.button].xdown = mousex;
				button[event.button.button].ydown = mousey;

				auto surface = getSurface();

				if(surface !is null) 
					surface.mousedown(event.button.button, Vec2i(mousex,mousey));

				break;
			case SDL_MOUSEBUTTONUP:
				button[event.button.button].down = false;
				button[event.button.button].up = true;
				button[event.button.button].xup = mousex;
				button[event.button.button].yup = mousey;

				auto surface = getSurface();

				if(surface !is null)
 					surface.mouseup(event.button.button, Vec2i(mousex,mousey));

				break;
			case SDL_MOUSEMOTION:
					
				if(grabbed){
					if(event.motion.x != mousex || event.motion.y != mousey)
						SDL_WarpMouse(mousex, mousey);
					else break;
					
				}
				else{
					mousex = event.motion.x;
					mousey = event.motion.y;
				}
				
				auto surface = getSurface();

				//if the surface that the mouse is in has changed
				if(currentSurface !is surface){
					//If the old surface is not device
					if(currentSurface !is null)
						//Tell it that the mouse left
						currentSurface.mouseleave(surface, event.button.button, Vec2i(mousex,mousey));
					//If the new surface is not device
					if(surface !is null)
						//Tell it that the mosue entered
						surface.mouseenter(event.button.button, Vec2i(mousex,mousey));
						
						//The new current surface
						currentSurface = surface;
				}
				//Needs to be changed so that check is run once
				if(surface !is null)
					surface.mousemove(event.button.button, Vec2i(event.motion.xrel, event.motion.yrel));
					
				break;

				// System
				//case SDL_ACTIVEEVENT:
				//case SDL_VIDEOEXPOSE:
			case SDL_VIDEORESIZE:
				Device.resizeWindow(event.resize.w, event.resize.h);
				break;
			case SDL_QUIT:
				Device.exit(0);
				break;
			default:
				break;
		}
	}

	static bool getGrabMouse()
	{	return grabbed;
	}
	
	static Surface getSurface(){
		if(surfaceLock) return surfaceLock;
		return findSurface(mousex, mousey);
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
