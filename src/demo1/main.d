/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty:   none
 *
 * This module is not part of the engine, but merely uses it.
 * This is a demo to show off some of the cool features of Yage 
 * and also acts a general, incomplete test for regressions.
 */

module demo1.main;

import tango.core.Memory;
import tango.core.Thread;
import tango.io.Stdout;
import tango.util.Convert;
import tango.text.convert.Format;
import tango.text.xml.Document;
import tango.text.Regex;

import derelict.sdl.sdl;

import yage.all;
import demo1.ship;
import demo1.misc;

import derelict.opengl.gl;
import yage.system.graphics.all;
import std.stdio;

class DemoScene : Scene
{
	Scene skybox;
	Ship ship;
	CameraNode camera;
	SoundNode music;
	
	LightNode light;
	SpriteNode star;
	ModelNode planet;
	
	// Create the scene and all elements in it
	this()
	{
		super();
		
		// Skybox
		skyBox = new Scene();
		skyBox.addChild(new ModelNode("sky/sanctuary.ms3d"));
		backgroundColor = "#444444";
		
		// Ship
		ship = addChild(new Ship());	
		ship.setPosition(Vec3f(1200, 150, 0));
		ship.getCameraSpot().setPosition(Vec3f(1000, 4000, 10000));

		// Camera
		camera = ship.getCameraSpot().addChild(new CameraNode());
		ship.getCameraSpot().addChild(camera);
		camera.setView(2, 100000, 60, 0, 1);	// wide angle view
		
		// Music
		music = camera.addChild(new SoundNode("music/celery - pages.ogg"));
		music.setLooping(true);
		//music.play();

		// Lights
		light = scene.addChild(new LightNode());
		light.diffuse = "#FFD9B3";
		light.setLightRadius(7000);
		light.setPosition(Vec3f(0, 0, -6000));

		// Star
		star = light.addChild(new SpriteNode());
		star.setMaterial("space/star.xml");
		star.setSize(Vec3f(2500));

		// Planet
		planet = scene.addChild(new ModelNode("space/planet.ms3d"));
		planet.setSize(Vec3f(60));
		planet.setAngularVelocity(Vec3f(0, -0.01, 0));
		
		// Asteroids
		asteroidBelt(1200, 1400, planet);
	}
	
	override void update(float delta)
	{	super.update(delta);
		ship.getSpring().update(1/60.0f);
	}
}

// Current program entry point.  This may change in the future.
int main()
{		
	// Init and create window
	System.init(); 
	auto window = Window.getInstance();
	window.setResolution(720, 445, 0, false, 1); // golden ratio
	ResourceManager.addPath(["../res/", "../res/shader", "../res/gui/font"]);

	// Create and start a Scene
	Log.info("Starting update loop.");
	auto scene = new DemoScene();
	scene.play(); // update 60 times per second
	
	// Main surface where camera output is rendered.
	Surface view = new Surface();
	view.style.set("width: 100%; height: 100%");
	
	// Events for main surface.
	view.onKeyDown = delegate void (Surface self, int key, int modifier){
		if (key == SDLK_ESCAPE)
			System.abort("Yage aborted by esc key press.");
		
		// Trigger the garbage collector
		if(key == SDLK_c) {
			GC.collect();
			Log.info("Garbage collected");
		}
		if (key == SDLK_f)
			window.setResolution(640, 480, 0, false, 1); // TODO: fix this

		
		// Reset the scene
		if (key == SDLK_r)
		{	scene.pause();
			scene = new DemoScene();
			scene.camera.setListener();
			scene.play();
		}
		
		scene.ship.keyDown(key);
	};
	
	view.onKeyUp = delegate void (Surface self, int key, int modifier){
		scene.ship.keyUp(key);
	};
	
	view.onMouseDown = delegate void (Surface self, byte buttons, Vec2i coordinates){
		scene.ship.acceptInput = !scene.ship.acceptInput;
		if (scene.ship.acceptInput)
			self.grabMouse();
		else
			self.releaseMouse();
	};
	view.onMouseMove = delegate void (Surface self, byte buttons, Vec2i rel){
		if(scene.ship.acceptInput)
			scene.ship.input.mouseDelta += rel;
	};
		
	// Make a draggable window to show some useful info.
	auto info = view.addChild(new Surface());
	info.style.set("top: 5px; right: 5px; width: 130px; height: 70px; color: black; padding: 3px; " ~
		"border-width: 5px; border-image: url('gui/skin/clear2.png'); " ~
		"font-family: url('Vera.ttf'); font-size: 14px");

	//window.style.backgroundImage = scene.camera.getTexture();
	info.onMouseDown = delegate void(Surface self, byte buttons, Vec2i coordinates) {
		self.raise();
		self.focus();
	};
	info.onMouseMove = delegate void(Surface self, byte buttons, Vec2i amount) {
		if(buttons == 1) 
			self.move(cast(Vec2f)amount, true);
	};
	info.onMouseUp = delegate void(Surface self, byte buttons, Vec2i coordinates) {
		self.blur();
	};
	info.onMouseOver = delegate void(Surface self, byte buttons, Vec2i coordinates) {
		self.style.set("border-image: url('gui/skin/clear3.png')");
	};
	info.onMouseOut = delegate void(Surface self, byte buttons, Vec2i coordinates) {
		self.style.set("border-image: url('gui/skin/clear2.png')");
	};

	int fps = 0;
	Timer frame = new Timer();
	Timer delta = new Timer();
	Log.info("Starting rendering loop.");
	GC.collect();
	
	// Rendering loop
	while(!System.isAborted())
	{
		float dtime = delta.tell();
		delta.seek(0);

		Input.processAndSendTo(view);
		auto stats = Render.scene(scene.camera, window);
		Render.surface(view, window);
		Render.complete(); // swap buffers
		
		// Print framerate
		fps++;
		if (frame.tell()>=1f)
		{	float framerate = fps/frame.tell();
			window.setCaption(Format.convert("Yage Demo | {} fps\0", framerate));
			info.text = Format.convert(
				`{} <b>fps</span><br/>`
				`{} <b>objects</b><br/>`
				`{} <b>polygons</b><br/>`
				`{} <b>vertices</b>`,
				framerate, stats.nodeCount, stats.triangleCount, stats.vertexCount);
			frame.seek(0);
			fps = 0;
		}
		
		// Free up a little cpu if over 60 fps.
		//if (dtime < 1/60.0)
		//	Thread.sleep(1/60.0f-dtime);
	}
	
	System.deInit();
	return 0;
}