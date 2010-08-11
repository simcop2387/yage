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
class FPSCamera : MovableNode
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
	protected FPSCamera camera;
	
	this(char[] name)
	{	camera = scene.addChild(new FPSCamera());	
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
		
		if (key == SDLK_x)
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
	
	this(char[] name)
	{	super(name);
		
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
		auto rotater1 = addChild(new MovableNode());
		rotater1.setAngularVelocity(Vec3f(0, 1, 0));
		
		LightNode l = rotater1.addChild(new LightNode());
		l.setPosition(Vec3f(0, 0, 100));
		l.setLightRadius(100);
		
		LightNode l2 = rotater1.addChild(new LightNode());
		l2.setPosition(Vec3f(0, 0, -100));
		l2.setLightRadius(100);
		l2.diffuse = "green";
		
		LightNode l3 = rotater1.addChild(new LightNode());
		l3.setPosition(Vec3f(100, 0, 0));
		l3.setLightRadius(100);
		l3.diffuse = "red";
		
		LightNode l4 = rotater1.addChild(new LightNode());
		l4.setPosition(Vec3f(-100, 0, 0));
		l4.setLightRadius(100);
		l4.diffuse = "blue";		
		
		//camera.setPosition(Vec3f(0, 0, -500));
	}
}

class Picking : TestScene
{
	Model asteroid;
	
