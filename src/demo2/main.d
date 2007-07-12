/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module demo1.main;

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
	scope(exit)scene.stop();

	// Skybox
	Scene skybox = new Scene();
	auto sky = new ModelNode(skybox);
	sky.setModel("sky/sanctuary.ms3d");
	scene.setSkybox(skybox);
	scene.setGlobalAmbient(Vec4f(.3));

	// Ship
	Ship ship = new Ship(scene);
	ship.setPosition(Vec3f(0, 50, -950));
	ship.getCameraSpot().setPosition(0, 1000, 3000);

	// Camera
	CameraNode camera = new CameraNode(ship.getCameraSpot());
	camera.setView(2, 20000, 60, 0, 1);	// wide angle view
	
	Surface bg = new Surface(null);
	bg.topLeft = Vec2f(.05,.05);
	bg.bottomRight = Vec2f(.95, .95);
	bg.setTexture(new GPUTexture("test2.png"));
	bg.fill = stretched;
	bg.setVisibility(true);
	
	Surface disp = new Surface(bg);
	disp.topLeft = Vec2f(.1,.1);
	disp.bottomRight = Vec2f(.9, .9);
	disp.setTexture(new GPUTexture("test/bc-dark.png"));
	//disp.fill = stretched;
	disp.setVisibility(true);

	Surface first = new Surface(disp);
	first.setTexture(new GPUTexture("test.png"));
	first.fill = stretched;
	first.topLeft = Vec2f(.8, .8);
	first.bottomRight = Vec2f(.95, .95);
	first.setVisibility(true);
	
	Surface third = new Surface(disp);
	third.setTexture(new GPUTexture("box.png"));
	third.fill = stretched;
	third.topLeft = Vec2f(.8, .05);
	third.bottomRight = Vec2f(.95, .2);
	third.setVisibility(true);
	
	Surface fourth = new Surface(disp);
	fourth.setTexture(new GPUTexture("test/button2.png"));
	fourth.fill = stretched;
	fourth.topLeft = Vec2f(.05, .8);
	fourth.bottomRight = Vec2f(.2, .95);
	fourth.setVisibility(true);
	
	Surface fifth = new Surface(disp);
	fifth.setTexture(new GPUTexture("test/radio1.png"));
	fifth.fill = stretched;
	fifth.topLeft = Vec2f(.05, .05);
	fifth.bottomRight = Vec2f(.2, .2);
	fifth.setVisibility(true);
	
	Surface second = new Surface(disp);
	second.setTexture(camera.getTexture());
	second.topLeft = Vec2f(.2,.2);
	second.bottomRight = Vec2f(.8, .8);
	second.setVisibility(true);
	
	Surface clear = new Surface(second);
	clear.setTexture(new GPUTexture("test/clear.png"));
	clear.topLeft = Vec2f(.1,.1);
	clear.bottomRight = Vec2f(.9, .9);
	clear.fill = stretched;
	clear.setVisibility(true);
	
	void onMousedown(Surface self, byte buttons, Vec2i coordinates){
		self.raise();
		Input.button[1].up = false;
		Input.setGrabMouse(!Input.getGrabMouse());
	}
	
	void onResize(Surface self){
		int xres = self.position2.x - self.position1.x;
		int yres = self.position2.y - self.position1.y;
		camera.setResolution(xres, yres);
		writefln("Camera resolution changed to ", xres, " x ", yres);
	}
	
	void onMousedown2(Surface self, byte buttons, Vec2i coordinates){
		self.raise();
		Input.setSurfaceLock(self);
	}
	void onMouseup2(Surface self, byte buttons, Vec2i coordinates){
		Input.unlockSurface();
	}
	void onMousemove(Surface self, byte buttons, Vec2i coordinates){
		if(buttons == 1) self.moveAdd(coordinates);
	}
	
	second.onMousedown = &onMousedown;	
	second.onResize = &onResize;
	clear.onMousedown = &onMousedown2;
	clear.onMousemove = &onMousemove;
	clear.onMouseup = &onMouseup2;
	first.onMousedown = &onMousedown2;
	first.onMousemove = &onMousemove;
	first.onMouseup = &onMouseup2;
	
	bg.onMousedown = &onMousedown2;
	bg.onMousemove = &onMousemove;
	bg.onMouseup = &onMouseup2;
	
	// Music
	SoundNode music = new SoundNode(camera);
	music.setSound("music/celery - pages.ogg");
	music.setLooping(true);
	music.play();

	// Lights
	LightNode l1 = new LightNode(scene);
	l1.setDiffuse(1, .85, .7);
	l1.setLightRadius(7000);
	l1.setPosition(0, 0, -6000);

	// Star
	SpriteNode star = new SpriteNode(l1);
	star.setMaterial("space/star.xml");
	star.setScale(2500);

	// Planet
	auto planet = new ModelNode(scene);
	planet.setModel("space/planet.ms3d");
	planet.setScale(60);
	planet.setAngularVelocity(0, -0.01, 0);
	
	//planet.getModel().clearAttribute("gl_Normal");
	
	// Asteroids
	asteroidBelt(800, 1400, planet);

	// Add to the scene's update loop
	Input.getMouseDelta();
	void update(BaseNode self)
	{	// check for exit
		if (Input.keydown[SDLK_ESCAPE])
			Input.exit=true;

		// Toggle mouse grab
// 		if (Input.button[1].up)
// 		{	Input.button[1].up = false;
// 			Input.setGrabMouse(!Input.getGrabMouse());
// 		}
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
	while(!Input.exit)
	{
		float dtime = delta.get();
		delta.reset();

		//earth.getModel().getMeshes()[0].getMaterial().getLayers()[1].getTextures()[0].position.x -= dtime/1024;

		Input.processInput();
		camera.toTexture();
		bg.render();
		
		
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
