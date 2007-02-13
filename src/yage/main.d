/*
 * Copyright:  (c) 2006-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module yage.main;

import std.bind;
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
int main()
{
	// Variables
	float dtime=0;
  	float step = .2;

  	// Init
	Device.init(800, 600, 32, false);
	//Device.init(1024, 768, 32, true);
	//Device.init(1440, 900, 32, true);
	Resource.addPath("../res/");
	Resource.addPath("../res2/");
	Resource.addPath("../res/shader");

	Timer delta = new Timer();
  	Timer frame = new Timer();

	// Create skybox and scene
	Scene skybox = new Scene();
	ModelNode sky = new ModelNode(skybox);
	sky.setModel("sky/sanctuary.ms3d");
	Universe scene = new Universe();
	scene.setSkybox(skybox);
	scene.setGlobalAmbient(Vec4f(.5));

	scene.setClearColor(.5, .5, .5);
	scene.setFogColor(.5, .5, .5);
	//scene.setFogEnabled(true);
	scene.setFogDensity(.0001);

	// Camera
	CameraNode camera = new CameraNode(scene);
	Device.texture = camera.getTexture();
	camera.setView(1, 150000, 60, 0, 1);	// wide angle view

	// Music
	SoundNode music = new SoundNode(camera);
	music.setSound("music/celery - pages.ogg");
	music.setLooping(true);
	music.play();

	// Lights
	LightNode l1 = new LightNode(scene);
	l1.setPosition(0, 1, 1);
	l1.setDiffuse(1, .85, .7);
	l1.setLightRadius(200000);
	l1.setLightType(LIGHT_DIRECTIONAL);

	// Star
	SpriteNode star = new SpriteNode(l1);
	star.setMaterial("space/star.xml");
	star.setScale(400);

	// Ship
	Ship ship = new Ship(scene);
	ship.setPosition(Vec3f(0, 500, 1300));
	ship.getCameraSpot().setPosition(0, 1000, 3000);
	camera.setParent(ship.getCameraSpot());

	// Universe
	asteroidBelt(1000, 1800, scene);

	// main loop
	Log.write("Beginning rendering loop" ~"");
	Input.setGrabMouse(false);
	delta.reset();
	Input.mousedx = Input.mousedy = 0;

	int fps = 0;
	//Input.setGrabMouse(true);
	long last_count = 0;
	while(!Input.exit)
	{
		//long count = getCPUCount();
		//writefln(dtime);
		//last_count = count;

		dtime = delta.get();
		delta.reset();
		//dtime = 0.03;

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
			for (int i=0; i<10; i++)
			{	SpriteNode s = new SpriteNode(scene);
				s.setMaterial("fx/flare1.xml");
				s.setPosition(0, 0, 0);
				s.setVelocity(Vec3f(random(-1, 1)*500, random(-1, 1)*500, random(-1, 1)*500));
				s.setLifetime(random(3, 4));
				s.setScale(12);

				void recolor(BaseNode self)
				{	(cast(SpriteNode)self).setColor(1, 1, 1, self.getLifetime()/3);
				}
				s.onUpdate(&recolor);
			}
		}
		//star.setPosition(0, dtime*10000, 0);


		Input.processInput();
		ship.getSpring().update(dtime);
		scene.update(dtime);
		camera.toTexture();
		Device.render();

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
	}

	return 0;
}
