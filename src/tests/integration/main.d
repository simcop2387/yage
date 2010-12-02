/*
 * Copyright:  (c) 2005-2010 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Boost 1.0
 */

module tests.demo.main;

import tango.core.Thread;
import tango.math.Math;
import tango.text.Util;
import yage.all;
import yage.core.math.vector;
import yage.resource.embed.embed;

/*
 * A floating camera that can be moved and rotated. */
class FPSCamera : Node
{	
	float speed = 300; 			// units/second^2 acceleration
	float angularSpeed = .2; 	// radians of acceleration per pixel of mouse movement.
	float dampen = 5;			// dampen linear velocity by this % every second
	float angularDampen = 50;	// dampen angular velocity by this % every second.
	
	CameraNode camera;			// Camera rotates its pitch while the ModelNode parent rotates its yaw.
	bool up, down, left, right;
	Vec2f rotation;
	
	this()
	{	camera = addChild(new CameraNode());
	}
	
	Vec2f getOrientation()
	{	return Vec2f(getRotation().y, camera.getRotation().x);
	}
	
	void setOrientation(Vec2f orientation)
	{	setRotation(Vec3f(0, orientation.x, 0));
		camera.setRotation(Vec3f(orientation.y, 0, 0));
	}
	
	override void update(float delta)
	{	
		// Dampen and accelerate linear velocity
		float speed = this.speed*delta;
		setVelocity(getVelocity().scale(max(1-delta*dampen, 0.0f)));
		Vec3f move = Vec3f(speed*right - speed*left, 0, speed*down - speed*up);
		accelerate(move.rotate(camera.getTransform()).rotate(getTransform()));
		
		// Dampen and accelerate angular velocity
		setAngularVelocity(getAngularVelocity().scale(max(1-delta*angularDampen, 0.0f)));
		camera.setAngularVelocity(camera.getAngularVelocity().scale(max(1-delta*angularDampen, 0.0f)));		
		angularAccelerate(Vec3f(0, -rotation.x*angularSpeed, 0));
		camera.angularAccelerate(Vec3f(rotation.y*angularSpeed, 0, 0));
		rotation = Vec2f(0);
		
		super.update(delta);
	}
}

/*
 * A basic scene with a movable camera.
 * Other test Scenes typically inherit from this. */
class TestScene : Scene
{
	char[] name = "Unnamed Scene";
	protected FPSCamera camera;
	
	this(char[] name)
	{	this.name = name;
		camera = scene.addChild(new FPSCamera());
	}
	
	FPSCamera getCamera()
	{	return camera;
	}	
	
	void keyState(int key, bool state)
	{	if (key == SDLK_w || key == SDLK_UP)
			camera.up = state;
		if (key == SDLK_a || key == SDLK_LEFT)
			camera.left = state;
		if (key == SDLK_s || key == SDLK_DOWN)
			camera.down = state;
		if (key == SDLK_d || key == SDLK_RIGHT)
			camera.right = state;
		
		if (key == SDLK_x) // reset shaders
		{
			Embed.phong_vert = cast(char[])ResourceManager.getFile("../src/yage/resource/embed/phong.vert");
			Embed.phong_frag = cast(char[])ResourceManager.getFile("../src/yage/resource/embed/phong.frag");
			
			Render.reset();
		}
	}
}

class LotsOfObjects : TestScene
{
	Model asteroid;
	
