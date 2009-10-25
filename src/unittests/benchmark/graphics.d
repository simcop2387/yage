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
import yage.all;

// program entry point.
void main()
{
	// Init and create window
	//System.init(); 
	//auto window = Window.getInstance();
	//window.setResolution(200, 140); // req'd to preceed OpenGL operations.
	
	
	Timer a = new Timer();
	for (int i=0; i<1000; i++)
	{	Graphics.pushState();
		Graphics.popState();
	}
	Log.trace(a.toString());
	
	//a = new Timer();
	//for (int i=0; i<1000; i++)
	//	Graphics.popState();
	//Log2.trace(a.toString());
	
	a = new Timer();
	auto o = new OpenGL();
	for (int i=0; i<1000; i++)
	{	//OpenGL.getContext().applyState();
		//assert(o);
		Graphics.applyState();
	}
	Log.trace(a.toString());
	

}
