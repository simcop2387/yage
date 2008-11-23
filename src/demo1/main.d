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
import std.random;

import derelict.opengl.gl;
import derelict.opengl.glext;
import derelict.sdl.sdl;

import yage.all;

import demo1.ship;
import demo1.misc;



// Current program entry point.  This may change in the future.
int main()
{		
  	// Init (resolution, depth, fullscreen, aa-samples)
	Device.init(800, 600, 32, false, 1);
	//Device.init(1024, 768, 32, true);
	//Device.init(1440, 900, 32, true);
	
	// Paths
	Resource.addPath("../res/");
	Resource.addPath("../res/shader");
	Resource.addPath("../res2/");	

	// Create and start a Scene
	Log.write("Starting update loop.");
	Scene scene = new Scene();
	scene.play(); // update 60 times per second
	
	// Skybox
	Scene skybox = new Scene();
	auto sky = skybox.addChild(new ModelNode());
	sky.setModel("sky/sanctuary.ms3d");
	scene.setSkybox(skybox);
	scene.setGlobalAmbient(Color("555555"));
	
	// Ship
	Ship ship = scene.addChild(new Ship());	
	ship.setPosition(Vec3f(0, 50, -950));
	ship.getCameraSpot().setPosition(Vec3f(0, 1000, 3000));
	
	// Camera
	CameraNode camera = ship.getCameraSpot().addChild(new CameraNode());
	ship.getCameraSpot().addChild(camera);
	camera.setView(2, 20000, 60, 0, 1);	// wide angle view

	
	// Music
	auto music = new SoundNode();
	camera.addChild(music);
	music.setSound("music/celery - pages.ogg");
	music.setLooping(true);
	music.play();

	// Lights
	auto l1 = scene.addChild(new LightNode());
	l1.setDiffuse(Color(1, .85, .7));
	l1.setLightRadius(7000);
	l1.setPosition(Vec3f(0, 0, -6000));

	// Star
	auto star = l1.addChild(new SpriteNode());
	star.setMaterial("space/star.xml");
	star.setSize(Vec3f(2500));

	// Planet
	auto planet = scene.addChild(new ModelNode());
	planet.setModel("space/planet.ms3d");
	planet.setSize(Vec3f(60));
	planet.setAngularVelocity(Vec3f(0, -0.01, 0));
	
	// Asteroids
	asteroidBelt(800, 1400, planet);

	
	// Main surface where camera output is rendered.
	Surface view = new Surface();
	view.style.backgroundMaterial = camera.getTexture();
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
	window.onMouseMove = (Surface self, byte buttons, Vec2i diff){
		if(buttons == 1) 
			self.move(cast(Vec2f)diff, true);
	};
	window.onMouseUp = (Surface self, byte buttons, Vec2i coordinates){
		self.blur();
	};
	window.onMouseOver = (Surface self, byte buttons, Vec2i coordinates){
		self.style.set("background-material: url('gui/skin/clear3.png')");
	};
	window.onMouseOut = (Surface self, byte buttons, Vec2i coordinates){
		self.style.set("background-material: url('gui/skin/clear2.png')");
	};
	
	
	// Events for main surface.
	view.onKeyDown = delegate void (Surface self, int key, int modifier){
		if (key == SDLK_ESCAPE)
			Device.running = false;
		
		if(key == SDLK_c){
			std.gc.fullCollect();
			writefln("garbage collected");
		}
	};
	view.onMouseDown = delegate void (Surface self, byte buttons, Vec2i coordinates){
		self.grabMouse(!ship.input);
		ship.input = !ship.input;
	};
	view.onMouseMove = delegate void (Surface self, byte buttons, Vec2i rel){
		if(ship.input)
 			ship.mouseDelta = ship.mouseDelta + rel;
	};
	view.onResize = delegate void (Surface self, Vec2f amount){
		camera.setResolution(cast(int)self.width, cast(int)self.height);
	};
	// Add to the scene's update loop
	void update(Node self){
		ship.getSpring().update(1/60.0f);
		// Test creation and removal of lots of lights and sounds and sprites.
		/*
		for (int i=0; i<1; i++)
		{	
			auto flare = scene.addChild(new SpriteNode());
			flare.setMaterial("fx/flare1.xml");
			flare.setSize(Vec3f(2));
			flare.setPosition(Vec3f(0, 0, -1400));
			flare.setLifetime((rand()%100)/100.0f + 2);
			flare.setVelocity(Vec3f(cast(int)((rand()%100)-50)/2.0f, (cast(int)(rand()%100)-50)/2.0f, (cast(int)(rand()%100)-50)/2.0f));
			
			auto l = flare.addChild(new LightNode());
			l.setDiffuse(Color(1, 1, 1));
			l.setLightRadius(1200);
			
			SoundNode zap = flare.addChild(new SoundNode());
			zap.setSound("sound/laser.wav");
			zap.setVolume(1);
			zap.setLifetime(2); 
			zap.play();	 	
		}
		*/
	}
	scene.onUpdate(&update);
	
	// Rendering / Input Loop
	int fps = 0;
	Timer frame = new Timer();
	Timer delta = new Timer();
	Log.write("Starting rendering loop.");
	std.gc.fullCollect();	
	while(Device.running)
	{
		float dtime = delta.get();
		delta.reset();

		Input.processInput();
		camera.toTexture();
		view.render();

		// Print framerate
		fps++;
		if (frame.get()>=0.25f)
		{	SDL_WM_SetCaption("Yage Demo\0", null);
			window.text = swritef("%.2f fps\n%d objects\n%d polygons\n%d vertices",
				fps/frame.get(), camera.getNodeCount(), camera.getPolyCount(), camera.getVertexCount());
			frame.reset();
			fps = 0;
		}
		
		// Free up a little cpu if over 60 fps.
		if (dtime < 1/60.0)
			std.c.time.usleep(100);
		scene.swapTransformRead();
	}
	scene.pause();
	scene.finalize();
	
	Device.deInit();

	return 0;
}
