import std.string;
import std.math;
import std.stdio;
import std.thread;
import std.random;
import derelict.sdl.sdl;
import yage.all;

import yage.universe;
import yage.ship;

/// Current program entry point.  This may change in the future.
void main()
{
	// Variables
	float res = 1440;
	float dtime=0;
  	float step = .1;

  	// Init
	Device.init(800, 600, 32, false);
	//Device.init(1440, 900, 32, true);
	//Device.init(1024, 768, 32, true);
	Resource.addPath("../res/");
	Resource.addPath("../res2/");
	Resource.addPath("../res/shader");

	Timer time  = new Timer();
	Timer delta = new Timer();
  	Timer frame = new Timer();

	// Create skybox and scene
	//Scene skybox = new Scene();
	//ModelNode sky = new ModelNode(skybox);
	//sky.setModel("sky/g2.ms3d");
	Universe scene = new Universe();

	//scene.setSkybox(skybox);
	scene.setGlobalAmbient(.5, .5, 1);
/*	scene.setClearColor(.7, .4, .2);
	scene.setFogColor(.7, .4, .2);
	scene.setFogDensity(.002);
	scene.enableFog(true);
*/
	// Camera
	CameraNode camera = new CameraNode(scene);
	Device.texture = camera.getTexture();
	camera.setView(.1, 100000, 75, 0, 1);	// wide angle view

	// Music
	SoundNode music = new SoundNode(camera);
	music.setSound("music/celery - pages.ogg");
	music.setLooping(true);
	music.play();

	// Lights
	LightNode l1 = new LightNode(scene);
	l1.setPosition(0, 0, -40);
	l1.setDiffuse(1, .85, .7);
	l1.setLightRadius(1200);

	// Star
	SpriteNode star = new SpriteNode(l1);
	star.setMaterial("fx/flare1.xml");
	star.setScale(250);

	// Ship
	Ship ship = new Ship(scene);
	camera.setParent(ship.getCameraSpot());
	ship.setPosition(Vec3f(0, 0, 300));
	ship.getCameraSpot().setPosition(0, 2000, 10000);


	// Universe
	scene.generate(400, 2000);
	Resource.material("fx/smoke.xml");

	void update(float dtime)
	{

	}
	Repeater updater = new Repeater(&update, 40);
	updater.start();


	// main loop
	Log.write("Beginning rendering loop" ~"");
	Input.setGrabMouse(false);
	delta.reset();
	Input.mousedx = Input.mousedy = 0;


	int fps = 0;
	int last;
	Input.setGrabMouse(true);
	scene.update(.1);
	while(!Input.exit)
	{
		dtime = delta.get();
		delta.reset();

		// check for exit
		if (Input.keydown[SDLK_ESCAPE])
		{	Input.exit=true;
			break;
		}

		// Toggle mouse grab
		if (Input.button[1].up)
		{	Input.button[1].up = false;
			Input.setGrabMouse(!Input.getGrabMouse());
		}

		// Create Explosion
		if (Input.keydown[SDLK_LSHIFT])
		{
			for (int i=0; i<100; i++)
			{	SpriteNode s = new SpriteNode(scene);
				s.setMaterial("fx/flare1.xml");
				s.setPosition(0, 0, 0);
				s.setVelocity(random(-1, 1)*100, random(-1, 1)*100, random(-1, 1)*100);
				s.setLifetime(random(8, 10));
				s.setScale(3);
			}
		}

		camera.toTexture();
		Device.render();

		Input.processInput();
		scene.update(dtime);
		ship.update(dtime);

		// Print framerate
		fps++;
		if (frame.get()>0.5f)
		{	char[] sfps = toString(fps*2);
			char[] onscreen = toString(camera.getNodeCount());

			char[] caption = "Yage Test (" ~ sfps ~ " fps) (" ~
				onscreen ~ " objects on screen)\0";
			SDL_WM_SetCaption(caption.ptr, null);
			delete caption;
			delete sfps;
			delete onscreen;
			frame.reset();
			fps = 0;
		}
		std.c.time.msleep(2);
	}
}
