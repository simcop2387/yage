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
import yage.system.input;
import yage.resource.texture;
import yage.gui.style;


//move to constants
enum{
	traditional, //default
	stretched,
	tiled
}

float third = 1.0/3.0;

/** 
 * Surfaces are similar to HTML DOM elements, including having text inside it, 
 * margin, padding, a border, and a background texture, including textures from a camera. 
 * Surfaces will exist in a hierarchical structure, with each having a parent and an array of children. 
 * Surfacs are positioned relative to their parent. 
 * A style struct defines most of the styles associated with the Surface. */
class Surface{
	static final Style defaultStyle;
	Style style;
	
	//Change from GPUTexture to Texture or Material
	protected GPUTexture texture;
	
	Surface parent;
	Surface[] children;
	//Not sure if I should have a reference to Parent or not, but for now, I will.
	
	
	Vec2f topLeft;//rid self of these
	Vec2f bottomRight;
	
	//these are calculated, not for calculating
	Vec2i position1;
	Vec2i position2;
	Vec2i size;
	
	//these are for calculating
	protected Vec2i locationAdd;
	
	//used for the texture
	Vec2f portion;
	
	bool visible;
	bool mouseIn;
	
	byte fill = traditional;
	
	//Not sure how to impelement gluUnProject
	
	//Perhaps add some of these for global events.
	void delegate(typeof(this) self) onBlur;
	
	//dunno how
	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onClick;

	//dunno how
	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onDblclick;

	void delegate(typeof(this) self) onFocus; //Done -- See Raise, no fall through

	void delegate(typeof(this) self, byte key) onKeydown;
	void keydown(byte key){
		if(onKeydown)onKeydown(this, key);
		else if(parent !is null) parent.keydown(key);
	}
	
	void delegate(typeof(this) self, byte key, byte modifiers) onKeypress; //Why is this here when we have down?
	
	void delegate(typeof(this) self, byte key) onKeyup;
	void keyup(byte key){
		if(onKeyup)onKeyup(this, key);
		else if(parent !is null) parent.keyup(key);
	}

	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onMousedown; //Done
	void mousedown(byte buttons, Vec2i coordinates){ 
		if(onMousedown)onMousedown(this, buttons, coordinates);
		else if(parent !is null) parent.mousedown(buttons, coordinates);
	}

	void delegate(typeof(this) self, byte buttons, Vec2i rel) onMousemove; //Done
	void mousemove(byte buttons, Vec2i rel){
		if(onMousemove)onMousemove(this, buttons, rel);
		else if(parent !is null) parent.mousemove(buttons, rel);
	}

	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onMouseleave;
	void mouseleave(Surface next, byte buttons, Vec2i coordinates){
		if(mouseIn == true){
			if(isSub(next))
				return;
			else{
				mouseIn = false;
				if(onMouseleave)
					onMouseleave(this, buttons, coordinates);
			
				if(next !is parent && parent !is null)
					parent.mouseleave(next, buttons, coordinates);
			}
		}
	}
	
	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onMouseenter;
	void mouseenter(byte buttons, Vec2i coordinates){
		if(mouseIn == false){
			if(parent !is null) parent.mouseenter(buttons, coordinates);
			
			mouseIn = true;
			if(onMouseenter) onMouseenter(this, buttons, coordinates);
		}
	}
	
	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onMouseup; //Done
	void mouseup(byte buttons, Vec2i coordinates){ 
		if(onMouseup)onMouseup(this, buttons, coordinates);
		else if(parent !is null) parent.mouseup(buttons, coordinates);
	}

	void delegate(typeof(this) self) onResize; //Done -- See recalculate, no fall through
	
	
	this(Surface p){
		parent = p;
		if(parent is null){
			Device.children ~= this;
			this.recalculate();
		}
		else{
			parent.children ~= this;
			this.recalculate();
		}
	}
	
	void setTexture(GPUTexture tex){
		texture = tex;
		recalculateTexture();
	}
	
	void recalculate(Vec2i parent1, Vec2i parent2, Vec2i parentSize, bool doSubs = true){ //not done
		
		position1.x = cast(int)(topLeft.x * cast(float)parentSize.x) + parent1.x + locationAdd.x;
		position1.y = cast(int)(topLeft.y * cast(float)parentSize.y) + parent1.y + locationAdd.y;
		
		position2.x = parent2.x - cast(int)((1.0 - bottomRight.x) * cast(float)parentSize.x) + locationAdd.x;
		position2.y = parent2.y - cast(int)((1.0 - bottomRight.y) * cast(float)parentSize.y) + locationAdd.y;
		
		size.x = position2.x - position1.x;
		size.y = position2.y - position1.y;
		
		if(onResize)onResize(this);
		
		if(doSubs)
			recalculateSubs();
	}
	
	private void recalculateSubs(){
		foreach(sub; this.children)
			sub.recalculate(position1, position2, size);
	}
	
	void recalculate(bool doSubs = true){
		if(parent is null){
			recalculate(Vec2i(0,0), Device.size, Device.size, doSubs);
		}
		else
			recalculate(parent.position1, parent.position2, parent.size, doSubs);
	}
	
