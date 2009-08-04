/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:	   Joe Pusderis (deformative0@gmail.com), Eric Poggel
 * License:	   <a href="lgpl.txt">LGPL</a> 
 */

module yage.gui.surface;

import tango.io.Stdout;
import tango.math.IEEE;
import tango.math.Math;
import derelict.sdl.sdl;
import derelict.opengl.gl;
import yage.core.all;
import yage.system.system;
import yage.system.input;
import yage.system.graphics.graphics;
import yage.system.graphics.render;
import yage.resource.texture;
import yage.resource.image;
import yage.resource.material;
import yage.gui.style;
import yage.gui.textlayout;
import yage.gui.surfacegeometry;

/** 
 * Surfaces are similar to HTML DOM elements, including having text inside it, 
 * margin, padding, a border, and a background texture, including textures from a camera. 
 * Surfaces will exist in a hierarchical structure, with each having a parent and an array of children. 
 * Surfacs are positioned relative to their parent. 
 * A style struct defines most of the styles associated with the Surface. */
class Surface : Tree!(Surface)
{	
	Style style;
	char[] text;
	char[] old_text;
	GPUTexture textTexture;
	
	static final Style defaultStyle;
	
	protected static Surface grabbedSurface;
	protected static Surface focusSurface;
	
	/// This is a mirror of SDLMod (SDL's modifier key struct)
	enum ModifierKey
	{	NONE  = 0x0000,
		LSHIFT= 0x0001,
		RSHIFT= 0x0002,
		LCTRL = 0x0040,
		RCTRL = 0x0080,
		LALT  = 0x0100,
		RALT  = 0x0200,
		LMETA = 0x0400,
		RMETA = 0x0800,
		NUM   = 0x1000,
		CAPS  = 0x2000,
		MODE  = 0x4000,
		RESERVED = 0x8000,
		CTRL  = LCTRL | RCTRL,
		SHIFT = LSHIFT | RSHIFT,
		ALT   = LALT | RALT,
		META  = LMETA | RMETA
	};
	
	// internal values
	Vec2f offset;		// pixel distance of the topleft corner from parent's top left, a relative offset
	Vec2f size;			// pixel outer width/height, which includes borders and padding.
	Vec4f border;		// pixel sizes of each border
	Vec4f padding;		// pixel sizes of each padding	
	
	Vec2f offsetAbsolute;		// pixel distance of top left from the window's top left at 0, 0, an absolute offset
	
	bool mouseIn; 		// used to track mouseover/mouseout
	bool _grabbed;	
	bool resize_dirty = true;
	
	SurfaceGeometry geometry;

	/// Callback functions
	// TODO convert these to private and have functions to set them with such names as onBlur()?
	void delegate(Surface self) onBlur; ///
	void delegate(Surface self) onDraw; ///
	void delegate(Surface self) onFocus; ///
	void delegate(Surface self, byte buttons, Vec2i coordinates) onClick; /// unfinished
	void delegate(Surface self, byte buttons, Vec2i coordinates) onDblCick; /// unfinished
	void delegate(Surface self, int key, int modifier) onKeyDown; ///
	void delegate(Surface self, int key, int modifier) onKeyUp; ///
	void delegate(Surface self, byte buttons, Vec2i coordinates) onMouseDown; ///
	void delegate(Surface self, byte buttons, Vec2i coordinates) onMouseUp; ///
	void delegate(Surface self, byte buttons, Vec2i amount) onMouseMove; ///
	void delegate(Surface self, byte buttons, Vec2i coordinates) onMouseOver; ///
	void delegate(Surface self, byte buttons, Vec2i coordinates) onMouseOut; ///
	void delegate(Surface self, Vec2f amount) onResize; ///

	this()
	{	geometry = new SurfaceGeometry();
		updateDimensions();
	}
	
