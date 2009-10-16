/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty:   none
 *
 * This module is not part of the engine, but merely uses it.
 * This is minimal code to launch yage and draw something.
 */

module demo2.main;

import tango.text.convert.Format;
import tango.io.Stdout;
import derelict.sdl.sdl;
import yage.all;

import derelict.opengl.gl;
import derelict.opengl.glext;

// program entry point.
int main()
{
	// Init and create window
	System.init(); 
	auto window = Window.getInstance();
	window.setResolution(720, 445, 0, false, 1); // golden ratio
	ResourceManager.addPath(["../res/", "../res/shader", "../res/gui/font"]);

	// Create and start a Scene
	Scene scene = new Scene();
	scene.play();
	scene.backgroundColor = "green";
	
	// Ship
	auto ship = scene.addChild(new ModelNode());
	ship.setModel("scifi/fighter.ms3d");
	ship.setAngularVelocity(Vec3f(0, 1, 0));

	// Camera
	auto camera = scene.addChild(new CameraNode());
	camera.setPosition(Vec3f(0, 5, 30));
	
	// Main surface
	auto view = new Surface();
	
	// Events for main surface.
	bool grabbed = true;
	view.onKeyDown = delegate void(Surface self, int key, int modifier){
		if (key == SDLK_ESCAPE)
			System.abort("Yage aborted by esc key press.");
		if (key == SDLK_c)
			new GPUTexture("../res/fx/flare1.jpg"); // This proves that the LazyResource queue doesn't work yet!
	};
	view.onMouseDown = delegate void(Surface self, byte buttons, Vec2i coordinates) {
		grabbed = !grabbed;
		if (grabbed)
			self.grabMouse();
		else
			self.releaseMouse();		
	};
	
	// Lights
	auto l1 = scene.addChild(new LightNode());
	l1.setPosition(Vec3f(0, 300, -300));
	

	// For Testing
	auto info = view.addChild(new Surface());
	info.style.set("top: 40px; left: 40px; width: 500px; height: 260px; padding: 3px; color: brown; " ~
		"border-width: 5px; border-image: url('gui/skin/clear2.png'); " ~
		"font-family: url('gui/font/Vera.ttf'); font-size: 14px; text-align: right; opacity: .8");
	
	info.onMouseDown = delegate void(Surface self, byte buttons, Vec2i coordinates){
		self.raise();
		self.focus();
	};
	info.onMouseMove = delegate void(Surface self, byte buttons, Vec2i amount) {
		if(buttons == 1) 
			self.move(cast(Vec2f)amount, true);
	};
	info.onMouseUp = delegate void(Surface self, byte buttons, Vec2i coordinates) {
		self.blur();
	};
	info.onMouseOver = delegate void(Surface self, byte buttons, Vec2i coordinates) {
		self.style.set("border-image: url('gui/skin/clear3.png')");
	};
	info.onMouseOut = delegate void(Surface self, byte buttons, Vec2i coordinates) {
		self.style.set("border-image: url('gui/skin/clear2.png')");
	};

	info.style.transform = Matrix().scale(Vec3f(.5, .5, .5));
	
	// Rendering / Input Loop
	int fps = 0;
	Timer frame = new Timer();
	while(!System.isAborted())
	{		
		Input.processAndSendTo(view);
		auto stats = Render.scene(camera, window);
		Render.surface(view, window);
		Render.complete(); // swap buffers
		
		// Print framerate
		fps++;
		info.style.transform = info.style.transform.move(Vec3f(-40, -40, 0));
		info.style.transform *= Matrix().rotate(Vec3f(0, 0.0005, 0.0005));
		info.style.transform = info.style.transform.move(Vec3f(40, 40, 0));
		
		
		if (frame.tell()>=0.25f)
		{	
			info.text = `In a <s>traditional</s> <span style="color: green; text-decoration: overline; font-size:40px">`~
			`<u>M</u>a<s>nua</s>l <u style="font-size: 18px">printing</u></span> (letterpress) `~
			`<span style="text-decoration: overline">house</span> the font would refer to a complete set of metal `~
			`type that <b>would be used</b> to type-set an entire page. Unlike a digital typeface it would not `~
			`include a single definition of each character, but commonly used characters (such as vowels and periods) `~
			`would have more <i>physical type-pieces included. A <b>font <i style="font-style: normal">when</i> bought</b> new would often be sold as `~
			`(for example in a roman alphabet) 12pt 14A 34a, meaning that it would be a <span style="font-size: 30px">size</span> 12pt fount containing `~
			`14 upper-case 'A's, and 34 lower-case 'A's.</i> The rest of the characters would be provided in quantities `~
			`appropriate for the language it was required for in order to set a complete page in that language. `~
			`Some metal type required in type-setting, such as varying sizes of inter-word spacing pieces and `~
			`line-width spacers, were not part of a specific font in pre-digital usage, but were separate, `~
			`generic pieces.[1]             `~ Format.convert(` {} fps<br/>`, fps/frame.tell());
			
			frame.seek(0);
			fps = 0;
		}
	}
	
	// Free resources that can't be freed by the garbage collector.
	System.deInit();
	return 0;
}
