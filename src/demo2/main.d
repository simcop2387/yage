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
	// Init
	System.init(814, 445, 32, false, 1);
	ResourceManager.addPath(["../res", "../res2"]);

	// Create and start a Scene
	Scene scene = new Scene();
	scene.play();
	scene.backgroundColor = Color("green");
	
	// Ship
	auto ship = scene.addChild(new ModelNode());
	ship.setModel("obj/tie2.obj");
	ship.setAngularVelocity(Vec3f(0, 1, 0));

	// Camera
	auto camera = scene.addChild(new CameraNode());
	camera.setPosition(Vec3f(0, 5, 30));
	
	// Main surface where camera output is rendered.
	auto view = new Surface();
	view.style.backgroundImage = camera.getTexture();
	view.style.set("background-color: red; font-family: url('gui/font/Vera.ttf')");	
	System.setSurface(view);
	
	// Events for main surface.
	bool grabbed = true;
	view.onKeyDown = delegate void (Surface self, int key, int modifier){
		if (key == SDLK_ESCAPE)
			System.abort("Yage aborted by esc key press.");
		if (key == SDLK_c)
			new GPUTexture("../res/fx/flare1.jpg"); // This proves that the LazyResource queue doesn't work yet!
	};
	view.onMouseDown = delegate void (Surface self, byte buttons, Vec2i coordinates) {
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
	auto window = view.addChild(new Surface());
	window.style.set("top: 5px; left: 5px; width: 500px; height: 260px; padding: 3px; color: brown; " ~
		"border-width: 5px; border-image: url('gui/skin/clear2.png'); " ~
		"font-family: url('gui/font/Vera.ttf'); font-size: 14px; text-align: right; opacity: .8");
	
	window.onMouseDown = (Surface self, byte buttons, Vec2i coordinates){
		self.raise();
		self.focus();
	};
	window.onMouseMove = (Surface self, byte buttons, Vec2i amount) {
		if(buttons == 1) 
			self.move(cast(Vec2f)amount, true);
	};
	window.onMouseUp = (Surface self, byte buttons, Vec2i coordinates) {
		self.blur();
	};
	window.onMouseOver = (Surface self, byte buttons, Vec2i coordinates) {
		self.style.set("border-image: url('gui/skin/clear3.png')");
	};
	window.onMouseOut = (Surface self, byte buttons, Vec2i coordinates) {
		self.style.set("border-image: url('gui/skin/clear2.png')");
	};
	
	// Rendering / Input Loop
	int fps = 0;
	Timer frame = new Timer();
	while(!System.isAborted())
	{		
		Input.processInput();
		scene.swapTransformRead(); // swap scene buffer so the latest version can be rendered.
		camera.toTexture();
		view.render();
		
		// Print framerate
		fps++;
		
		if (frame.get()>=0.25f)
		{	
			window.text = `In a <s>traditional</s> <span style="color: green; text-decoration: overline; font-size:40px">`~
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
			`generic pieces.[1]             `~ Format.convert(` {} fps<br/>`, fps/frame.get());
			
			//window.text = Format.convert(`{} fps<br/>{}`,
			//	fps/frame.get());
			//window.text = Format.convert(`<span style="color: white">{}</span> fps`, fps/frame.get());
			frame.reset();
			fps = 0;	
			//break;
		}
	}
	
	// Free resources that can't be freed by the garbage collector.
	System.deInit();
	return 0;
}