	this()
	{	super("Lots of Objects");
		
		int length = 24;
		int spacing = 10;
		
		// Add asteroids
		asteroid = new Model("space/asteroid1.dae");
		for (int x=-length/2; x<length/2; x++)
			for (int y=-length/2; y<length/2; y++)
				for (int z=-length/2; z<length/2; z++)
				{	auto node = new ModelNode(asteroid);
					node.setPosition(Vec3f(x*spacing, y*spacing, z*spacing));
					node.setScale(Vec3f(.1));
					addChild(node);
				}
		
		// Add rotating lights
		auto rotater1 = new Node(this);
		rotater1.setAngularVelocity(Vec3f(0, 1, 0));
		
		LightNode l = new LightNode(rotater1);
		l.setPosition(Vec3f(0, 0, 100));
		l.setLightRadius(100);
		
		LightNode l2 =new LightNode(rotater1);
		l2.setPosition(Vec3f(0, 0, -100));
		l2.setLightRadius(100);
		l2.diffuse = "green";
		
		LightNode l3 = new LightNode(rotater1);
		l3.setPosition(Vec3f(100, 0, 0));
		l3.setLightRadius(100);
		l3.diffuse = "red";
		
		LightNode l4 =new LightNode(rotater1);
		l4.setPosition(Vec3f(-100, 0, 0));
		l4.setLightRadius(100);
		l4.diffuse = "blue";		
		
		//camera.setPosition(Vec3f(0, 0, -500));
	}
}

class SoundsAndPicking : TestScene
{
	Model asteroid;
	
	this()
	{	super("Sounds and Picking");
	
		int length = 4;
		int spacing = 150;
		
		// Add asteroids
		asteroid = new Model("space/asteroid1.dae");
		for (int x=-length/2; x<length/2; x++)
			for (int y=-length/2; y<length/2; y++)
				for (int z=-length/2; z<length/2; z++)
				{	auto node = new ModelNode(asteroid);
					node.setPosition(Vec3f(x*spacing, y*spacing, z*spacing));
					node.setScale(Vec3f(random(.1, 2)));
					addChild(node);
					
					auto sound = new SoundNode("sound/ship-engine.ogg", node);
					sound.volume = .1;
					sound.play();
					sound.looping = true;
				}
		
		// Add rotating lights
		LightNode l = addChild(new LightNode());
		l.setPosition(Vec3f(30, 30, 130));
		l.setLightRadius(400);
			
		//camera.setPosition(Vec3f(0, 0, -500));
	}
}

/*
 * Test lights and fogs.
 * This Scene has a box with fog and multiple spinning lights inside */
class LightsAndFog : TestScene
{	
	MaterialPass pass;
	LightNode /*light1, */light2, light3, light4;
	
