
module unittests.demo.main;

import tango.core.Thread;
import yage.all;

class DemoScene : Scene
{
	this()
	{
		
		
		
	}	
}

class FPSCamera : MovableNode
{
	CameraNode camera;
	
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
}

void main()
{
	
	System.init(); 
	auto window = Window.getInstance();
	window.setResolution(720, 445, 0, false, 1); // golden ratio
	ResourceManager.addPath(["../res/", "../res/shader", "../res/gui/font"]);

	// Create and start a Scene
	Log.info("Starting update loop.");
	auto scene = new DemoScene();
	scene.backgroundColor = "white";
	scene.play(); // update 60 times per second
	
	//auto skyBox = new Scene();
	//skyBox.addChild(new ModelNode("sky/sanctuary.dae"));
	//scene.skyBox = skyBox;
	
	auto camera = scene.addChild(new FPSCamera());
	
	// large ground
	auto plane = scene.addChild(new ModelNode(Geometry.getPlane()));	
	plane.setPosition(Vec3f(0, -2, 0)); // BUG:  setting it more negative makes the ground disappear.
	plane.setRotation(Vec3f(-3.1415927f/2, 0, 0));
	plane.setScale(Vec3f(1000));
	plane.getModel().getMeshes()[0].getMaterial().getPass().textures ~= Texture(ResourceManager.texture("space/rocky2.jpg"));
	
	
	// User interface
	Surface view = new Surface();
	Surface info = view.addChild(new Surface());
	info.style = Style("width: 200px; height: 100px; color: white; " ~ 
		"background-color: #0000007f; font-size: 16px");
	
	view.onMouseMove = delegate bool (Surface self, byte buttons, Vec2i rel, char[] href) {		
		Log.info("onMouseMove");
		Vec2f orientation = camera.getOrientation;
		orientation += Vec2f(rel.x/64f, rel.y/64f); // broken!
		camera.setOrientation(orientation);
		return true; // don't propagate
	};
	
	
	int fps = 0;
	Timer frame = new Timer();
	Log.info("Starting rendering loop.");
	GC.collect();
	
	// Rendering loop
	while(!System.isAborted())
	{
		Input.processAndSendTo(view);
		auto stats = Render.scene(camera.camera, window);
		Render.surface(view, window);
		Render.complete(); // swap buffers
		
		// Print framerate
		fps++;
		if (frame.tell()>=1f)
		{	float framerate = fps/frame.tell();
			window.setCaption(format("Yage System Tests | %s fps\0", framerate));
			info.text = format(
				`%s <b>fps</span><br/>`
				`%s <b>objects</b><br/>`
				`%s <b>polygons</b><br/>`
				`%s <b>vertices</b>`,
				framerate, stats.nodeCount, stats.triangleCount, stats.vertexCount);
			frame.seek(0);
			fps = 0;
		}
		
		//Thread.getThis().yield();
	}
	
}