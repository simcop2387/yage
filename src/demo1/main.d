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
		Scene skybox = new Scene();
		skybox.addChild(new ModelNode("sky/sanctuary.ms3d"));
		setSkybox(skybox);
		setGlobalAmbient(Color("#444444"));
		
		// Ship
		ship = addChild(new Ship());	
		ship.setPosition(Vec3f(0, 50, -950));
		ship.getCameraSpot().setPosition(Vec3f(0, 4000, 10000));
		
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
		light.setDiffuse(Color(1, .85, .7));
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
	// Init (resolution, depth, fullscreen, aa-samples)
	System.init(720, 445, 32, false, 1); // golden ratio
	//System.init(1024, 768, 32, true);
	//System.init(1440, 900, 32, true);
	
	// Paths
	ResourceManager.addPath("../res/");
	ResourceManager.addPath("../res/shader");
	ResourceManager.addPath("../res/gui/font");

	// Create and start a Scene
	Log.write("Starting update loop.");
	auto scene = new DemoScene();
	scene.play(); // update 60 times per second
	
	// Main surface where camera output is rendered.
	Surface view = new Surface();
	view.style.backgroundImage = scene.camera.getTexture();
	view.style.set("bottom: 0; right: 0");	
	System.setSurface(view);
	
	// Events for main surface.
	view.onKeyDown = delegate void (Surface self, int key, int modifier){
		if (key == SDLK_ESCAPE)
			System.abort("Yage aborted by esc key press.");
		
		// Trigger the garbage collector
		if(key == SDLK_c) {
			GC.collect();
			Stdout("garbage collected").newline;
		}
		
		// Reset the scene
		if (key == SDLK_r)
		{	scene.pause();
			//scene.finalize();
			scene = new DemoScene();
			scene.camera.setListener();
			view.style.backgroundImage = scene.camera.getTexture();
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
	view.onResize = delegate void (Surface self, Vec2f amount){
		scene.camera.setResolution(cast(int)self.width, cast(int)self.height);
	};
	
		
	// Make a draggable window to show some useful info.
	auto window = view.addChild(new Surface());
	window.style.set("top: 5px; right: 5px; width: 160px; height: 80px; color: black; padding: 3px; " ~
		"border-width: 5px; border-image: url('gui/skin/clear2.png'); " ~
		"font-family: url('Vera.ttf'); font-size: 16px");

	//window.style.backgroundImage = scene.camera.getTexture();
	window.onMouseDown = (Surface self, byte buttons, Vec2i coordinates){
		self.raise();
		self.focus();
	};
	window.onMouseMove = (Surface self, byte buttons, Vec2i amount) {
		if(buttons == 1) 
			self.move(cast(Vec2f)amount, true);
	};
	window.onMouseUp = (Surface self, byte buttons, Vec2i coordinates) {
		self.blur();
	};
	window.onMouseOver = (Surface self, byte buttons, Vec2i coordinates) {
		self.style.set("border-image: url('gui/skin/clear3.png')");
	};
	window.onMouseOut = (Surface self, byte buttons, Vec2i coordinates) {
		self.style.set("border-image: url('gui/skin/clear2.png')");
	};

	int fps = 0;
	Timer frame = new Timer();
	Timer delta = new Timer();
	Log.write("Starting rendering loop.");
	GC.collect();

	
	// Rendering loop
	while(!System.isAborted())
	{
		float dtime = delta.get();
		delta.reset();

		Input.processInput();
		scene.camera.toTexture();
		view.render();
		
		// Print framerate
		fps++;
		if (frame.get()>=1f)
		{	SDL_WM_SetCaption("Yage Demo\0", null);
			window.text = Format.convert(
				`{} <b>fps</span><br/>`
				`{} <b>objects</b><br/>`
				`{} <b>polygons</b><br/>`
				`{} <b>vertices</b>`,
				fps/frame.get(), scene.camera.getNodeCount(), scene.camera.getPolyCount(), scene.camera.getVertexCount());
			frame.reset();
			fps = 0;
		}
		
		// Free up a little cpu if over 60 fps.
		if (dtime < 1/60.0)
			Thread.sleep(1/60.0f-dtime);
		scene.swapTransformRead();
	}
	
	System.deInit();
	return 0;
}