	this()
	{	super("Lights and Fog");
	
		backgroundColor = "gray";
		
		// Create a textured plane
		Geometry geometry = Geometry.createPlane(4, 4);
		auto texture = TextureInstance(ResourceManager.texture("space/rocky2.jpg"));
		auto normal = TextureInstance(ResourceManager.texture("space/rocky2-normal.jpg"));
		texture.transform = Matrix().scale(Vec3f(8));
		
		pass = geometry.getMeshes()[0].getMaterial().getPass();	
		pass.lighting = true;
		pass.emissive = "#222";
		pass.diffuse = "gray";
		pass.specular = "gray";
		pass.shininess = 128;
		pass.textures = [texture, normal];
		pass.autoShader = MaterialPass.AutoShader.PHONG;
	
		// Make a box out of six planes
		ModelNode plane;
		float PI = 3.1415927f;
		
		// Bottom/Top
		plane = scene.addChild(new ModelNode(geometry));
		plane.setPosition(Vec3f(0, -50, 0));
		plane.setRotation(Vec3f(-PI/2, 0, 0));
		plane.setScale(Vec3f(50));

		plane = scene.addChild(new ModelNode(geometry));
		plane.setPosition(Vec3f(0, 50, 0));
		plane.setRotation(Vec3f(PI/2, 0, 0));
		plane.setScale(Vec3f(50));
		
		// Left/Right
		plane = scene.addChild(new ModelNode(geometry));
		plane.setPosition(Vec3f(0, 0, -50));
		plane.setRotation(Vec3f(0, 0, 0));
		plane.setScale(Vec3f(50));
		
		plane = scene.addChild(new ModelNode(geometry));
		plane.setPosition(Vec3f(0, 0, 50));
		plane.setRotation(Vec3f(0, PI, 0));
		plane.setScale(Vec3f(50));
		
		// Front/Back
		plane = scene.addChild(new ModelNode(geometry));
		plane.setPosition(Vec3f(-50, 0, 0));
		plane.setRotation(Vec3f(0, PI/2, 0));
		plane.setScale(Vec3f(50));
		
		plane = scene.addChild(new ModelNode(geometry));
		plane.setPosition(Vec3f(50, 0, 0));
		plane.setRotation(Vec3f(0, -PI/2, 0));
		plane.setScale(Vec3f(50));
		
		
		// A critter
		auto beast = new ModelNode("character/beast.dae");
		scene.addChild(beast);
		beast.setScale(Vec3f(.3));
		beast.setPosition(Vec3f(0, -20, -20));
		beast.rotate(Vec3f(1.507, 0, 0));
		beast.setAngularVelocity(Vec3f(0, .5, 0));
		beast.getModel().drawJoints = true;
		
		/*
		auto terrorist = scene.addChild(new ModelNode("character/terrorist/terrorist.dae"));
		terrorist.setPosition(Vec3f(20, -40, -20));
		terrorist.getModel().drawJoints = true;
		*/
		// Lights
		auto rotater = addChild(new ModelNode());
		//rotater.setAngularVelocity(Vec3f(0, 0.5, 0));
		auto light1 = rotater.addChild(new LightNode());
		light1.setPosition(Vec3f(10, 0, 0));
		//light1.setAngularVelocity(Vec3f(0, 10, 0));
		light1.diffuse = "white";
		light1.setLightRadius(80);		
		//light1.spotExponent = 3;
		//light1.spotAngle = 80 * 3.1415/180;
		//light1.type = LightNode.Type.SPOT;
		
		
		light2 = addChild(new LightNode());
		light2.setAngularVelocity(Vec3f(.1, .1, 0));
		light2.diffuse = "red";
		light2.setLightRadius(100);
		light2.spotExponent = 1;
		light2.spotAngle = 20 * 3.1415/180;
		light2.type = LightNode.Type.SPOT;

		light3 = light1.addChild(new LightNode());
		light3.setPosition(Vec3f(0, 0, -49));
		light3.setAngularVelocity(Vec3f(1, 1, 0));
		light3.diffuse = "blue";
		light3.setLightRadius(20);

		// Enable fog
		//this.fogEnabled = true;
		this.fogDensity = 0.01;	
	}
	
	override void keyState(int key, bool state)
	{	super.keyState(key, state);	
		
		if (pass)
		{	// Force shader to reload
			if (key == SDLK_x && state)
				pass.shader = null;
			
			// Toggle shaders on/off
			if (key == SDLK_t && state)
				pass.autoShader = pass.autoShader == MaterialPass.AutoShader.NONE ? MaterialPass.AutoShader.PHONG : MaterialPass.AutoShader.NONE;
		}
	}
}

/*
 * Test rendering transparent objects */
class Transparency : TestScene
{	
	MaterialPass pass;
	LightNode light1, light2, light3, light4;
	
	this()
	{	super("Transparency");
		backgroundColor = "white";
		
		camera.move(Vec3f(5));
		
		// Create a textured plane
		Geometry geometry = Geometry.createPlane(1, 1);
		auto texture = TextureInstance(ResourceManager.texture("misc/reference2.png"));
		
		pass = geometry.getMeshes()[0].getMaterial().getPass();			
		pass.emissive = 0x222222;
		pass.diffuse = "white";
		pass.emissive = "gray";
		pass.blend = MaterialPass.Blend.AVERAGE;
		pass.textures ~= texture;
		
		Geometry geometry2 = Geometry.createPlane(1, 1);
		auto texture2 = TextureInstance(ResourceManager.texture("fx/smoke.png"));
		
		MaterialPass pass2 = geometry2.getMeshes()[0].getMaterial().getPass();			
		pass2.emissive = 0x222222;
		pass2.diffuse = "white";
		pass2.emissive = "gray";
		pass2.blend = MaterialPass.Blend.AVERAGE;
		pass2.textures ~= texture2;

		// Make a circle of the planes
		float PI = 3.1415927f;
		
		auto rotator = new Node(scene);
		rotator.setAngularVelocity(Vec3f(0, .1, 0));
		
		int number = 50;
		for (int i=0; i<number; i++)
		{
			float angle = i/cast(float)number * PI*2;
			
			auto plane = rotator.addChild(new ModelNode(i%2==0 ? geometry : geometry2));
			plane.setPosition(Vec3f(cos(angle)*number, 0, sin(angle)*number));
			plane.setRotation(Vec3f(0, PI-angle, 0));
			plane.setSize(Vec3f(10));		
			
			auto plane2 = rotator.addChild(new ModelNode(i%2==0 ? geometry : geometry2));
			plane2.setPosition(Vec3f(cos(angle)*number, 0, sin(angle)*number));
			plane2.setRotation(Vec3f(0, -angle, 0)); // back side
			plane2.setSize(Vec3f(10));
		}
		
		// Lights
		light1 = addChild(new LightNode());
		light1.setPosition(Vec3f(0, 40, 20));
		light1.diffuse = "white";
		light1.setLightRadius(120);
	}
	
