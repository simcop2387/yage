/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty:   none
 *
 * This module is not part of the engine, but merely uses it.
 * This is minimal code to launch yage and draw something.
 */

module unittests.demo.ui;

import tango.text.convert.Format;
import tango.io.Stdout;
import derelict.sdl.sdl;
import yage.all;

import derelict.opengl.gl;
import derelict.opengl.glext;

class UIDemo : Surface
{
	Surface title;
	
	this()
	{	style.set("top: 40px; left: 40px; width: 400px; height: 260px; padding: 10px; " ~
			"background-color: #000b; border: 1px solid white; " ~
			"font-family: url('gui/font/Vera.ttf'); font-size: 14px; color: white ");
	
		onMouseDown = delegate void(Surface self, byte buttons, Vec2i coordinates){
			self.focus();
		};
		onMouseMove = delegate void(Surface self, byte buttons, Vec2i amount) {
			if(buttons == 1) 
				self.move(cast(Vec2f)amount, true);
		};
		
		title = addChild(new Surface());
		title.text = "Yage UI Demo";
		title.style.set("font: 24px bold Vera.ttf; color: white");
	}
	
}

// program entry point.
int main()
{
	// Init and create window
	System.init(); 
	auto window = Window.getInstance();
	window.setResolution(720, 445, 0, false, 1); // golden ratio
	ResourceManager.addPath(["../res/", "../res/shader", "../res/gui/font"]);

	// Main surface
	auto view = new Surface();	
	view.style.set("background-image: url('space/rocky1.jpg')");
	
	// Events for main surface.
	bool grabbed = true;
	view.onKeyDown = delegate void(Surface self, int key, int modifier){
		if (key == SDLK_ESCAPE)
			System.abort("Yage aborted by esc key press.");
	};
	
	
	auto info = view.addChild(new UIDemo());
	
	
	// Rendering / Input Loop
	int fps = 0;
	Timer frame = new Timer();
	while(!System.isAborted())
	{		
		Input.processAndSendTo(view);
		Render.surface(view, window);
		Render.complete(); // swap buffers
		
		// Print framerate
		fps++;		
		if (frame.tell()>=0.25f)
		{	frame.seek(0);
			fps = 0;
		}
	}
	
	// Free resources that can't be freed by the garbage collector.
	System.deInit();
	return 0;
}
