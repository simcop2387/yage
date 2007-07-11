/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Joe Pusderis (deformative0@gmail.com)
 * License:    <a href="lgpl.txt">LGPL</a> 
 */

module yage.gui.surface;

import std.stdio;
import derelict.opengl.gl;
import derelict.sdl.sdl;
import yage.core.all;
import yage.system.device;
import yage.system.constant;
import yage.resource.texture;
import yage.gui.style;


/** 
 * A surface will be similar to an HTML DOM element, including having text inside it, 
 * margin, padding, a border, and a background texture, including textures from a camera. 
 * Surfaces will exist in a hierarchical structure, with each having a parent and an array of children. 
 * The children will be positioned relative to the borders of their parent. */
class Surface{
	static final Style defaultStyle;
	Style style;
	
	//Style style;  //move style into a higher level clas, perhaps make a geometry struct isntead
	GPUTexture texture;  //Change from GPUTexture to Texture or Material
	
	//Linked list would be faster for raising a window.
	Surface[] subs;//Perhaps this should be changed into a linked list...
	//Not sure if I should have a reference to Parent or not, but for now, I will.
	Surface parent;
	
	Vec2f portion; //used for the texture only
	
	Vec2f topLeft;
	Vec2f bottomRight;
	
	//these are used for rendering, not calculation
	Vec2i position1;
	Vec2i position2;
	
	
	Vec2i size;
	
	bool visible;


	//add root position and stuff
	
	//Not sure how to impelement gluUnProject
	
	void delegate(typeof(this) self) onBlur;
	void blur(){ if(onBlur)onBlur(this);}

	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onClick;

	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onDblclick;

	void delegate(typeof(this) self) onFocus;

	void delegate(typeof(this) self, byte key, byte modifiers) onKeydown;

	void delegate(typeof(this) self, byte key, byte modifiers) onKeypress;

	void delegate(typeof(this) self, byte key, byte modifiers) onKeyup;

	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onMousedown;
	void mousedown(byte buttons, Vec2i coordinates){ if(onMousedown)onMousedown(this, buttons, coordinates);}

	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onMousemove;
	void mousemove(byte buttons, Vec2i coordinates){ if(onMousemove)onMousemove(this, buttons, coordinates);}

	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onMouseout;

	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onMouseover;

	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onMouseup;
	void mouseup(byte buttons, Vec2i coordinates){ if(onMouseup)onMouseup(this, buttons, coordinates);}

	void delegate(typeof(this) self, Vec2i difference) onResize;
	
	
	this(Surface p){
		parent = p;
		if(parent is null){
			Device.subs ~= this;
			recalculate(Device.getHeight(), Device.getWidth());
		}
		else{
			parent.subs ~= this;
			recalculate(parent.size.x, parent.size.y);
		}
	}
	
	void setTexture(GPUTexture tex){
		texture = tex;
		recalculateTexture();
	}
	
	void recalculate(int width, int height){ //not done
		position1.x = cast(int)(topLeft.x * cast(float)width);
		position1.y = cast(int)(topLeft.y * cast(float)height);
		
		position2.x = cast(int)(bottomRight.x * cast(float)width);
		position2.y = cast(int)(bottomRight.y * cast(float)height);
		
		Vec2i temp = size;
		
		size.x = position2.x - position1.x;
		size.y = position2.y - position1.y;
		
		if(onResize)onResize(this, Vec2i(temp.x - size.x, temp.y - size.y));
		
		foreach(sub ;this.subs)
			sub.recalculate(size.x, size.y);
	}
	
	void recalculate(){
		if(parent == null)
			recalculate(Device.width, Device.height);
		else
			recalculate(parent.size.x, parent.size.y);
	}
	
	void recalculateTexture(){
		portion.x = texture.requested_width/cast(float)texture.getWidth();
		portion.y = texture.requested_height/cast(float)texture.getHeight();
	}
	
	void render(){
		glPushAttrib(0xFFFFFFFF);	// all attribs
		
		// Setup the viewport in orthogonal mode,
		// with dimensions 0..width, 0..height
		// with 0,0 being at the top left.
		glViewport(0, 0, Device.width, Device.height);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0, Device.width, Device.height, 0, -1, 1);
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		
		glDisable(GL_DEPTH_TEST);
		glDisable(GL_LIGHTING);
		
		glEnable(GL_TEXTURE_2D);
		
		//This may need to be changed for when people wish to render surfaces individually so the already rendered are not cleared.
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		
		draw();
		
		SDL_GL_SwapBuffers();
		
		glPopAttrib();
	}
	
	void draw(){
		if(visible){
			if (texture !is null){
				recalculateTexture();
				// Draw a textured quad of our current material
				Texture(texture, true, TEXTURE_FILTER_BILINEAR).bind();
		
				glBegin(GL_QUADS);

				glTexCoord2f(0, 0);
				glVertex2i(position1.x, position2.y);
				
				glTexCoord2f(portion.x, 0);
				glVertex2i(position2.x, position2.y);
				
				glTexCoord2f(portion.x, portion.y); 
				glVertex2i(position2.x, position1.y);

				glTexCoord2f(0, portion.y);
				glVertex2i(position1.x, position1.y);

				glEnd();
			}
			
			// Sort subs
			if (!subs.ordered(true, (Surface s){return s.style.zIndex;} ))
				subs.radixSort((Surface s){return s.style.zIndex;} );			
			
			foreach(sub; subs)
				sub.draw();
		}
	}
	
	void setVisibility(bool v){
		visible = v;
	}
	
	void raise(){ //Could be cleaner, whatever, I'll fix it later
		if(parent is null){
			uint index = findIndex(this, Device.subs);
			for(; index < Device.subs.length - 1; index++)
				Device.subs[index] = Device.subs[index+1];
			Device.subs[$] = this;
		}
		else{
			uint index = findIndex(this, parent.subs);
			for(; index < parent.subs.length - 1; index++)
				parent.subs[index] = parent.subs[index+1];
			parent.subs[$-1] = this;
		}
	}
}

Surface findSurface(int x, int y){
	foreach_reverse(sub; Device.subs){
		if(sub.position1.x <= x && x <= sub.position2.x && sub.position1.y <= y && y <= sub.position2.y){
			return findSurface(sub, x, y);
		}
	}
	return null;
}

Surface findSurface(Surface surface,int x, int y){
	foreach_reverse(sub; surface.subs){
		if(sub.position1.x <= x && x <= sub.position2.x && sub.position1.y <= y && y <= sub.position2.y){
			return findSurface(sub, x, y);
		}
	}
	return surface;
}

uint findIndex(Surface surface, Surface[] array){ //perhaps put into a template
	foreach(uint index, Surface current; array){
		if(current == surface) return  index;
	}
	return 1 << 8;
}