	void startDrag(){
		lock();
	}
	
	void drag(Vec2i add){
		locationAdd.x += add.x;
		locationAdd.y += add.y;
		
		
		recalculate(false);
		
		
		//All of the below is for not going out of boundry
		if(parent is null){
 			recalculateSubs();
 			return;
		}
		
		if(position1.x < parent.position1.x){
			position1.x = parent.position1.x;
			position2.x = position1.x + size.x;
		}
		else if(position2.x > parent.position2.x){
 			position2.x = parent.position2.x;
 			position1.x = position2.x - size.x;
		}
		
		if(position1.y < parent.position1.y){
			position1.y = parent.position1.y;
			position2.y = position1.y + size.y;
		}
		else if(position2.y > parent.position2.y){
			position2.y = parent.position2.y;
			position1.y = position2.y - size.y;
		}
		
		recalculateSubs();
	}
	
	void endDrag(){
		recalculate(false);
		if(parent is null) goto after;
		
		
		if(position1.x < parent.position1.x)
			locationAdd.x += parent.position1.x - position1.x;
		else if(position2.x > parent.position2.x)
			locationAdd.x -= position2.x - parent.position2.x;
		
		
		if(position1.y < parent.position1.y)
			locationAdd.y += parent.position1.y - position1.y;
		else if(position2.y > parent.position2.y)
			locationAdd.y -= position2.y - parent.position2.y;
		
		recalculate(false);
		after:
		unlock();
	}
	
	//I would like textures to automatically do this so that it doesn't need to happen for every single surface on every single frame
	void recalculateTexture(){  //Dunno if this will be needed when we change to materials
		portion.x = texture.requested_width/cast(float)texture.getWidth();
		portion.y = texture.requested_height/cast(float)texture.getHeight();
	}
	
	void render(){
		glPushAttrib(0xFFFFFFFF);	// all attribs
		
		// Setup the viewport in orthogonal mode,
		// with dimensions 0..width, 0..height
		// with 0,0 being at the top left.
		glViewport(0, 0, Device.size.x, Device.size.y);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0, Device.size.x, Device.size.y, 0, -1, 1);
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		
		glDisable(GL_DEPTH_TEST);
		glDisable(GL_LIGHTING);
		
		glEnable(GL_BLEND);
 		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
 		//glColor4f(1, 1, 1, 1);
		
		
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
				
