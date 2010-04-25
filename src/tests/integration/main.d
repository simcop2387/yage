
module unittests.demo.main;

import tango.core.Thread;
import tango.math.Math;
import tango.text.Util;
import yage.all;
import yage.core.math.vector;

/*
 * A floating camera that can be moved and rotated. */
class FPSCamera : MovableNode
{	
	float speed = 200; 			// units/second^2 acceleration
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
	
	this()
	{	camera = scene.addChild(new FPSCamera());	
	}
	
	FPSCamera getCamera()
	{	return camera;
	}	
	
	void keyState(int key, bool state)
	{	if (key == SDLK_w)
			camera.up = state;
		if (key == SDLK_a)
			camera.left = state;
		if (key == SDLK_s)
			camera.down = state;
		if (key == SDLK_d)
			camera.right = state;
	}
}

class LotsOfObjects : TestScene
{
	this()
	{
		int length = 20;
		int spacing = 10;
		
		// Add asteroids
		Model asteroid = new Model("space/asteroid1.dae");
		for (int x=-length/2; x<length/2; x++)
			for (int y=-length/2; y<length/2; y++)
				for (int z=-length/2; z<length/2; z++)
				{	auto node = new ModelNode(asteroid);
					node.setPosition(Vec3f(x*spacing, y*spacing, z*spacing));
					node.setScale(Vec3f(.1));
					addChild(node);
				}
		
		// Add rotating light
		auto rotater1 = addChild(new MovableNode());
		rotater1.setAngularVelocity(Vec3f(0, 1, 0));
		LightNode l = rotater1.addChild(new LightNode());
		l.setPosition(Vec3f(0, 0, 100));
		l.setLightRadius(100);		
	}	
}

/*
 * Test lights and fogs.
 * This Scene has a box with fog and multiple spinning lights inside */
class LightsAndFog : TestScene
{	
	MaterialPass pass;
	LightNode light1, light2, light3, light4;
	
	this()
	{	backgroundColor = "white";
		
		// Create a textured plane
		Geometry geometry = Geometry.getPlane(16, 16);
		Texture texture = Texture(ResourceManager.texture("space/rocky2.jpg"));
		texture.transform = Matrix().scale(Vec3f(4));
		
		pass = geometry.getMeshes()[0].getMaterial().getPass();			
		pass.emissive = Color(0x222222);
		pass.diffuse = "white";
		pass.specular = "gray";
		pass.shininess = 128;
		pass.textures ~= texture;
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
		
		
		// Lights
		light1 = addChild(new LightNode());
		light1.setAngularVelocity(Vec3f(0, 0.3, 0));
		light1.diffuse = "white";
		light1.setLightRadius(120);		
		light1.spotExponent = 32;
		light1.spotAngle = 45 * 3.1415/180;
		light1.type = LightNode.Type.SPOT;
		
		light2 = addChild(new LightNode());
		light2.setAngularVelocity(Vec3f(1, 1, 0));
		light2.diffuse = "red";
		light2.setLightRadius(100);
		light2.spotExponent = 1;
		light2.spotAngle = 20 * 3.1415/180;
		light2.type = LightNode.Type.SPOT;
		
		light3 = light2.addChild(new LightNode());
		light3.setPosition(Vec3f(0, 0, -49));
		light3.setAngularVelocity(Vec3f(1, 1, 0));
		light3.diffuse = "blue";
		light3.setLightRadius(20);	

		// Enable fog
		this.fogEnabled = true;
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
 * UI Provides a surface for the main rendering area and a small window to show info. */
class UI : Surface
{
	Surface info;
	TestScene scene;
	
	this(TestScene scene) 
	{	this.scene = scene;
		info = addChild(new Surface());
		info.style.set("width: 240px; height: 240px; color: white; " ~ 
			"background-color: #000000cf; font-size: 16px");		
	}
	
	override void mouseDown(byte buttons, Vec2i coordinates, char[] href=null)
	{	super.mouseDown(buttons, coordinates, href);
		grabMouse(!getGrabbedMouse());
	};
	
	override void mouseMove(byte buttons, Vec2i rel, char[] href=null) 
	{	super.mouseMove(buttons, rel, href);		
		if (getGrabbedMouse())
			scene.getCamera().rotation += Vec2f(rel.x, rel.y);
	};
	
	override void keyDown(int key, int modifier) 
	{	super.keyDown(key, modifier);
		scene.keyState(key, true);
		
		if (key == SDLK_ESCAPE)
			System.abort("Yage aborted by esc key press.");
	};
	
	override void keyUp(int key, int modifier) 
	{	super.keyDown(key, modifier);
		scene.keyState(key, false);
	};
}

void main()
{	
	// Initialize and create window
	System.init(); 
	auto window = Window.getInstance();
	window.setResolution(720, 445, 0, false, 1); // golden ratio
	ResourceManager.addPath(["../res/", "../res/shader", "../res/gui/font"]);

	// Create and start a Scene
	auto scene = new LotsOfObjects();
	scene.play(); // start scene thread
	
	// User interface
	UI ui = new UI(scene);
	
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
		char[] profiling = Profile.getTimesAndClear().substitute("\n", "<br/>");
		if (frame.tell()>=1f)
		{	float framerate = fps/frame.tell();
			window.setCaption(format("Yage Integration Tests | %s fps\0", framerate));
			ui.info.text = format(
				`%s <b>fps</span><br/>`
				`%s <b>objects</b><br/>`
				`%s <b>polygons</b><br/>`
				`%s <b>vertices</b><br/>`,
				framerate, stats.nodeCount, stats.triangleCount, stats.vertexCount) ~
				profiling;
			
			frame.seek(0);
			fps = 0;
		}
		
		//Thread.getThis().sleep(0.01);
		//Thread.getThis().yield();
	}
	System.deInit();
}