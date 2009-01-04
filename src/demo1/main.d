/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty:   none
 *
 * This module is not part of the engine, but merely uses it.
 * This is a demo to show off some of the cool features of Yage 
 * and also acts a general, incomplete test for regressions.
 */

module demo2.main;

import std.c.time;
import std.string;
import std.stdio;
import std.gc;

import derelict.opengl.gl;
import derelict.opengl.glext;
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
		ship.getCameraSpot().setPosition(Vec3f(0, 1000, 3000));
		
		// Camera
		camera = ship.getCameraSpot().addChild(new CameraNode());
		ship.getCameraSpot().addChild(camera);
		camera.setView(2, 100000, 60, 0, 1);	// wide angle view
		
		// Music
		music = camera.addChild(new SoundNode("music/celery - pages.ogg"));
		music.setLooping(true);
		music.play();

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
	Device.init(800, 600, 32, false, 1);
	//Device.init(1024, 768, 32, true);
	//Device.init(1440, 900, 32, true);
	
	// Paths
	ResourceManager.addPath("../res/");
	ResourceManager.addPath("../res/shader");

	// Create and start a Scene
	Log.write("Starting update loop.");
	auto scene = new DemoScene();
	scene.play(); // update 60 times per second
	
	// Main surface where camera output is rendered.
	Surface view = new Surface();
	view.style.backgroundMaterial = scene.camera.getTexture();
	view.style.set("bottom: 0; right: 0");	
	Device.setSurface(view);
	
	// Make a draggable window to show some useful info.
	auto window = view.addChild(new Surface());
	window.style.set("top: 0; right: 0; width: 150px; height: 80px; background-position: 5px 5px; color: black; " ~ 
		"background-repeat: nineslice; background-material: url('gui/skin/clear2.png'); " ~
		"font-family: url('gui/font/Vera.ttf'); font-size: 11px");
	window.onMouseDown = (Surface self, byte buttons, Vec2i coordinates){
		self.raise();
		self.focus();
	};
	window.onMouseMove = (Surface self, byte buttons, Vec2i diff) {
		if(buttons == 1) 
			self.move(cast(Vec2f)diff, true);
	};
	window.onMouseUp = (Surface self, byte buttons, Vec2i coordinates) {
		self.blur();
	};
	window.onMouseOver = (Surface self, byte buttons, Vec2i coordinates) {
		self.style.set("background-material: url('gui/skin/clear3.png')");
	};
	window.onMouseOut = (Surface self, byte buttons, Vec2i coordinates) {
		self.style.set("background-material: url('gui/skin/clear2.png')");
	};
	
	
	// Events for main surface.
	view.onKeyDown = delegate void (Surface self, int key, int modifier){
		if (key == SDLK_ESCAPE)
			Device.abort("Yage aborted by esc key press.");
		
		if(key == SDLK_c){
			std.gc.fullCollect();
			writefln("garbage collected");
		}
	};
	view.onMouseDown = delegate void (Surface self, byte buttons, Vec2i coordinates){
		self.grabMouse(!scene.ship.input);
		scene.ship.input = !scene.ship.input;
	};
	view.onMouseMove = delegate void (Surface self, byte buttons, Vec2i rel){
		if(scene.ship.input)
			scene.ship.mouseDelta = scene.ship.mouseDelta + rel;
	};
	view.onResize = delegate void (Surface self, Vec2f amount){
		scene.camera.setResolution(cast(int)self.width, cast(int)self.height);
	};


	int fps = 0;
	Timer frame = new Timer();
	Timer delta = new Timer();
	Log.write("Starting rendering loop.");
	std.gc.fullCollect();
	
	// Rendering loop
	while(!Device.isAborted())
	{
		float dtime = delta.get();
		delta.reset();

		Input.processInput();
		scene.camera.toTexture();
		view.render();

		// Print framerate
		fps++;
		if (frame.get()>=0.25f)
		{	SDL_WM_SetCaption("Yage Demo\0", null);
			window.text = swritef("%.2f fps\n%d objects\n%d polygons\n%d vertices",
				fps/frame.get(), scene.camera.getNodeCount(), scene.camera.getPolyCount(), scene.camera.getVertexCount());
			frame.reset();
			fps = 0;
		}
		
		// Free up a little cpu if over 60 fps.
		if (dtime < 1/60.0)			
			std.c.time.usleep(cast(int)((1/60.0f-dtime)*1_000_000));
		scene.swapTransformRead();
	}
	//scene.finalize(); // is this needed to prevent albuffer.c error?
	Device.deInit();

	return 0;
}