	override void keyState(int key, bool state)
	{	super.keyState(key, state);	
		
		if (pass)
		{	// Force shader to reload
			if (key == SDLK_x && state)
				pass.shader = null;
			
			// Toggle shaders on/off
			if (key == SDLK_t && state)
				pass.autoShader = pass.autoShader == MaterialPass.AutoShader.NONE ? MaterialPass.AutoShader.PHONG : MaterialPass.AutoShader.NONE;
		}
	}
}

/*
 * UI Provides a surface for the main rendering area and a small window to show info. */
class UI : Surface
{
	TestScene[] scenes;
	
	/**
	 * A tab on the Panel */
	class Tab : Surface
	{	
		this(char[] name, Surface parent, Panel info, Surface show)
		{	super("width: 58px; height: 20px; background-color: black", name, parent);
			onMouseOver = curry((Tab self)
			{	self.style.set("background-color: gray");
				self.mouseOver();
			}, this);
			onMouseOut = curry((Surface next, Tab self)
			{	self.style.set("background-color: black");
				self.mouseOut(next);
			}, this);
				
			onClick = curry((Input.MouseButton button, Vec2f coordinates, Panel info, Surface show)
			{	info.stats.style.display = info.stats is show;
				info.scene.style.display = info.scene is show;
				info.controls.style.display = info.controls is show;
			}, info, show);
		}
	}
	
	/**
	 * A dialog for showing */
	class Panel : Surface
	{
		Surface stats, scene, controls;
		private bool dragging = false;
		
		this(TestScene[] scenes, Surface parent=null)
		{	
			super(parent);
			style.set("width: 400px; height: 300px; color: white; " ~
				"border-width: 12px; border-image: url('gui/skin/panel1.png'); font-size: 13px");
			
			// Content
			Surface content = new Surface("width: 100%; height: 100%; top: 25px", this); // container for content pages
			
			char[] contentStyle = "width: 100%; height: 100%; display: none";
			stats = new Surface(contentStyle, "Stats", content);
			scene = new Surface(contentStyle, "Scene", content);
			controls = new Surface(contentStyle, "", content);
			stats.style.display = true;
			
			// Tabs
			Surface tabs = new Surface(this);
			Surface statsTab = new Tab("Stats", tabs, this, stats);
			Surface sceneTab = new Tab("Scenes", tabs, this, scene);
			sceneTab.style.left = "60px";
			Surface controlsTab = new Tab("Controls", tabs, this, controls);
			controlsTab.style.left = "120px";
						
			// Events
			onMouseDown = curry((Input.MouseButton button, Vec2f coordinates, Panel self)
			{	if (button==Input.MouseButton.LEFT)
					self.dragging = true;
			}, this);
			onMouseMove = curry((Vec2f amount, Panel self) // allow dragging
			{	if (self.dragging)
					self.move(amount, true);
			}, this);
			onMouseUp =  curry((Input.MouseButton button, Vec2f coordinates, Panel self)
			{	if (button==Input.MouseButton.LEFT)
					self.dragging = false;
			}, this);
			
			// Populate the list of scenes on the scenes tab.
			int y = 0;
			foreach (scene; scenes)
			{	auto button = new Surface("width: 100px; height: 18px; background-color: gray", scene.name, this.scene);
				button.style.top = y;
				button.onClick = curry((Input.MouseButton button, Vec2f coordinates, Panel panel, TestScene scene) {
					App.setScene(scene);
				}, this, scene);
				y+=20;
			}
			
			// Controls
			Surface textAreaLabel = new Surface("", "TextArea:", controls); // TODO: textarea's overflow: hidden hides the tabs.  why?
			Surface textarea = new Surface("width: 100px; height: 96px; top: 15px; border: 1px solid white; padding: 3px; background-color: #00000088; overflow: hidden", "Click here to edit", controls);
			textarea.editable = true;
		}
	}
	Panel panel;
	