				switch(fill){
					case traditional:
						glTexCoord2f(0, 0);
						glVertex2i(position1.x, position2.y);
						
						glTexCoord2f(portion.x, 0);
						glVertex2i(position2.x, position2.y);
						
						glTexCoord2f(portion.x, portion.y); 
						glVertex2i(position2.x, position1.y);
		
						glTexCoord2f(0, portion.y);
						glVertex2i(position1.x, position1.y);
						break;
					case stretched: //Move calculations somwhere else!
						//Not sure about the difference between /3 and *third, but who cares, I used *third
						float partx = portion.x * third;
						float party = portion.y * third;
						
						float partytimes2 = party * 2;
						float partxtimes2 = partx * 2;
						
						int w = cast(int)(texture.requested_width * third);
						int h = cast(int)(texture.requested_height * third);
						
						int partwidth = position1.x + w;
						int partheight = position1.y + h;
						
						int partwidthminus = position2.x - w;
						int partheightminus = position2.y - h;
						
						/*
						* topleft
						*/
						glTexCoord2f(0, party);
						glVertex2i(position1.x, partheight);
						
						glTexCoord2f(partx, party);
						glVertex2i(partwidth, partheight);
						
						glTexCoord2f(partx, 0); 
						glVertex2i(partwidth, position1.y);
		
						glTexCoord2f(0, 0);
						glVertex2i(position1.x, position1.y);
	
						
						/*
						* left
						*/
						glTexCoord2f(0, partytimes2);
						glVertex2i(position1.x, partheightminus);
						
						glTexCoord2f(partx, partytimes2);
						glVertex2i(partwidth, partheightminus);
						
						glTexCoord2f(partx, party); 
						glVertex2i(partwidth, partheight);
		
						glTexCoord2f(0, party);
						glVertex2i(position1.x, partheight);
	
	
						/*
						* bottomleft
						*/
						glTexCoord2f(0, portion.y);
						glVertex2i(position1.x, position2.y);
						
						glTexCoord2f(partx, portion.y);
						glVertex2i(partwidth, position2.y);
						
						glTexCoord2f(partx, partytimes2); 
						glVertex2i(partwidth, partheightminus);
		
						glTexCoord2f(0, partytimes2);
						glVertex2i(position1.x, partheightminus);
	
	
						/*
						* top
						*/
						glTexCoord2f(partx, party);
						glVertex2i(partwidth, partheight);
						
						glTexCoord2f(partxtimes2, party);
						glVertex2i(partwidthminus, partheight);
						
						glTexCoord2f(partxtimes2, 0); 
						glVertex2i(partwidthminus, position1.y);
		
						glTexCoord2f(partx, 0);
						glVertex2i(partwidth, position1.y);
	
	
						/*
						* middle
						*/
						glTexCoord2f(partx, partytimes2);
						glVertex2i(partwidth, partheightminus);
						
						glTexCoord2f(partxtimes2, partytimes2);
						glVertex2i(partwidthminus, partheightminus);
						
						glTexCoord2f(partxtimes2, party); 
						glVertex2i(partwidthminus, partheight);
		
						glTexCoord2f(partx, party);
						glVertex2i(partwidth, partheight);
	
	
						/*
						* bottom
						*/
						glTexCoord2f(partx, portion.y);
						glVertex2i(partwidth, position2.y);
						
						glTexCoord2f(partxtimes2, portion.y);
						glVertex2i(partwidthminus, position2.y);
						
						glTexCoord2f(partxtimes2, partytimes2); 
						glVertex2i(partwidthminus, partheightminus);
		
						glTexCoord2f(partx, partytimes2);
						glVertex2i(partwidth, partheightminus);
	
	
						/*
						* topright
						*/
						glTexCoord2f(partxtimes2, party);
						glVertex2i(partwidthminus, partheight);
						
						glTexCoord2f(portion.x, party);
						glVertex2i(position2.x, partheight);
						
						glTexCoord2f(portion.x, 0); 
						glVertex2i(position2.x, position1.y);
		
						glTexCoord2f(partxtimes2, 0);
						glVertex2i(partwidthminus, position1.y);
	
	
						/*
						* right
						*/
						glTexCoord2f(partxtimes2, partytimes2);
						glVertex2i(partwidthminus, partheightminus);
						
						glTexCoord2f(portion.x, partytimes2);
						glVertex2i(position2.x, partheightminus);
						
						glTexCoord2f(portion.x, party); 
						glVertex2i(position2.x, partheight);
		
						glTexCoord2f(partxtimes2, party);
						glVertex2i(partwidthminus, partheight);
	
						/*
						* bottomright
						*/
						glTexCoord2f(partxtimes2, portion.y);
						glVertex2i(partwidthminus, position2.y);
						
						glTexCoord2f(portion.x, portion.y);
						glVertex2i(position2.x, position2.y);
						
						glTexCoord2f(portion.x, partytimes2); 
						glVertex2i(position2.x, partheightminus);
		
						glTexCoord2f(partxtimes2, partytimes2);
						glVertex2i(partwidthminus, partheightminus);
						break;
					case tiled:
						
						break;
					default:
						writefln("Not a valid fill type");
						//assert(0)
						break;
				}
				glEnd();
			}
			
			//I am clueless about this, so it's commented
			// Sort subs
			//if (!subs.ordered(true, (Surface s){return s.style.zIndex;} ))
			//	subs.radixSort((Surface s){return s.style.zIndex;} );
			
			foreach(sub; children)
				sub.draw();
		}
	}
	
	void setVisibility(bool v){
		visible = v;
	}
	
	void raise(){ //Could be cleaner, whatever, I'll fix it later
		if(parent is null){
			uint index = findIndex(this, Device.children);
			for(; index < Device.children.length - 1; index++)
				Device.children[index] = Device.children[index+1];
			Device.children[$-1] = this;
		}
		else{
			uint index = findIndex(this, parent.children);
			for(; index < parent.children.length - 1; index++)
				parent.children[index] = parent.children[index+1];
			parent.children[$-1] = this;
		}
		if(onFocus) onFocus(this);
	}
	
	//Events will be forwarded to the locked surface
	void lock(){
		Input.surfaceLock = this;
	}
	
	//Releases the locked surface, now the appropriate surface will recieve events
	void unlock(){
		Input.surfaceLock = null;
	}
	
	/** If enabled, the mousecursor will be hidden and grabbed by the application.
	 *  This also allows for mouse position changes to be registered in a relative fashion,
	 *  i.e. even when the mouse is at the edge of the screen.  This is ideal for attaching
	 *  the mouse to the look direction of a first or third-person camera. */
	void grabMouse(bool grab){
		if (grab){
			lock();
			SDL_WM_GrabInput(SDL_GRAB_ON);
			SDL_ShowCursor(false);
		}
		else{
			unlock();
			SDL_WM_GrabInput(SDL_GRAB_OFF);
			SDL_ShowCursor(true);
		}
		Input.grabbed = grab;
	}
		
	bool isSub(Surface surf){
		foreach(sub; children){
			if (sub == surf) return true;
		}
		return false;
	}
}

//Perhaps put into yage.system.input
//Could be better, a method perhaps...
Surface findSurface(int x, int y){
	foreach_reverse(sub; Device.children){
		if(sub.position1.x <= x && x <= sub.position2.x && sub.position1.y <= y && y <= sub.position2.y){
			return findSurface(sub, x, y);
		}
	}
	return null;
}
//Could be better, a method perhaps...
Surface findSurface(Surface surface,int x, int y){
	foreach_reverse(sub; surface.children){
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
	return 1 << 8;  //Implement this for not in subs
}