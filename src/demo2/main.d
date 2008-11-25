/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty:   none
 *
 * This module is not part of the engine, but merely uses it.
 * This is minimal code to launch yage and draw something.
 */

module min.main;

import std.string;
import std.stdio;
import std.random;
import derelict.sdl.sdl;
import yage.all;

import derelict.opengl.gl;
import derelict.opengl.glext;

// program entry point.
int main()
{
	Device.init(800, 600, 32, false, 1);
	
	// Paths
	ResourceManager.addPath(["../res", "../res2"]);
	
	// ResourceManager.material("fx/flare1.xml"); // This shouldn't be required here.
	
	// Create and start a Scene
	Scene scene = new Scene();
	scene.play();
	scene.setClearColor(Color("green"));
	
	// Ship
	auto ship = scene.addChild(new ModelNode());
	ship.setModel("obj/tie2.obj");
	ship.setAngularVelocity(Vec3f(0, 1, 0));

	// Camera
	auto camera = scene.addChild(new CameraNode());
	camera.setPosition(Vec3f(0, 5, 30));	
	
	// Main surface where camera output is rendered.
	auto view = new Surface();
	view.style.backgroundMaterial = camera.getTexture();
	view.style.set("background-color: red; font-family: url('gui/font/Vera.ttf')");	
	Device.setSurface(view);
	
	// Events for main surface.
	bool grabbed = true;
	view.onKeyDown = delegate void (Surface self, int key, int modifier){
		if (key == SDLK_ESCAPE)
			Device.running = false;	
	};
	view.onMouseDown = delegate void (Surface self, byte buttons, Vec2i coordinates) {
		self.grabMouse(grabbed);
		grabbed = !grabbed;
	};
	
	// Lights
	auto l1 = scene.addChild(new LightNode());
	l1.setPosition(Vec3f(0, 300, -300));
	
	//	 Music
	auto music = new SoundNode();
	camera.addChild(music);
	music.setSound("music/celery - pages.ogg");
	music.setLooping(true);
	music.play();
	
	// Add to the scene's update loop
	void update(Node self){
		
		// Test creation and removal of lots of lights and sounds and sprites.
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
	}
	scene.onUpdate(&update);
	
	// Rendering / Input Loop
	int fps = 0;
	Timer frame = new Timer();
	while(Device.running)
	{		
		Input.processInput();
		scene.swapTransformRead(); // swap scene buffer so the latest version can be rendered.
		camera.toTexture();
		view.render();
		
		// Print framerate
		fps++;
		if (frame.get()>=0.25f)
		{	view.text = swritef("%.2f fps", fps/frame.get());
			frame.reset();
			fps = 0;			
		}
	}
	
	// Free resources that can't be freed by the garbage collector.
	Device.deInit();
	return 0;
}
