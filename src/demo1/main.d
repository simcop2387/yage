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

import derelict.sdl.sdl;

import yage.all;
import yage.core.json;
import demo1.ship;
import demo1.gameobj;
import yage.system.graphics.all;
import yage.resource.material;

import yage.system.graphics.api.api : GraphicsException;

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
		ambient = "#123"; // global ambient
		
		// Skybox
		skyBox = new Scene();
		auto sky = new ModelNode("sky/blue-nebula.dae");
		sky.setScale(Vec3f(1000));
		skyBox.addChild(sky);
		
		
		// Ship
		ship = addChild(new Ship());	
		ship.setPosition(Vec3f(5000, 150, 0));
		ship.getCameraSpot().setPosition(Vec3f(1000, 4000, 10000));

		// Camera
		camera = ship.getCameraSpot().addChild(new CameraNode());
		ship.getCameraSpot().addChild(camera);
		camera.setView(2, 2000000, 60, 0, 1);	// wide angle and distanct
		
		// Music
		music = camera.addChild(new SoundNode("music/celery - pages.ogg"));
		music.setLooping(true);
		//music.play();

		// Lights
		light = scene.addChild(new LightNode());
		light.diffuse = "#fed";
		light.setLightRadius(1000000);
		light.setPosition(Vec3f(0, 0, -600000));

		// Star
		star = light.addChild(new SpriteNode());
		star.setMaterial("space/star.dae", "star-material");
		star.setSize(Vec3f(100000));

		// Planet
		planet = scene.addChild(new ModelNode("space/planet.dae"));
		planet.setSize(Vec3f(200));
		planet.setAngularVelocity(Vec3f(0, -0.005, 0));
		
		// Atmosphere
		/*
		auto atmosphere = planet.addChild(new SpriteNode());
		atmosphere.setMaterial("space/star2.dae", "star-material");
		atmosphere.getMaterial().getPass().blend = MaterialPass.Blend.AVERAGE;
		atmosphere.setSize(Vec3f(3000));
		*/
		
		// Moon
		auto moon = scene.addChild(new ModelNode("space/planet.dae"));
		auto moonMaterial = new Material(true);
		auto pass = moonMaterial.getPass();
		pass.ambient = "#fff";
		pass.textures = [
			TextureInstance(ResourceManager.texture("space/rocky2.jpg")),
			TextureInstance(ResourceManager.texture("space/rocky2-normal.jpg", Texture.Format.AUTO_UNCOMPRESSED))
		];
		pass.autoShader = MaterialPass.AutoShader.PHONG;
		moon.materialOverrides ~= moonMaterial;
		moon.setPosition(Vec3f(8000, 0, -1000));
		moon.setSize(Vec3f(50));		
		moon.setAngularVelocity(Vec3f(0, 0.01, 0));
		

		// Asteroids
		asteroidBelt(4000, 5000, planet);
	}
	
	override void update(float delta)
	{	super.update(delta);
		ship.getSpring().update(1/60.0f);
	}
}

// Current program entry point.  This may change in the future.
int main()
{		
	// Init and create window
	System.init(); 
	auto window = Window.getInstance();
	window.setResolution(720, 445, 0, false, 0); // golden ratio
	//window.setResolution(1920, 1080, 0, true, 4);
	ResourceManager.addPath(["../res/", "../res/shader", "../res/gui/font"]);

	// Create and start a Scene
	Log.info("Starting update loop.");
	auto scene = new DemoScene();
	scene.play(); // update 60 times per second
	
	// Main surface that receives input.
	Surface view = new Surface("width: 100%; height: 100%");
	
	// Events for main surface.
	view.onKeyDown = (Surface self, int key, int modifier){
		if (key == SDLK_ESCAPE)
			System.abort("Yage aborted by esc key press.");
		
		// Trigger the garbage collector
		if(key == SDLK_c) {
			GC.collect();
			Log.info("Garbage collected");
		}
		//if (key == SDLK_f)
		//	window.setResolution(640, 480, 0, false, 1); // TODO: fix this

		
		// Reset the scene
		if (key == SDLK_r)
		{	scene.pause();
			scene = new DemoScene();
			scene.camera.setListener();
			scene.play();
		}	
		if (key == SDLK_x)
		{	Render.reset();
		}
		
		scene.ship.keyDown(key);
		return false;
	};
	
	view.onKeyUp = (Surface self, int key, int modifier){
		scene.ship.keyUp(key);
		return false;
	};
	
	view.onMouseDown = (Surface self, Input.MouseButton button, Vec2f coordinates){
		scene.ship.acceptInput = !scene.ship.acceptInput;
		self.grabMouse(scene.ship.acceptInput);
		return false;
	};
	view.onMouseMove = (Surface self, Vec2f amount){
		if(scene.ship.acceptInput)
			scene.ship.input.mouseDelta += amount.vec2i;
		return false;
	};
		
	// Make a draggable window to show some useful info.
	auto info = new Surface(view);
	info.style.set("top: 5px; right: 12px; width: 115px; height: 100px; color: white; " ~
		"border-width: 12px; border-image: url('gui/skin/panel1.png'); font-size: 12px");

	//window.style.backgroundImage = scene.camera.getTexture();
	bool dragging;
	info.onMouseDown = delegate bool(Surface self, Input.MouseButton button, Vec2f coordinates) {
		if (button == Input.MouseButton.LEFT)
			dragging = true;
		return false; // don't propagate upward
	};
	info.onMouseMove = delegate bool(Surface self, Vec2f amount) {
		if (dragging)
			self.move(amount, true);
		return false;
	};
	info.onMouseUp = delegate bool(Surface self, Input.MouseButton button, Vec2f coordinates) {
		if (button == Input.MouseButton.LEFT)
			dragging = false;
		return false;
	};
	info.onMouseOver = delegate bool(Surface self) {
		self.style.set("border-image: url('gui/skin/panel2.png')");
		return false;
	};
	info.onMouseOut = delegate bool(Surface self) {
		self.style.set("border-image: url('gui/skin/panel1.png')");
		return false;
	};

	int fps = 0;
	Timer frame = new Timer(true);
	Timer delta = new Timer(true);
	Log.info("Starting rendering loop.");
	GC.collect();
	
	// Rendering loop
	while(!System.isAborted())
	{
		float dtime = delta.tell();
		delta.seek(0);

		Input.processAndSendTo(view);
		auto stats = Render.scene(scene.camera, window);
		Render.surface(view, window);
		Render.complete(); // swap buffers
		
		// Print framerate
		fps++;
		if (frame.tell()>=1f)
		{	float framerate = fps/frame.tell();
			window.setCaption(format("Yage Demo | %.2f fps\0", framerate));
			info.setHtml(format(
				`%.2f <b>fps</span><br/>`
				`%d <b>objects</b><br/>`
				`%d <b>polygons</b><br/>`
				`%d <b>vertices</b><br/>`
				`%d <b>lights</b><br/><br/> wasd to move<br/> +q for hyperdrive<br/>space to shoot`,
				framerate, stats.nodeCount, stats.triangleCount, stats.vertexCount, stats.lightCount) ~ Profile.getTimesAndClear());
			frame.seek(0);
			fps = 0;
		}
		
		// Free up a little cpu if over 60 fps.
		//if (dtime < 1/60.0)
		//	Thread.sleep(1/60.0f-dtime);
	}
	
	System.deInit();
	return 0;
}