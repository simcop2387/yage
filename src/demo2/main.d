/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty:   none
 *
 * This module is not part of the engine, but merely uses it.
 * This is minimal code to launch yage and draw something.
 */

module demo2.main;

import tango.math.Math;
import tango.io.device.File;
import derelict.sdl.sdl;
import yage.all;

import derelict.opengl.gl;
import derelict.opengl.glext;

bool dragging;
bool running = true;

// program entry point.
int main()
{
	// Init and create window
	System.init(); 
	auto window = Window.getInstance();
	window.setCaption("Yage Demo 2");
	window.setResolution(720, 445, 0, false, 1); // golden ratio
	window.onExit = delegate void() {
		Log.info("Yage aborted by window close.");
		running = false;
	};
	ResourceManager.addPath(["../res/", "../res/shader", "../res/gui/font"]);

	// Create and start a Scene
	Scene scene = new Scene();
	scene.play();
	scene.backgroundColor = "gray";
	
	// Ship	
	auto ship = scene.addChild(new ModelNode());
	ship.setModel("space/fighter.dae");
	ship.setAngularVelocity(Vec3f(0, 1, 0));
	ship.setScale(Vec3f(1));

	// Camera
	auto camera = scene.addChild(new CameraNode());
	camera.setPosition(Vec3f(0, 5, 30));
	
	// Main surface
	auto view = new Surface("width: 100%; height: 100%");
	
	// Events for main surface.
	view.onKeyDown = delegate void (int key, int modifier){
		if (key == SDLK_ESCAPE)
		{	running = false;
			Log.info("Yage aborted by esc key press.");
		}
	};
	
	// Lights
	auto l1 = scene.addChild(new LightNode());
	l1.setPosition(Vec3f(0, 200, -30));	

	// A window with text in it
	auto info = new Surface(view);
	info.style.set("top: 40px; left: 40px; width: 500px; height: 260px; padding: 3px; color: #ff8800; " ~
		"border-width: 12px; border-image: url('gui/skin/panel1.png'); " ~
		"font-family: url('Vera.ttf'); text-align: center; opacity: .8; overflow: hidden");
	
	bool dragging;
	info.onMouseDown = curry(delegate void (Input.MouseButton button, Vec2f coordinates, Surface self) {
		if (button == Input.MouseButton.LEFT)
			dragging = true;
	}, info);
	info.onMouseMove = curry(delegate void (Vec2f amount, Surface self) {		
		if (dragging)
			self.move(amount, true);
	}, info);
	info.onMouseUp = curry(delegate void (Input.MouseButton button, Vec2f coordinates, Surface self) {
		if (button == Input.MouseButton.LEFT)
			dragging = false;
	}, info);
	info.onMouseOver = curry(delegate void (Surface self) {
		self.style.set("border-image: url('gui/skin/panel2.png')");
	}, info);
	info.onMouseOut = curry(delegate void (Surface next, Surface self) {
		self.style.set("border-image: url('gui/skin/panel1.png')");
	}, info);
	info.editable = view.editable = true;
	/*
	// Test overflow clipping
	auto clip = new Surface(info);
	clip.style.set("width: 60px; height: 60px; background-color: black; top: -30px; left: -30px; overflow: hidden");
	
	auto clip2 = new Surface(clip);
	clip2.style.set("width: 30px; height: 30px; background-color: blue; top: 15px; left: 45px");
	
	auto clip3 = new Surface(info);
	clip3.style.set("width: 60px; height: 60px; background-color: orange; top: -30px; right: -30px");
	*/
	
	
	// Rendering / Input Loop
	int fps = 0;
	Timer total = new Timer(true);
	Timer frame = new Timer(true);
	while(running && !System.getThreadExceptions())
	{	
		Input.processAndSendTo(view);
		auto stats = Render.scene(camera, window);
		Render.surface(view, window);
		Render.complete(); // swap buffers
		/+
		// Rotate the info box
		float amount = total.tell();
		info.style.transform = Matrix();
		info.style.transform = info.style.transform.move(Vec3f(-300, -20, 0));
		info.style.transform *= Matrix().rotate(Vec3f(0, /*sin(amount/2)/2*/0, sin(amount/2)/5));
		info.style.transform = info.style.transform.move(Vec3f(300, 20, 0));
		+/
		
		fps++;
		if (frame.tell()>=.25f && !(Surface.getFocusSurface() is info))
		{	info.setHtml(`Click <s>here</s> <span style="color: green; text-decoration: overline; font-size:40px">`~
			`<u>To</u><s> type and</s> <u style="font-size: 18px">edit</u></span> this `~
			`<span style="text-decoration: overline">block</span> of <b>text. <i style="font-style: normal">No,</i> really</b> it `~
			`works,<br/><br/>Another line of text.<br/><br/><br/> `~format(` %s fps<br/>`, fps/frame.tell()));
			
			frame.seek(0);
			fps = 0;
		}
	}
	
	// Free resources that can't be freed by the garbage collector.
	System.deInit();
	return 0;
}