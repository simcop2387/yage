/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel, Ludovic Angot
 * Warranty:   none
 *
 * This module is not part of the engine, but merely uses it.
 * This is a demo to show off some of the cool features of Yage 
 * and also acts a general, incomplete test for regressions.
 */

module demo3.main;

import tango.core.Memory;
import tango.core.Thread;

import derelict.sdl.sdl;

import yage.all;
import yage.core.json;
import yage.system.graphics.all;
import yage.resource.graphics.material;

import demo3.gameobj;
import demo3.rtscamera;

class TerrainDemo : Scene
{
	RTSCamera rtsCamera;

	SoundNode music;
	LightNode light;
	SpriteNode star;
	
	// Create the scene and all elements in it
	this()
	{		
		super();
		ambient = "#102733"; // global ambient
		backgroundColor = "#ffffff";

		// Terrain
		auto terrainGenerator = new HmapHeightGenerator( "terrain/badlandsHeight.png", Vec2i(256), HmapHeightGenerator.Scaling.REPEAT);
		auto terrain = new TerrainNode(terrainGenerator,  this);

		auto terrainMaterial = new Material(true);
			auto passTerrain = terrainMaterial.getPass();
			passTerrain.ambient = "#fff";
			passTerrain.textures = [
				TextureInstance(ResourceManager.texture("terrain/badlands.jpg"))
				];
			//passTerrain.autoShader = MaterialPass.AutoShader.PHONG;
		terrain.materialOverrides ~= terrainMaterial;
		//terrain.setScale(Vec3f(2400, 2400, 2200));
		terrain.setScale(Vec3f(1000, 1000, 1000));
		terrain.setPosition(Vec3f(0, 0, -1000));
		// Camera
		rtsCamera = scene.addChild(new RTSCamera());
		rtsCamera.setPosition(Vec3f(0, 0, 0));
		
		// Lights
		light = new LightNode(this);
		light.diffuse = "#fed";
		light.ambient = "#555";
		//light.type = LightNode.Type.DIRECTIONAL;
		light.setLightRadius(10000);
		light.setPosition(Vec3f(10000, 10000, 0));
	}

	override void update(float delta)
	{	super.update(delta);	
	}
}