	// Set style dimensions from pixels.
	protected void top(float v)    
	{	style.top    = style.top.unit   == CSSValue.Unit.PERCENT ? 100*v/parentHeight() : v; 
	}
	protected void right(float v)  
	{	style.right  = style.right.unit == CSSValue.Unit.PERCENT ? 100*v/parentWidth() : v; 
	}
	protected void bottom(float v) 
	{	style.bottom = style.bottom.unit== CSSValue.Unit.PERCENT ? 100*v/parentHeight() : v; 
	}	
	protected void left(float v)   
	{	style.left   = style.left.unit  == CSSValue.Unit.PERCENT ? 100*v/parentWidth() : v; 
	}
	protected void width(float v)  
	{	style.width  = style.width.unit == CSSValue.Unit.PERCENT ? 100*v/parentWidth() : v; 
	}
	protected void height(float v) 
	{	style.height = style.height.unit== CSSValue.Unit.PERCENT ? 100*v/parentHeight() : v; 
	}
	// Get dimensions of this Surface's parent in pixels
	protected float parentWidth() { return parent ? parent.width()  : System.getWidth(); }
	protected float parentHeight(){ return parent ? parent.height() : System.getHeight(); }	// ditto	

	
	/**
	 * Get the distance of this surface from its parent's top left corner. */
	float top()
	{	return offset.x;
	}
	float left() /// ditto
	{	return offset.y;
	}
	
	/**
	 * Get the inner-most width/height of the surface.  Just as with CSS, this is the width/height inside the padding. */
	float width() 
	{	return innerWidth() - padding.left - padding.right;
	}	
	float height() /// ditto
	{	return innerHeight() - padding.top - padding.bottom;
	}
	
	/**
	 * Get the width/height of the surface, including the width/height of the padding, but not including the border. */
	float innerWidth()
	{	return outerWidth() - border.left - border.right;
	}
	float innerHeight() /// ditto
	{	return outerHeight() - border.top - border.bottom;
	}
	
	/**
	 * Get the width/height of the surface, including both the padding and the border.
	 * This is the same as the distance from top to bottom and left to right. */
	float outerWidth() 	
	{	return size.x;
	}
	float outerHeight()  /// ditto
	{	return size.y;
	}
	
	/**
	 * Update the internally stored x, y, width, and height based on the style.
	 * This will also update the geometry, recurse through children, and call the resize event if necessary. */
	void updateDimensions()
	{
		Vec2f old_offset = offset;
		Vec2f old_size = size;
		
		// Copy/convert borders and padding to internal pixel values.
		Vec2f parent_size = Vec2f(parentWidth(), parentHeight());
		for (int i=0; i<4; i++)
		{	float scale_by = i%2==0 ? parent_size.y : parent_size.x;			
			padding[i] = style.padding[i].toPx(scale_by, false);
			border[i] = style.borderWidth[i].toPx(scale_by, false);
		}
		
		// Convert style dimensions to pixels.		
		Vec4f style_dimensions = Vec4f(
			style.top.toPx(parent_size.y),
			style.right.toPx(parent_size.x),
			style.bottom.toPx(parent_size.y),
			style.left.toPx(parent_size.x));
		Vec2f style_size = Vec2f( // style size doesn't include borders and padding, but the internal size does.
			style.width.toPx(parent_size.x) + border.left + border.right + padding.left + padding.right, 
			style.height.toPx(parent_size.y) + border.top + border.bottom + padding.top + padding.bottom);
		
		// This loop over xy combines the x/left/right and y/top/bottom calulations into one block of code.
		for (int xy=0; xy<2; xy++)
		{	int topLeft= xy==0 ? 3 : 0; // top or left
			int bottomRight = xy ==0 ? 1 : 2; // bottom or right
			
			// Ensure at least 4 of the 6 style dimensions are set.
			if (isNaN(style_dimensions[topLeft]))
			{	if (isNaN(style_dimensions[bottomRight]))
					style_dimensions[topLeft] = 0;
				if (isNaN(style_size[xy]))
					style_size[xy] = parent_size[xy];			
			}
			
			// Position	
			// Convert CSS style top, left, bottom, right, width, height to internal pixel x, y, width, height.
			// (at this point, at most only one of left/width/right will be NaN)
			if (isNaN(style_dimensions[topLeft])) // left is NaN
			{	size[xy] = style_size[xy];
				offset[xy] = parent_size[xy] - size[xy] - style_dimensions[bottomRight];
			}
			else if (isNaN(style_size.x)) // width is NaN
			{	offset[xy] = style_dimensions[topLeft];
				size[xy] = (parent_size[xy] - style_dimensions[bottomRight]) - offset[xy];
			}
			else // right is NaN
			{	offset[xy] = style_dimensions[topLeft];
				size[xy] = style_size[xy];
			}
		}	
		
		// Calculate absolute offset
		if (parent)
			offsetAbsolute = parent.offsetAbsolute + offset;
		else
			offsetAbsolute = offset;
		
		// If resized
		if (size != old_size)
		{	resize_dirty = true;
			resize(size-old_size); // trigger resize event.
			foreach (c; children)
				c.updateDimensions();
		}
	}
	