	this(char[] name)
	{	super(name);
	
		int length = 4;
		int spacing = 150;
		
		// Add asteroids
		asteroid = new Model("space/asteroid1.dae");
		for (int x=-length/2; x<length/2; x++)
			for (int y=-length/2; y<length/2; y++)
				for (int z=-length/2; z<length/2; z++)
				{	auto node = new ModelNode(asteroid);
					node.setPosition(Vec3f(x*spacing, y*spacing, z*spacing));
					node.setScale(Vec3f(random(.2, 5)));
					addChild(node);
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
	
	this(char[] name)
	{	super(name);
	
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
		beast.setPosition(Vec3f(0, -40, -20));
		//beast.setAngularVelocity(Vec3f(0, .5, 0));
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
	
	this(char[] name)
	{	super(name);
		backgroundColor = "white";
		
		// Create a textured plane
		Geometry geometry = Geometry.createPlane(1, 1);
		auto texture = TextureInstance(ResourceManager.texture("misc/reference2.png"));
		
		pass = geometry.getMeshes()[0].getMaterial().getPass();			
		pass.emissive = Color(0x222222);
		pass.diffuse = "white";
		pass.emissive = "gray";
		pass.blend = MaterialPass.Blend.AVERAGE;
		pass.textures ~= texture;
		
		Geometry geometry2 = Geometry.createPlane(1, 1);
		auto texture2 = TextureInstance(ResourceManager.texture("fx/smoke.png"));
		
		MaterialPass pass2 = geometry2.getMeshes()[0].getMaterial().getPass();			
		pass2.emissive = Color(0x222222);
		pass2.diffuse = "white";
		pass2.emissive = "gray";
		pass2.blend = MaterialPass.Blend.AVERAGE;
		pass2.textures ~= texture2;

		// Make a circle of the planes
		float PI = 3.1415927f;
		
		auto rotator = scene.addChild(new MovableNode());
		rotator.setAngularVelocity(Vec3f(0, .1, 0));
		
		int number = 500;
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
	
	TestScene currentScene;
	TestScene[] scenes;
	
	class Info : Surface
	{
		Surface stats, scene, controls;
		private bool dragging = false;
		
		this(Surface parent=null)
		{	super(parent);
			style.set("width: 400px; height: 300px; color: white; " ~
				"border-width: 12px; border-image: url('gui/skin/panel1.png'); font-size: 13px");
			
			// Tabs
			Surface tabs = new Surface(this);
			Surface statsTab = new Surface("width: 60px; height: 20px; background-color: green", "Stats", tabs);
			statsTab.onClick = (Surface self, Input.MouseButton button, Vec2f coordinates)
			{	if (button==Input.MouseButton.LEFT)
				{	Log.trace("tab click", coordinates);
					self.style.display = false;
					//(cast(Info)self).stats.style.visible = true;
				}
				return false;
			};
			statsTab.onMouseOver = (Surface self)
			{	self.style.set("background-color: red");
				return false;
			};
			statsTab.onMouseOut = (Surface self)
			{	self.style.set("background-color: red");
				return false;
			};
			
			Surface sceneTab = new Surface("width: 60px; height: 20px; left: 60px", "Scenes", tabs);
			Surface controlsTab = new Surface("width: 60px; height: 20px; left: 120px", "Controls", tabs);
			
			// Content area
			Surface content = new Surface("width: 50%; height: 70px; top: 30px; left: 30px", this);
			content.onMouseOver = (Surface self)
			{	self.style.set("background-color: blue");
				return false;
			};		
			content.onMouseOut = (Surface self)
			{	self.style.set("background-color: transparent");
				return false;
			};
			
			/*
			stats = new Surface("width: 100%; height: 100%", "stats", content);
			scene = new Surface("width: 100%; height: 100%", content);
			controls = new Surface("width: 100%; height: 100%", content);
			stats.style.visible = scene.style.visible = controls.style.visible = false;		
			*/
			
			
			// Allow dragging
			onMouseDown = (Surface self, Input.MouseButton button, Vec2f coordinates)
			{	if (button==Input.MouseButton.LEFT)
					(cast(Info)self).dragging = true;
				return false;
			};
			onMouseMove = (Surface self, Vec2f amount)
			{	if ((cast(Info)self).dragging)
					self.move(amount, true);
				return false;
			};
			onMouseUp = (Surface self, Input.MouseButton button, Vec2f coordinates)
			{	if (button==Input.MouseButton.LEFT)
					(cast(Info)self).dragging = false;
				return false;
			};
			onMouseOver = (Surface self)
			{	self.style.set("border-image: url('gui/skin/panel2.png')");
				return false;
			};
			onMouseOut = (Surface self)
			{	self.style.set("border-image: url('gui/skin/panel1.png')");
				return false;
			};
			
			
		}
	}
	Info info;
	
	this(TestScene[] scenes) 
	{	currentScene = scenes[0];
		style.set("width: 100%; height: 100%");
		info = new Info(this);
	}
	
	override void mouseDown(Input.MouseButton button, Vec2f coordinates)
	{	super.mouseDown(button, coordinates);
		grabMouse(!getGrabbedMouse());
	};
	
	override void mouseMove(Vec2f amount) 
	{	super.mouseMove(amount);		
		if (getGrabbedMouse())
			currentScene.getCamera().rotation += amount;
	};
	
	override void keyDown(int key, int modifier) 
	{	super.keyDown(key, modifier);
		currentScene.keyState(key, true);
		
		if (key == SDLK_ESCAPE)
			System.abort("Yage aborted by esc key press.");
	};
	
	override void keyUp(int key, int modifier) 
	{	super.keyUp(key, modifier);
		currentScene.keyState(key, false);
	};
}

// Entry point
void main()
{		
	// Initialize and create window
	System.init(); 
	auto window = Window.getInstance();
	window.setResolution(720, 445, 0, false, 1); // golden ratio
	ResourceManager.addPath(["../res/", "../res/shader", "../res/gui/font"]);

	// Create and start a Scene
	auto scene = new Picking("Picking"); // set which scene to test
	scene.getUpdateThread().setFrequency(60);
	scene.play(); // start scene thread
	
	// User interface
	UI ui = new UI([scene]);
	
	// Rendering loop
	int fps = 0;
	Timer frame = new Timer(true);
	Timer delta = new Timer(true);
	while(!System.isAborted())
	{
		Input.processAndSendTo(ui);
		auto stats = Render.scene(scene.getCamera().camera, window);
		Render.surface(ui, window);
		Render.complete(); // swap buffers
		
		// Print framerate
		fps++;		
		if (frame.tell()>=1f)
		{	float framerate = fps/frame.tell();
			window.setCaption(format("Yage Integration Tests | %s fps\0", framerate));
			/*ui.info.stats.setHtml(format(
				`%s <b>fps</span><br/>`
				`%s <b>objects</b><br/>`
				`%s <b>polygons</b><br/>`
				`%s <b>vertices</b><br/>`,
				framerate, stats.nodeCount, stats.triangleCount, stats.vertexCount) ~
				Profile.getTimesAndClear().substitute("\n", "<br/>"));
			*/
			frame.seek(0);
			fps = 0;
		}
		Profile.clear();
		
		//Thread.getThis().sleep(0.01);
		//Thread.getThis().yield();
	}
	System.deInit();
}