/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel, Joe Pusdesris (deformative0@gmail.com)
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.input;

public import derelict.sdl2.sdl;
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
	/// This is a mirror of SDLMod (SDL's modifier key struct)
	enum ModifierKey
	{	NONE  = 0x0000, /// Allowed values.
		LSHIFT= 0x0001, /// ditto
		RSHIFT= 0x0002, /// ditto
		LCTRL = 0x0040, /// ditto
		RCTRL = 0x0080, /// ditto
		LALT  = 0x0100, /// ditto
		RALT  = 0x0200, /// ditto
		LMETA = 0x0400, /// ditto
		RMETA = 0x0800, /// ditto
		NUM   = 0x1000, /// ditto
		CAPS  = 0x2000, /// ditto
		MODE  = 0x4000, /// ditto
		RESERVED = 0x8000, /// ditto
		CTRL  = LCTRL | RCTRL, /// ditto
		SHIFT = LSHIFT | RSHIFT, /// ditto
		ALT   = LALT | RALT, /// ditto
		META  = LMETA | RMETA /// ditto
	};	
	
	///
	enum MouseButton
	{	LEFT=1, /// Allowed values.
		CENTER, /// ditto
		RIGHT, /// ditto
		WHEEL_UP, /// ditto
		WHEEL_DOWN, /// ditto
		FOUR, /// ditto
		FIVE, /// ditto
		SIX, /// ditto
		SEVEN, /// ditto
		EIGHT /// ditto
	}
	
	static int KEY_DELAY = 500; /// milliseconds before repeating a call to keyPress after holding a key down.
	static int KEY_REPEAT = 30; /// milliseconds before subsequent calls to keyPress after KEY_DELAY occurs.
	
	/// Position of the mouse and state of each button.
	struct Mouse
	{	Vec2i position; ///
		bool left; /// ditto
		bool center; /// ditto
		bool right; /// ditto
		bool four; /// ditto
		bool five; /// ditto
		bool six; /// ditto
		bool seven; /// ditto
		bool eight; /// ditto

		///
		char[] toString()
		{	return position.toString() ~ (left?"L":"") ~ (center?"C":"") ~ (right?"R":"") ~ (four?"4":"") ~ 
				(five?"5":"") ~ (six?"6":"") ~ (seven?"7":"") ~ (eight?"8":"");
		}
		
		// used internally
		private void fromMouseButton(ushort mouseButton, bool state)
		{	switch (mouseButton)
			{	case MouseButton.LEFT: left=state; break;
				case MouseButton.CENTER: center=state; break;
				case MouseButton.RIGHT: right=state; break;
				case MouseButton.FOUR: four=state; break;
				case MouseButton.FIVE: five=state; break;
				case MouseButton.SIX: six=state; break;
				case MouseButton.SEVEN: seven=state; break;
				case MouseButton.EIGHT: eight=state; break;
				default: break;
		}	}
		
	}
	static Mouse mouse; /// Stores the current state of the mouse.
	
	protected static Surface currentSurface;	// Surface that the mouse is currently over

	protected static SDL_Keysym lastKeyDown; // Used for manual key-repeat.
	protected static uint lastKeyDownTime = uint.max;
	
	/** 
	 * Process input, handle window resize and close events, and send the remaining events to surface,
	 * calling the surfaces's keyDown, keyUp, mouseDown, MouseUp, and mouseOver functions as appropriate. */
	static void processAndSendTo(Surface surface)
	{
		assert(surface);
		if (!currentSurface)
			currentSurface = surface;
		
		SDL_EnableUNICODE(1); // TODO: Move this
		auto focus = getFocusSurface(surface);
				
		SDL_Event event;
		while(SDL_PollEvent(&event))
		{	
			switch(event.type)
			{
				// Keyboard
				case SDL_KEYDOWN:
					
					// keysym.sym gets all keys on the keyboard, including separate keys for numpad, keysym.unicde should be reserved for text.
					if (focus.onKeyDown)
						focus.onKeyDown(event.key.keysym.sym, event.key.keysym.mod);
					else
						focus.keyDown(event.key.keysym.sym, event.key.keysym.mod);
				
					// Kepress will be called with the key repeat settings.
					focus.keyPress(event.key.keysym.sym, event.key.keysym.mod, event.key.keysym.unicode);
					lastKeyDown = event.key.keysym;
					lastKeyDownTime = clock()*1000 / CLOCKS_PER_SEC;
					  
					break;
				case SDL_KEYUP:
					if (focus.onKeyUp)
						focus.onKeyUp(event.key.keysym.sym, event.key.keysym.mod);
					else
						focus.keyUp(event.key.keysym.sym, event.key.keysym.mod);
					if (event.key.keysym.sym==lastKeyDown.sym) // if the same key we're repeating
						lastKeyDownTime = uint.max; // stop repeating
					break;
				
				// Mouse
				case SDL_MOUSEBUTTONDOWN:
					mouse.fromMouseButton(event.button.button, true); // set					
					auto over = getMouseSurface(surface);
					if(over) 
					{	Vec2f localMouse = currentSurface.globalToLocal(mouse.position.vec2f);
						if (over.onMouseDown)
							over.onMouseDown(cast(MouseButton)event.button.button, localMouse);
						else
							over.mouseDown(cast(MouseButton)event.button.button, localMouse);
					}
	
					break;
				case SDL_MOUSEBUTTONUP:
					mouse.fromMouseButton(event.button.button, false); // clear
					auto over = getMouseSurface(surface);
					if(over)
					{	Vec2f localMouse = currentSurface.globalToLocal(mouse.position.vec2f);
						if (over.onMouseUp)
							over.onMouseUp(cast(MouseButton)event.button.button, localMouse);
						else
							over.mouseUp(cast(MouseButton)event.button.button, localMouse);
					}
	
					break;
				case SDL_MOUSEMOTION:			
					mouse.position.x = event.motion.x;
					mouse.position.y = event.motion.y;
					
					// Doing this before getMouseSurface() fixes the mouse leaving the surface while dragging.
					if(currentSurface)
					{	if (currentSurface !is Surface.getGrabbedSurface())
							currentSurface.mouse = currentSurface.globalToLocal(mouse.position.vec2f);
						
						if (currentSurface.onMouseMove)
							currentSurface.onMouseMove(Vec2f(event.motion.xrel, event.motion.yrel));
						else
							currentSurface.mouseMove(Vec2f(event.motion.xrel, event.motion.yrel));
					}
	
					// If the surface that the mouse is in has changed
					auto over = getMouseSurface(surface);
					if(currentSurface !is over)
					{	
						// TODO: Sometimes mouseOver and mouseOut need to be called for more than one Surface when they're nested!
						if(currentSurface && (!over || !over.isAncestor(currentSurface))) //Tell it that the mouse left
						{	if (currentSurface.onMouseOut)
								currentSurface.onMouseOut(over);
							else
								currentSurface.mouseOut(over);
						}
						if (over) // Tell it that the mouse entered
						{
							if (over.onMouseOver)
								over.onMouseOver();
							else
								over.mouseOver();							
						}
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
					if (Window.getInstance().onExit)
						Window.getInstance().onExit();
					break;
				default:
					break;
			}
		}
		
		// Key repeat
		if (focus)
		{	uint now = clock()*1000/CLOCKS_PER_SEC; // time in milliseconds
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
		return surface.findSurface(mouse.position.vec2f);
	}
	
	/**
	 * Get the surface that currently has focus, or the given surface if no surface has focus */
	private static Surface getFocusSurface(Surface surface) {
		if(Surface.getFocusSurface()) 
			return Surface.getFocusSurface();
		return surface;
	}
}