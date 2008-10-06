/**
 * Copyright:  none
 * Authors:    Eric Poggel
 * License:    Public Domain
 *
 * This module is not technically part of the engine, but merely uses it.
 * This is minimal code to launch yage and draw something.
 */

module min.main;

import std.string;
import std.stdio;
import derelict.sdl.sdl;
import yage.all;

import derelict.opengl.gl;
import derelict.opengl.glext;

// program entry point.
int main()
{
	Device.init(800, 600, 32, false, 1);
	
	// Paths
	Resource.addPath("../res/");
	
	// Create and start a Scene
	Scene scene = new Scene();
	scene.play();
	scene.setClearColor(Color("green"));
	// Ship
	auto ship = scene.addChild(new ModelNode());
	ship.setModel("obj/tie2.obj");
	ship.setAngularVelocity(Vec3f(0, 1, 0));

	// Camera
	auto camera = scene.addChild(new CameraNode());
	camera.setPosition(Vec3f(0, 5, 30));	
	
	// Main surface where camera output is rendered.
	auto view = new Surface();
	view.style.backgroundMaterial = camera.getTexture();
	view.style.set("background-color: red; font-family: url('gui/font/Vera.ttf')");	
	Device.setSurface(view);
	
	// Events for main surface.
	bool grabbed = true;
	view.onKeyDown = delegate void (Surface self, int key, int modifier){
		if (key == SDLK_ESCAPE)
			Device.exit(0);	
	};
	view.onMouseDown = delegate void (Surface self, byte buttons, Vec2i coordinates) {
		self.grabMouse(grabbed);
		grabbed = !grabbed;
	};
	
	// Lights
	auto l1 = scene.addChild(new LightNode());
	l1.setPosition(Vec3f(0, 300, -300));
	
	// Rendering / Input Loop
	int fps = 0;
	Timer frame = new Timer();
	while(1)
	{		
		Input.processInput();
		scene.swapTransformRead(); // swap scene buffer so the latest version can be rendered.
		camera.toTexture();
		view.render();
		
		// Print framerate
		fps++;
		if (frame.get()>=0.25f)
		{	view.text = formatString("%.2f fps", fps/frame.get());
			frame.reset();
			fps = 0;			
		}
	}

	return 0;
}