	/**
	 * Render this Surface.
	 * When finished, the draw methods of all of this Surface's children are called. 
	 * FIXME: When the surface has a non-integer width or height, the text texture is sometmes not scaled to an 
	 * exact pixel size, which causes some letters to appear slightly thicker.  Adding precision
	 * to the texture matrix doesn't seem to help. */
	void draw()
	{
		updateDimensions();
		if (resize_dirty)
			geometry.setDimensions(Vec2f(width(), height()), border, padding);
		
		// Text
		if (text.length && (text != old_text || resize_dirty))
		{	int font_size = cast(int)style.fontSize.toPx(parentWidth());
			int width = cast(int)width();
			int height = cast(int)height();
			Image textImage = TextLayout.render(text, style, width, height, true); // TODO: Change true to Probe.NextPow2
			if (!textTexture) // create texture on first go
				textTexture = new GPUTexture(textImage, false, false, text, true);
			else
				textTexture.commit(textImage, false, false, text, true);
			textTexture.padding = Vec2i(nextPow2(width)-width, -(nextPow2(height)-height));
			old_text = text;
		}
		
		geometry.setColors(style.backgroundColor, style.borderColor);
		geometry.setMaterials(style.backgroundImage, style.borderCenterImage, style.borderImage, style.borderCornerImage, textTexture);
		
		Graphics.pushMatrix();
		Graphics.translate(offset.x, offset.y, 0);
		Graphics.applyState();
		Render.geometry(geometry);
		
		// Using a z-buffer might make sorting unnecessary.  Tradeoffs?
		if (!children.sorted(true, (Surface s){return s.style.zIndex;} ))
			children.radixSort(true, (Surface s){return s.style.zIndex;} );
		foreach(surf; children)
			surf.draw();
		
		Graphics.popMatrix();
		
		resize_dirty = false;
	}
	
	/**
	 * Render this Surface a rendering target.
	 * TODO: Move this to Window?
	 * Params:
	 *     rt = TODO: Render to this target.*/
	void render(IRenderTarget rt=null) 
	{

		glPushAttrib(0xFFFFFFFF);	// all attribs
		glDisableClientState(GL_NORMAL_ARRAY);
		
		// Setup the viewport in orthogonal mode,
		// with dimensions 0..width, 0..height
		// with 0,0 being at the top left.
		glViewport(0, 0, cast(int)System.size.x, cast(int)System.size.y);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0, System.size.x, System.size.y, 0, -1, 1);
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();
		
		glDisable(GL_DEPTH_TEST);
		glDisable(GL_LIGHTING);		
		
		glEnable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
			
		//This may need to be changed for when people wish to render surfaces individually so the already rendered are not cleared.
		glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
		
		draw();
		
