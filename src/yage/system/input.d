/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
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
	private static bool resetmouse = true;	// Used to disable large mouse jumps

	static bool[1024] keyup;		/// The key was down and has been released.
	static bool[1024] keydown;		/// The key is currently being held down.
//	static uint keymod;				/// Modifier key (currently unused)

	static int mousex, mousey;		/// The current pixel location of the mouse cursor; (0, 0) is top left.
	static int mousedx, mousedy;	/// The number of pixels the mouse has moved since the last time input was queried.
	
	//I do not know if this does the same as moused, I was too lazy to mod it for my needs.
	static int xdiff, ydiff;
	
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
	static bool grabbed=0;			/// The window grabs the mouse.
	static bool exit = false;		/// A termination request has been received.

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
			switch(event.type)
			{
				// Standard keyboard
				case SDL_KEYDOWN:
					keydown[event.key.keysym.sym] = true;
					keyup[event.key.keysym.sym] = false;

					// Record text input
					//if(event.key.keysym.unicode)
					//	stream ~= event.key.keysym.unicode & 0x7F;
					//printf("key '%s' down\n", SDL_GetKeyName(event.key.keysym.sym));
					break;
				case SDL_KEYUP:
    				keyup[event.key.keysym.sym] = true;
    				keydown[event.key.keysym.sym] = false;
					break;

				// Mouse
				case SDL_MOUSEBUTTONDOWN:
					button[event.button.button].down = true;
					button[event.button.button].up = false;
					button[event.button.button].xdown = mousex;
					button[event.button.button].ydown = mousey;

					auto surface = getSurface();

					if(surface !is null) surface.mousedown(event.button.button, Vec2i(mousex,mousey));

					break;
				case SDL_MOUSEBUTTONUP:
					button[event.button.button].down = false;
					button[event.button.button].up = true;
					button[event.button.button].xup = mousex;
					button[event.button.button].yup = mousey;

					auto surface = getSurface();

					if(surface !is null) surface.mouseup(event.button.button, Vec2i(mousex,mousey));

					break;
				case SDL_MOUSEMOTION:
					if (resetmouse)
					{	resetmouse = false;
						event.motion.xrel = event.motion.yrel = 0;
					}
					mousedx += event.motion.xrel;	// these seem to behave differently on linux
					mousedy += event.motion.yrel;	// than on win32.  Testing should be done.
					
					xdiff = mousex - event.motion.x;
					ydiff = mousey - event.motion.y;
					
					mousex = event.motion.x;
					mousey = event.motion.y;
					
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
						surface.mousemove(event.button.button, Vec2i(xdiff,ydiff));
					
					break;

				// System
				//case SDL_ACTIVEEVENT:
				//case SDL_VIDEOEXPOSE:
				case SDL_VIDEORESIZE:
					Device.resizeWindow(event.resize.w, event.resize.h);
					break;
				case SDL_QUIT:
					exit = true;
					break;
				default:
					break;
			}
		}
	}

	/// Get the number of pixels the mouse has moved since the last time this function was called.
	static Vec2f getMouseDelta()
	{	Vec2f result = Vec2f(mousedx, mousedy);
		mousedx = mousedy = 0;
		return result;
	}

	/** If enabled, the mousecursor will be hidden and grabbed by the application.
	 *  This also allows for mouse position changes to be registered in a relative fashion,
	 *  i.e. even when the mouse is at the edge of the screen.  This is ideal for attaching
	 *  the mouse to the look direction of a first or third-person camera. */
	static void setGrabMouse(bool _grabbed)
	{	if (_grabbed)
		{	SDL_WM_GrabInput(SDL_GRAB_ON);
			SDL_ShowCursor(false);
			resetmouse = true;
		}else
		{	SDL_WM_GrabInput(SDL_GRAB_OFF);
			SDL_ShowCursor(true);
		}
		grabbed = _grabbed;
	}

	static bool getGrabMouse()
	{	return grabbed;
	}
	
	static void setSurfaceLock(Surface lock){
		surfaceLock = lock;
	}
	static void unlockSurface(){
		surfaceLock = null;
	}
	
	static Surface getSurface(){
		if(surfaceLock) return surfaceLock;
		return findSurface(mousex, mousey);
	}
}
