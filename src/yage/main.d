/**
 * Copyright:  (c) 2006-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * This module is not technically part of the engine, but merely uses it.
 */

module yage.main;

import std.string;
import std.stdio;
import derelict.sdl.sdl;
import yage.all;

import yage.universe;
import yage.ship;

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

	// Create and start a Scene
	Log.write("Starting update loop.");
	Scene scene = new Scene();
	scene.start(90);
	scope(exit)scene.stop();

	// Skybox
	Scene skybox = new Scene();
	auto sky = new ModelNode(skybox);
	sky.setModel("sky/sanctuary.ms3d");
	scene.setSkybox(skybox);
	scene.setGlobalAmbient(Vec4f(.5));

	// Ship
	Ship ship = new Ship(scene);
	ship.setPosition(Vec3f(0, 500, 1300));
	ship.getCameraSpot().setPosition(0, 1000, 3000);

	// Camera
	CameraNode camera = new CameraNode(ship.getCameraSpot());
	camera.setView(1, 150000, 60, 0, 1);	// wide angle view
	Device.texture = camera.getTexture();

	// Music
	SoundNode music = new SoundNode(camera);
	music.setSound("music/celery - pages.ogg");
	music.setLooping(true);
	music.play();

	// Lights
	LightNode l1 = new LightNode(scene);
	l1.setDiffuse(1, .85, .7);
	l1.setLightRadius(5000);

	// Star
	SpriteNode star = new SpriteNode(l1);
	star.setMaterial("space/star.xml");
	star.setScale(400);

	// Asteroids
	asteroidBelt(700, 1800, scene);

	/*
	Image img = new Image("misc/heightmap.bmp");
	img.resize(256, 256);
	auto t = new TerrainNode(scene);
	t.setHeightMap(img);
	t.setPosition(0, -2000, 0);
	t.setScale(10000, 2000, 10000);
	t.setMaterial("misc/test.xml");
	*/

	// Add to the scene's update loop
	Input.getMouseDelta();
	void update(BaseNode self)
	{	// check for exit
		if (Input.keydown[SDLK_ESCAPE])
			Input.exit=true;

		// Toggle mouse grab
		if (Input.button[1].up)
		{	Input.button[1].up = false;
			Input.setGrabMouse(!Input.getGrabMouse());
		}
		ship.getSpring().update(1/90.0f);
	}
	scene.onUpdate(&update);

	// Rendering / Input Loop
	int fps = 0;
	Timer frame = new Timer();
	Timer delta = new Timer();
	Log.write("Starting rendering loop.");
	while(!Input.exit)
	{
		float dtime = delta.get();
		delta.reset();

		Input.processInput();
		camera.toTexture();
		Device.render();

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
		//if (dtime < 1/90.0)
		//	std.c.time.usleep(cast(uint)(1000*1000 / (90-dtime) ));
		scene.swapTransformRead();
	}

	return 0;
}
