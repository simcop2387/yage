module demo3.rtscamera;

import tango.math.Math;

import yage.all;

import demo3.gameobj;

class RTSCamera : Node
{
	struct Input
	{	bool up;
		bool right;
		bool down;
		bool left;
		bool shoot;
		bool hyper;
		bool rotate;
		bool altitude;

		Vec2i wheelDelta;
		Vec2f mouseDelta;
	}
	
	//public members for convenience, it's a demo!
	Input input;
	bool hasMouse = false;
	CameraNode camera;

	this()
	{	this.camera = new CameraNode;
		camera.near = 2;
		camera.far = 2000000;
		camera.fov = 60;
		camera.threshold = 1;
		
		this.addChild(camera);
	}

	void keyDown(dchar key)
	{	keyToggle(key, true);	
	}
	void keyUp(dchar key)
	{	keyToggle(key, false);
	}
	
	void keyToggle(dchar key, bool on)
	{
		if (key==SDLK_UP || key==SDLK_w)
			input.up = on;
		if (key==SDLK_LEFT || key==SDLK_a)
			input.left = on;
		if (key==SDLK_RIGHT || key==SDLK_d)
			input.right = on;
		if (key==SDLK_DOWN || key==SDLK_s)
			input.down = on;
		if (key==SDLK_SPACE)
			input.shoot = on;
		if (key==SDLK_q)
			input.hyper = on;
	}

	/* The "action" function called in the engine loop */
	override void update(float delta)
	{	super.update(delta);

		// Set the acceleration speed
		float speed = 500*delta;

		// Move in the (x,y) plan according to keystrokes
		if (input.up)
			move(Vec3f(0, speed, 0).rotate(getTransform()));
		if (input.left)
			move(Vec3f(-speed, 0, 0).rotate(getTransform()));
		if (input.right)
			move(Vec3f(speed, 0, 0).rotate(getTransform()));
		if (input.down)
			move(Vec3f(0, -speed,0).rotate(getTransform()));

		// Action upon mouse input
		if (input.rotate)
		{	//rotate right and left
			rotate(Vec3f(0, 0, - input.mouseDelta.x/16.0));

			//rotate up and down
			camera.rotate(Vec3f(-input.mouseDelta.y/16.0, 0, 0));
			if (camera.getRotation().x > 2)
			{	camera.setRotation(Vec3f(PI/2, 0, 0));
			}
			if (camera.getRotation().x < 0)
			{	camera.setRotation(Vec3f(0, 0, 0));
			}
		}
		if (input.altitude)
		{	camera.move(Vec3f(0, 0, -input.mouseDelta.y/4.0));
		}
		input.mouseDelta.x = input.mouseDelta.y = 0;

		if (input.shoot)
		{
			Flare flare = this.getScene().addChild(new Flare());
			flare.setPosition(camera.getWorldPosition()+Vec3f(0, 0, -10));
			flare.setVelocity(Vec3f(0, 0, -100).rotate(camera.getWorldTransform())+camera.getVelocity());
		}
	}
}