	this(TestScene[] scenes) 
	{	
		style.set("width: 100%; height: 100%"); // no longer necessary?
		panel = new Panel(scenes, this);
		
		// Mouse Events
		onMouseUp = curry((Input.MouseButton button, Vec2f coordinates, Surface self) // grab on click
		{	self.grabMouse(!self.getGrabbedMouse());
		}, this);
		onMouseMove = curry((Vec2f amount, UI self) { // rotate camera on mouse move when grabbed
			if (self.getGrabbedMouse())
				App.scene.getCamera().rotation += amount;
		}, this);
		
		// Keyboard events
		onKeyDown = (int key, int modifier) 
		{	App.scene.keyState(key, true);
			if (key == SDLK_ESCAPE)
			{	running = false;
				Log.info("Yage aborted by esc key press.");
			}
		};
		onKeyUp = (int key, int modifier) 
		{	App.scene.keyState(key, false);
		};
	}
}

class App
{	static Window window;
	static TestScene scene;
	static UI ui;
	
	static void setScene(TestScene scene)
	{
		if (this.scene)
			this.scene.pause();
		this.scene = scene;
		scene.camera.camera.setListener();
		scene.play();
	}	
}

bool running = true;

// Entry point
void main()
{	
	// Initialize and create window
	System.init(); 
	App.window = Window.getInstance();
	App.window.setResolution(720, 445, 0, false, 1); // golden ratio
	App.window.onExit = delegate void() {
		Log.info("Yage aborted by window close.");
		running = false;
	};
	ResourceManager.addPath(["../res/", "../res/shader", "../res/gui/font"]);
	
	TestScene[] scenes = [cast(TestScene)new Transparency(), new SoundsAndPicking(), new LightsAndFog(), new LotsOfObjects];
	App.setScene(scenes[2]);
	
	// User interface
	App.ui = new UI(scenes);
	
	// Rendering loop
	int fps = 0;
	Timer frame = new Timer(true);
	while(running && !System.getThreadExceptions())
	{
		Input.processAndSendTo(App.ui);
		auto stats = Render.scene(App.scene.getCamera().camera, App.window);
		Render.surface(App.ui, App.window);
		Render.complete(); // swap buffers
		
		// Print framerate
		fps++;		
		if (frame.tell()>=1f)
		{	float framerate = fps/frame.tell();
			App.window.setCaption(format("Yage Integration Tests | %s fps\0", framerate));
			App.ui.panel.stats.setHtml(format(
				`%s <b>fps</span><br/>`
				`%s <b>objects</b><br/>`
				`%s <b>polygons</b><br/>`
				`%s <b>vertices</b><br/>`
				`Press w, a, s, d to move.<br/>`
				`Click the screen for mouse grab.<br/>`,
				framerate, stats.nodeCount, stats.triangleCount, stats.vertexCount) ~
				Profile.getTimesAndClear().substitute("\n", "<br/>"));
			frame.seek(0);
			fps = 0;
		}
		Profile.clear();
		
		//Thread.getThis().sleep(0.01);
		//Thread.getThis().yield();
	}
	System.deInit();
}