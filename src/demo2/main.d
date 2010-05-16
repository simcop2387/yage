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
import tango.io.device.File;
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
	window.setCaption("Yage Demo 2");
	window.setResolution(720, 445, 0, false, 1); // golden ratio
	ResourceManager.addPath(["../res/", "../res/shader", "../res/gui/font"]);

	// Create and start a Scene
	Scene scene = new Scene();
	scene.play();
	scene.backgroundColor = "green";
	
	// Ship	
	auto ship = scene.addChild(new ModelNode());
	ship.setModel("space/fighter.dae");
	ship.setAngularVelocity(Vec3f(0, 1, 0));
	ship.setScale(Vec3f(1));

	// Camera
	auto camera = scene.addChild(new CameraNode());
	camera.setPosition(Vec3f(0, 5, 30));
	
	// Main surface
	auto view = new Surface();
	
	// Events for main surface.
	view.onKeyDown = delegate bool(Surface self, int key, int modifier){
		if (key == SDLK_ESCAPE)
			System.abort("Yage aborted by esc key press.");
		return true;
	};
	view.onMouseDown = delegate bool(Surface self, byte buttons, Vec2i coordinates, char[] href) {
		self.grabMouse(!self.getGrabbedMouse());
		return true;
	};
	
	// Lights
	auto l1 = scene.addChild(new LightNode());
	l1.setPosition(Vec3f(0, 200, -30));	

	// For Testing
	auto info = view.addChild(new Surface());
	info.style.set("top: 40px; left: 40px; width: 500px; height: 260px; padding: 3px; color: brown; " ~
		"border-width: 5px; border-image: url('gui/skin/clear2.png'); " ~
		"font: 14px url('Vera.ttf'); text-align: right; opacity: .8; overflow: hidden");
	info.style.overflowX = Style.Overflow.HIDDEN;
	info.style.overflowY = Style.Overflow.HIDDEN;
	
	info.onMouseDown = delegate bool(Surface self, byte buttons, Vec2i coordinates, char[] href){
		self.raise();
		self.focus();
		return true;
	};
	info.onMouseMove = delegate bool(Surface self, byte buttons, Vec2i amount, char[] href) {
		if(buttons == 1) 
			self.move(cast(Vec2f)amount, true);
		return true;
	};
	info.onMouseUp = delegate bool(Surface self, byte buttons, Vec2i coordinates, char[] href) {
		self.blur();
		return true;
	};
	info.onMouseOver = delegate bool(Surface self, byte buttons, Vec2i coordinates) {
		self.style.set("border-image: url('gui/skin/clear3.png')");
		return true;
	};
	info.onMouseOut = delegate bool(Surface self, byte buttons, Vec2i coordinates) {
		self.style.set("border-image: url('gui/skin/clear2.png')");
		return true;
	};
	//info.style.transform = Matrix().scale(Vec3f(.5, .5, .5));
	
	auto clip = info.addChild(new Surface());
	clip.style.set("width: 60px; height: 60px; background-color: black; top: -30px; left: -30px; overflow: hidden");
	
	auto clip2 = clip.addChild(new Surface());
	clip2.style.set("width: 30px; height: 30px; background-color: blue; top: 15px; left: 45px");
	
	auto clip3 = info.addChild(new Surface());
	clip3.style.set("width: 60px; height: 60px; background-color: orange; top: -30px; right: -30px");
	
	
	
	// Rendering / Input Loop
	int fps = 0;
	Timer frame = new Timer(true);
	while(!System.isAborted())
	{		
		Input.processAndSendTo(view);
		auto stats = Render.scene(camera, window);
		Render.surface(view, window);

		Render.complete(); // swap buffers
		
		// Print framerate
		fps++;
		//info.style.transform = info.style.transform.move(Vec3f(-40, -40, 0));
		//info.style.transform *= Matrix().rotate(Vec3f(0, 0.0005, 0.0005));
		//info.style.transform = info.style.transform.move(Vec3f(40, 40, 0));
		
		
		if (frame.tell()>=1f)
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