		SDL_GL_SwapBuffers();
		
		glEnableClientState(GL_NORMAL_ARRAY);
		glPopAttrib();
	}
	
	/**
	 * Find the surface at the given coordinates.
	 * Surfaces are ordered by zIndex with higher values appearing on top.
	 * This function recurses through children and will return children, grandchildren, etc. as necessary.
	 * TODO: Add relative argument to allow x and y to be relative to another surface.
	 * Returns: The surface, or self if no surface at the coordinates, or null if coordinates are outside self. */
	Surface findSurface(float x, float y)
	{	if (Vec2f(x, y).inside(offsetAbsolute, offsetAbsolute + size))
		{	// Sort if necessary
			if (!children.sorted(false, (Surface s){return s.style.zIndex;}))
				children.radixSort(false, (Surface s){return s.style.zIndex;});
			
			// Recurse
			foreach(surf; children)
			{	Surface result = surf.findSurface(x, y);
				if (result)
					return result;
			}
			return this;
		}
		return null;
	}
	
	/** 
	 * When a Surface has grabMouse() enabled, the mouse cursor will be hidden this surface alone will receive all mouse input.
	 * This also mouse movement so the mouse can move infinitely without encountering any boundaries.
	 * For example, this is ideal for attaching the mouse to the look direction of a first or third-person camera. 
	 * releaseMouse() undoes the effect. */
	void grabMouse() {
		focus();
		SDL_WM_GrabInput(SDL_GRAB_ON);
		SDL_ShowCursor(false);
		grabbedSurface = this;
	}
	void releaseMouse() /// ditto
	{	SDL_WM_GrabInput(SDL_GRAB_OFF);
		SDL_ShowCursor(true);
		grabbedSurface = null;
	}
	
	/**
	 * Return the Surface that is currently grabbing mouse input, or null if no Surfaces are. */
	static Surface getGrabbedSurface()
	{	return grabbedSurface;		
	}
	
	/**
	 * Set the zIndex of this Surface to one more or less than the highest or lowest of its siblings. */
	void raise()
	{	this.style.zIndex = amax(parent.children, (Surface s){return s.style.zIndex;}).style.zIndex + 1;
	}
	void lower() /// ditto
	{	this.style.zIndex = amin(parent.children, (Surface s){return s.style.zIndex;}).style.zIndex - 1;	
	}
	
	/**
	 * Move this Surface.
	 * This updates the top, left, bottom, and right styles accordingly, maintaining pixels/percent units.
	 * Params:
	 *     amount = Amount to move the surface in pixels.
	 *     constrain = Prevent this surface from going outside the boundaries of its parent.*/
	void move(Vec2f amount, bool constrain=false)
	{	
		// Get top, right, bottom, and left in terms of pixels, or nan.
		Vec2f parent_size = Vec2f(parentWidth(), parentHeight());
		Vec4f dimension;
		for (int i=0; i<4; i++)
		{	int xy = (i+1) % 2;
			float multiplier = i==3 ? 1 : -1;				
			dimension[i] = style.dimension[i].toPx(parent_size[xy]) + amount[xy] * multiplier;
		}
		
		// Set top or left to 0 if they and their opposite are both NaN
		if (isNaN(dimension[0]) && isNaN(dimension[2]))
			dimension[0] = 0;
		if (isNaN(dimension[1]) && isNaN(dimension[3]))
			dimension[3] = 3;
		
		
		for (int i=0; i<4; i++)
		{	
			// Apply constraint
			int xy = (i+1) % 2;
			if (constrain && !isNaN(dimension[i]))
			{	if (dimension[i] < 0)				
					dimension[i] = 0;
				if (dimension[i] + size[xy] > parent_size[xy])
					dimension[i] = parent_size[xy] - size[xy];									
			}
			
			// Apply the movement
			if (style.dimension[i].unit == CSSValue.Unit.PERCENT)
				style.dimension[i].value = dimension[i] / parent_size[xy]*100;
			else
				style.dimension[i].value = dimension[i];
		}
		updateDimensions(); // dragging breaks w/o this.
	}
	
	/**
	 * Give focus to this Surface.  Only one Surface can have focus at a time.
	 * All keyboard/mouse events will be forwarded to the surface that has focus.
	 * If no Surface has focus, they will be given to the one under the mouse cursor.
	 * Also calls the onFocus callback function if set. */
	void focus() {
		Surface oldFocus = Surface.focusSurface;
		if(oldFocus && oldFocus.onBlur)
			oldFocus.onBlur(oldFocus);
		if(onFocus)
			onFocus(this);
		Surface.focusSurface = this;
	}
	
	/**
	 * Release focus from this surface and call the onBlur callback function if set. */
	void blur(){
		if(onBlur)
			onBlur(this);
		Surface.focusSurface = null;
	}
	
	/**
	 * Trigger a keyDown event and call the onKeyDown callback function if set. 
	 * If the onKeyDown function is not set, call the parent's keyDown function. */ 
	void keyDown(dchar key, int mod=ModifierKey.NONE)
	{	if(onKeyDown)
			onKeyDown(this, key, mod);
		else if(parent !is null) 
			parent.keyDown(key, mod);
	}
	
	/**
	 * Trigger a keyUp event and call the onKeyUp callback function if set. 
	 * If the onKeyUp function is not set, call the parent's keyUp function.*/ 
	void keyUp(dchar key, int mod=ModifierKey.NONE)
	{	if(onKeyUp)
			onKeyUp(this, key, mod);
		else if(parent !is null) 
			parent.keyUp(key, mod);
	}

	/**
	 * Trigger a mouseDown event and call the onMouseDown callback function if set. 
	 * If the onMouseDown function is not set, call the parent's mouseDown function.*/ 
	void mouseDown(byte buttons, Vec2i coordinates){ 
		if(onMouseDown)
			onMouseDown(this, buttons, coordinates);
		else if(parent !is null) 
			parent.mouseDown(buttons, coordinates);
	}
	
	/**
	 * Trigger a mouseUp event and call the onMouseUp callback function if set. 
	 * If the onMouseUp function is not set, call the parent's mouseUp function.*/ 
	void mouseUp(byte buttons, Vec2i coordinates){ 
		if(onMouseUp)
			onMouseUp(this, buttons, coordinates);
		else if(parent !is null) 
			parent.mouseUp(buttons, coordinates);
	}
	
	/**
	 * Trigger a mouseOver event and call the onMouseOver callback function if set. */ 
	void mouseOver(byte buttons, Vec2i coordinates){
		if(!mouseIn )
		{	if(parent !is null) 
				parent.mouseOver(buttons, coordinates);			
			mouseIn = true;
			if(onMouseOver) 
				onMouseOver(this, buttons, coordinates);
		}
	}
	
	/**
	 * Trigger a mouseMove event and call the onMouseMove callback function if set. */ 
	void mouseMove(byte buttons, Vec2i amount){
		if(onMouseMove)
			onMouseMove(this, buttons, amount);
		else if(parent !is null) 
			parent.mouseMove(buttons, amount);
	}

	/**
	 * Trigger a mouseOut event and call the onMouseOut callback function if set */ 
	void mouseOut(Surface next, byte buttons, Vec2i coordinates)
	{
		if(mouseIn)
		{	if(isChild(next))
				return;
			else
			{	mouseIn = false;
				if(onMouseOut)
					onMouseOut(this, buttons, coordinates);			
				if(next !is parent && parent !is null)
					parent.mouseOut(next, buttons, coordinates);
			}
		}
	}

	/**
	 * Trigger a resize event and call the onResize callback function if set.
	 * This is called automatically after the resize occurs. */ 
	void resize(Vec2f amount)
	{	if (onResize)
			onResize(this, amount);
	}
}