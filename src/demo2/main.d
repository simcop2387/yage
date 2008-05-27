/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel, Joe Pusdesris (deformative0@gmail.com)
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

import demo2.ship;
import demo2.gameobj;

// Current program entry point.  This may change in the future.
int main(){
	
	// Init (resolution, depth, fullscreen, aa-samples)
	Device.init(800, 600, 32, false, 1);
	
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
	
	Surface bg = new Surface(null);
	bg.setTexture(camera.getTexture());
	bg.topLeft = Vec2f(0,0);
	bg.bottomRight = Vec2f(1, 1);
	bg.setVisibility(true);
		
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
		if (key == SDLK_ESCAPE)
			Device.exit(0);
		
		if (key == SDLK_SPACE){
			Flare flare = new Flare(ship.getScene());
			flare.setPosition(ship.getAbsolutePosition());
			flare.setVelocity(Vec3f(0, 0, -150).rotate(ship.ship.getAbsoluteTransform())+ship.getVelocity());

			SoundNode zap = new SoundNode(ship);
			zap.setSound("sound/laser.wav");
			zap.setVolume(.3);
			zap.setLifetime(2);
			zap.play();
		}
		
		if(key == SDLK_c){
			std.gc.fullCollect(); 
			writefln("garbage collected");
		}
	}
	
	bg.onMousedown = &onMousedown;
	bg.onResize = &onResize;
	bg.onMousemove = &onMousemove;
	bg.onKeydown = &onKeydown;
	
	GPUTexture active = new GPUTexture("test/clear.png");
	GPUTexture inactive = new GPUTexture("test/clearInactive.png");
	GPUTexture inactive2 = new GPUTexture("test/clearInactive2.png");
	
	void onMousedown2(Surface self, byte buttons, Vec2i coordinates){
		self.raise();
		self.startDrag();
	}
	void onMouseup2(Surface self, byte buttons, Vec2i coordinates){
		self.endDrag();
	}
	void onMousemove2(Surface self, byte buttons, Vec2i diff){
		if(buttons == 1) self.drag(diff);
	}
	void onMouseenter(Surface self, byte buttons, Vec2i coordinates){
		self.setTexture(active);
	}
	void onMouseleave(Surface self, byte buttons, Vec2i coordinates){
		self.setTexture(inactive2);
	}
	
	Surface clear = new Surface(bg);
	clear.setTexture(inactive2);
	clear.topLeft = Vec2f(.65,0);
	clear.bottomRight = Vec2f(1, .25);
	clear.fill = stretched;
	clear.setVisibility(true);
	clear.onMousedown = &onMousedown2;
	clear.onMousemove = &onMousemove2;
	clear.onMouseup = &onMouseup2;
	clear.onMouseenter = &onMouseenter;
	clear.onMouseleave = &onMouseleave;
	
	Surface clear2 = new Surface(clear);
	clear2.setTexture(inactive2);
	clear2.topLeft = Vec2f(.65,0);
	clear2.bottomRight = Vec2f(1, .25);
	clear2.fill = stretched;
	clear2.setVisibility(true);
	clear2.onMousedown = &onMousedown2;
	clear2.onMousemove = &onMousemove2;
	clear2.onMouseup = &onMouseup2;
	clear2.onMouseenter = &onMouseenter;
	clear2.onMouseleave = &onMouseleave;

	Surface clear3 = new Surface(bg);
	clear3.setTexture(inactive2);
	clear3.topLeft = Vec2f(.65,0);
	clear3.bottomRight = Vec2f(1, .25);
	clear3.fill = stretched;
	clear3.setVisibility(true);
	clear3.onMousedown = &onMousedown2;
	clear3.onMousemove = &onMousemove2;
	clear3.onMouseup = &onMouseup2;
	clear3.onMouseenter = &onMouseenter;
	clear3.onMouseleave = &onMouseleave;

	Surface clear4 = new Surface(bg);
	clear4.setTexture(inactive2);
	clear4.topLeft = Vec2f(.4,0);
	clear4.bottomRight = Vec2f(1, .25);
	clear4.fill = stretched;
	clear4.setVisibility(true);
	clear4.onMousedown = &onMousedown2;
	clear4.onMousemove = &onMousemove2;
	clear4.onMouseup = &onMouseup2;
	clear4.onMouseenter = &onMouseenter;
	clear4.onMouseleave = &onMouseleave;

	Surface clear5 = new Surface(bg);
	clear5.setTexture(inactive);
	clear5.topLeft = Vec2f(.65,0);
	clear5.bottomRight = Vec2f(1, .4);
	clear5.fill = stretched;
	clear5.setVisibility(true);
	clear5.onMousedown = &onMousedown2;
	clear5.onMousemove = &onMousemove2;
	clear5.onMouseup = &onMouseup2;
	clear5.onMouseenter = &onMouseenter;
	clear5.onMouseleave = &onMouseleave;
	
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
	planet.scale = Vec3f(600);
	planet.setAngularVelocity(Vec3f(0, -0.01, 0));
	
	// Asteroids
	asteroidBelt(800, 1400, planet);

	// Add to the scene's update loop
	void update(Node self){
		ship.getSpring().update(1/60.0f);
	}
	scene.onUpdate(&update);
	
	bg.recalculate();
	
	// Rendering / Input Loop
	int fps = 0;
	Timer frame = new Timer();
	Timer delta = new Timer();
	Log.write("Starting rendering loop.");
	std.gc.fullCollect();
	while(1){
		float dtime = delta.get();
		delta.reset();

		Input.processInput();
		camera.toTexture();
		bg.render();
		
		
		// Print framerate
		fps++;
		if (frame.get()>=0.25f)
		{	char[] caption = formatString("Yage Test (%.2f fps) (%d objects, %d polygons, %d vertices rendered)\0",
				fps/frame.get(), camera.getNodeCount(), camera.getPolyCount(), camera.getVertexCount());
			SDL_WM_SetCaption(caption.ptr, null);
			//delete caption;
			frame.reset();
			fps = 0;
		}

		// Cap framerate
		//if (dtime < 1/60.0)
		//	std.c.time.usleep(cast(uint)(1000));
		scene.swapTransformRead();
	}

	return 0;
}