// Current program entry point.  This may change in the future.
int main()
{
	Repeater physicsThread;

	// The engine is running as long as something happens
	bool running = true;

	// Init and create window
	System.init();
	auto window = Window.getInstance();
	window.setResolution(500, 245, 0, false, 0);
	window.onExit = delegate void() {
		Log.info("Yage aborted by window close.");
		running = false;
	};
	
	// Add path to textures and shaders
	ResourceManager.addPath(["../res/", "../res/shader", "../res/gui/font"]);

	// Create and start a Scene
	Log.info("Starting update loop.");
	auto scene = new TerrainDemo();

	// Main surface that receives input.
	Surface view = new Surface("width: 100%; height: 100%");
	
	// Events for main surface.
	view.onKeyDown = curry(delegate void (int key, int modifier, TerrainDemo* scene) {
		if (key == SDLK_ESCAPE)
		{	running = false;
			Log.info("Yage aborted by esc key press.");
		}
		
		// Trigger the garbage collector
		if(key == SDLK_c) {
			GC.collect();
			Log.info("Garbage collected");
		}
		
		// Reset the scene
		if (key == SDLK_r)
		{	physicsThread.pause();
			physicsThread.dispose();
			delete *scene;
			GC.collect();
			*scene = new TerrainDemo();
			physicsThread.play();
		}
		if (key == SDLK_x)
		{	Render.reset();
		}
		
		scene.rtsCamera.keyDown(key);
	}, &scene);
	
	view.onKeyUp = curry(delegate void(int key, int modifier, TerrainDemo* scene){
		scene.rtsCamera.keyUp(key);
	}, &scene);
	
	view.onMouseDown = curry(delegate void(Input.MouseButton button, Vec2f coordinates, Surface self, TerrainDemo* scene){
		/* Check which mouse button is activated */
		switch (button)
		{	case Input.MouseButton.LEFT:
				/* Activate the mouse for the 'view' surface (if it belongs to another surface) */
				scene.rtsCamera.hasMouse = ! scene.rtsCamera.hasMouse;
				self.grabMouse(scene.rtsCamera.hasMouse);
				break;
			case Input.MouseButton.CENTER:
				scene.rtsCamera.input.rotate = true;
				break;
			case Input.MouseButton.RIGHT:
				scene.rtsCamera.input.altitude = true;
				break;
			default:
				break;
		}
	}, view, &scene);

	view.onMouseUp = curry(delegate void(Input.MouseButton button, Vec2f coordinates, Surface self, TerrainDemo* scene){
		/* Check which mouse button is released */
		switch (button)
		{	case Input.MouseButton.CENTER:
				scene.rtsCamera.input.rotate = false;
				break;
			case Input.MouseButton.RIGHT:
				scene.rtsCamera.input.altitude = false;
				break;
			default:
				break;
		}
	}, view, &scene);

	view.onMouseMove = curry(delegate void(Vec2f amount, TerrainDemo* scene) {
		if(scene.rtsCamera.hasMouse)
			scene.rtsCamera.input.mouseDelta += amount.vec2f;
	}, &scene);


	/* Make a draggable GUI window to show some useful info. */
	auto info = new Surface(view);
	info.style.set("top: 5px; right: 12px; width: 115px; height: 70px; color: white; " ~
		"border-width: 12px; border-image: url('gui/skin/panel1.png'); font-size: 11px");
	
	/* Event for info window */
	// Boolean to know if "info" reacts to mouse motion
	bool dragging;

	info.onMouseDown = curry(delegate void(Input.MouseButton button, Vec2f coordinates, Surface self) {
		if (button == Input.MouseButton.LEFT)
			dragging = true;
	}, info);
	info.onMouseMove = curry(delegate void(Vec2f amount, Surface self) {
		if (dragging)
			self.move(amount, true);
	}, info);
	info.onMouseUp = curry(delegate void(Input.MouseButton button, Vec2f coordinates, Surface self) {
		if (button == Input.MouseButton.LEFT)
			dragging = false;
	}, info);
	info.onMouseOver = curry(delegate void(Surface self) {
		self.style.set("border-image: url('gui/skin/panel2.png')");
	}, info);
	info.onMouseOut = curry(delegate void(Surface next, Surface self) {
		self.style.set("border-image: url('gui/skin/panel1.png')");
	}, info);
	
	int fps = 0;
	Timer frame = new Timer(true);
	Timer delta = new Timer(true);
	Log.info("Starting rendering loop.");
	GC.collect();
	GC.disable();
	
	/* Make a GUI window to show controls settings. */
	auto settings = new Surface(view);
	settings.style.set("bottom: 3px; left: 3px; width: 465px; height: 15px; color: white; " ~
		"border-width: 12px; border-image: url('gui/skin/panel1.png'); font-size: 11px");
	settings.setHtml("arrows to move | mouse C to rotate | mouse R to change altitude | space for flares");

	// Physics loop thread
	physicsThread = new Repeater(curry(delegate void(TerrainDemo scene) {
		scene.update(1/60f);
	}, scene), true, 60);

	// Rendering loop
	float dtime=0, ltime=0;
	while(running && !physicsThread.error)
	{
		ltime = dtime;
		dtime = delta.tell();
		//Log.trace(dtime-ltime);
		delta.seek(0);

		Input.processAndSendTo(view);
		auto stats = Render.scene(scene.rtsCamera.camera, window);

		Render.surface(view, window);
		Render.complete(); // swap buffers
		
		// Print framerate
		fps++;
		if (frame.tell()>=1f)
		{	float framerate = fps/frame.tell();
			window.setCaption(format("Yage Demo | %.2f fps\0", framerate));
			info.setHtml(format(
				`%.2f <b>fps</span><br/>`
				`%.1f%% <b>physics cpu</span><br/>`
				`%d <b>objects</b><br/>`
				`%d <b>polygons</b><br/>`
				`%d <b>vertices</b><br/>`
				`%d <b>lights</b>`,
					framerate, scene.updateTime*60*100, stats.nodeCount, stats.triangleCount, stats.vertexCount, stats.lightCount) ~ 
					Profile.getTimesAndClear());
			frame.seek(0);
			fps = 0;
		}
	}

	// Stop the threads and report any errors
	if (physicsThread.error)
		Log.write(physicsThread.error);
	physicsThread.dispose();
	
	System.deInit();
	return 0;
}
