/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module demo2.main;

import std.string;
import std.stdio;
import derelict.sdl.sdl;
import yage.all;

import derelict.opengl.gl;
import derelict.opengl.glext;

import demo1.ship;

// Current program entry point.  This may change in the future.
int main()
{	
  	// Init (resolution, depth, fullscreen, aa-samples)
	Device.init(800, 600, 32, false, 1);
	//Device.init(1024, 768, 32, true);
	//Device.init(1440, 900, 32, true);

	// Paths
	Resource.addPath("../res/");
	Resource.addPath("../res2/");
	Resource.addPath("../res/shader");

	new Material("fx/smoke.xml");
	new Material("fx/flare1.xml");

	// Create and start a Scene
	Log.write("Starting update loop.");
	Scene scene = new Scene();
	scene.start(60); // update 60 times per second
	
	Device.onExit = &scene.stop;
	
	// Skybox
	Scene skybox = new Scene();
	auto sky = new ModelNode(skybox);
	sky.setModel("sky/sanctuary.ms3d");
	scene.setSkybox(skybox);
	scene.setGlobalAmbient(Color("555555"));

	// Ship
	Ship ship = new Ship(scene);
	ship.setPosition(Vec3f(0, 50, -950));
	ship.getCameraSpot().setPosition(Vec3f(0, 1000, 3000));

	// Camera
	CameraNode camera = new CameraNode(ship.getCameraSpot());
	camera.setView(2, 20000, 60, 0, 1);	// wide angle view

	Surface disp = new Surface(null);
	disp.topLeft = Vec2f(0,0);
	disp.bottomRight = Vec2f(1, 1);
	disp.setVisibility(true);
	disp.setTexture(camera.getTexture());

	
	void onMousedown(Surface self, byte buttons, Vec2i coordinates){
		self.grabMouse(!ship.input);
		ship.input = !ship.input;
	}

	void onMousemove(Surface self, byte buttons, Vec2i rel){
		if(ship.input){
 			ship.mouseDelta = ship.mouseDelta.add(rel);
		}
	}
	
	void onResize(Surface self){
		camera.setResolution(self.size.x, self.size.y);
		writefln("Camera resolution changed to ", self.size.x, " x ", self.size.y);
	}
	
	void onKeydown(Surface self, byte key){
		if (Input.keydown[SDLK_ESCAPE])
			Device.exit(0);
		
		if(key == SDLK_c){
			std.gc.fullCollect(); 
			writefln("garbage collected");
		}
	}
	
	disp.onMousedown = &onMousedown;	
	disp.onResize = &onResize;
	disp.onMousemove = &onMousemove;
	disp.onKeydown = &onKeydown;
		
	// Music
	SoundNode music = new SoundNode(camera);
	music.setSound("music/celery - pages.ogg");
	music.setLooping(true);
	music.play();

	// Lights
	LightNode l1 = new LightNode(scene);
	l1.setDiffuse(Color(1, .85, .7));
	l1.setLightRadius(7000);
	l1.setPosition(Vec3f(0, 0, -6000));

	// Star
	SpriteNode star = new SpriteNode(l1);
	star.setMaterial("space/star.xml");
	star.setScale(Vec3f(2500));

	// Planet
	auto planet = new ModelNode(scene);
	planet.setModel("space/planet.ms3d");
	planet.scale = Vec3f(60);
	planet.setAngularVelocity(Vec3f(0, -0.01, 0));
	
	//planet.getModel().clearAttribute("gl_Normal");
	
	// Asteroids
	asteroidBelt(800, 1400, planet);

	// Add to the scene's update loop
	void update(BaseNode self){
		ship.getSpring().update(1/60.0f);
	}
	scene.onUpdate(&update);

	Device.resizeWindow(800, 600);
	//disp.recalculateTexture();
	
	// Rendering / Input Loop
	int fps = 0;
	Timer frame = new Timer();
	Timer delta = new Timer();
	Log.write("Starting rendering loop.");
	while(1)
	{
		float dtime = delta.get();
		delta.reset();

		//earth.getModel().getMeshes()[0].getMaterial().getLayers()[1].getTextures()[0].position.x -= dtime/1024;

		Input.processInput();
		camera.toTexture();
		disp.render();
		
		
		// Print framerate
		fps++;
		if (frame.get()>=0.25f)
		{	char[] caption = formatString("Yage Test (%.2f fps) (%d objects, %d polygons, %d vertices rendered)\0",
				fps/frame.get(), camera.getNodeCount(), camera.getPolyCount(), camera.getVertexCount());
			SDL_WM_SetCaption(caption.ptr, null);
			delete caption;
			frame.reset();
			fps = 0;
		}

		// Cap framerate
		//if (dtime < 1/60.0)
			std.c.time.usleep(cast(uint)(1000));
		scene.swapTransformRead();
	}

	return 0;
}
