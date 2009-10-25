/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:	   Joe Pusderis (deformative0@gmail.com), Eric Poggel
 * License:	   <a href="lgpl3.txt">LGPL v3</a> 
 */

module yage.gui.surface;

import tango.io.Stdout;
import tango.math.IEEE;
import tango.math.Math;
import tango.text.convert.Utf;
import yage.core.all;
import yage.system.system;
import yage.system.input;
import yage.system.log;
import yage.system.graphics.render;
import yage.system.window;
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
	bool editable = true;
	bool mouseChildren = true;
	
	protected char[] old_text;
	protected GPUTexture textTexture;	

	/// Callback functions
	bool delegate(Surface self) onBlur; ///
	bool delegate(Surface self) onDraw; ///
	bool delegate(Surface self) onFocus; ///
	bool delegate(Surface self, byte buttons, Vec2i coordinates) onClick; /// unfinished
	bool delegate(Surface self, byte buttons, Vec2i coordinates) onDblCick; /// unfinished
	bool delegate(Surface self, int key, int modifier) onKeyDown; /// Triggered once when a key is pressed down
	bool delegate(Surface self, int key, int modifier) onKeyUp; /// Triggered once when a key is released
	bool delegate(Surface self, int key, int modifier) onKeyPress; /// Triggered when a key is pressed down and repeats at the key repeat rate.
	bool delegate(Surface self, byte buttons, Vec2i coordinates, char[] href) onMouseDown; ///
	bool delegate(Surface self, byte buttons, Vec2i coordinates, char[] href) onMouseUp; ///
	bool delegate(Surface self, byte buttons, Vec2i amount, char[] href) onMouseMove; ///
	bool delegate(Surface self, byte buttons, Vec2i coordinates) onMouseOver; ///
	bool delegate(Surface self, byte buttons, Vec2i coordinates) onMouseOut; ///
	void delegate(Surface self, Vec2f amount) onResize; ///
	
	/// This is a mirror of SDLMod (SDL's modifier key struct)
	enum ModifierKey
	{	NONE  = 0x0000, /// Allowed values.
		LSHIFT= 0x0001, /// ditto
		RSHIFT= 0x0002, /// ditto
		LCTRL = 0x0040, /// ditto
		RCTRL = 0x0080, /// ditto
		LALT  = 0x0100, /// ditto
		RALT  = 0x0200, /// ditto
		LMETA = 0x0400, /// ditto
		RMETA = 0x0800, /// ditto
		NUM   = 0x1000, /// ditto
		CAPS  = 0x2000, /// ditto
		MODE  = 0x4000, /// ditto
		RESERVED = 0x8000, /// ditto
		CTRL  = LCTRL | RCTRL, /// ditto
		SHIFT = LSHIFT | RSHIFT, /// ditto
		ALT   = LALT | RALT, /// ditto
		META  = LMETA | RMETA /// ditto
	};
	
	// internal values
	protected Vec2f offset;		// pixel distance of the topleft corner from parent's top left, a relative offset
	protected Vec2f size;		// pixel outer width/height, which includes borders and padding.
	public Vec4f border;		// pixel sizes of each border
	protected Vec4f padding;		// pixel sizes of each padding	
	
	public Vec2f offsetAbsolute;	// pixel distance of top left from the window's top left at 0, 0, an absolute offset
	
	protected bool mouseIn; 		// used to track mouseover/mouseout
	protected bool _grabbed;	
	protected bool resize_dirty = true;
	
	protected SurfaceGeometry geometry;
	
	protected static final Style defaultStyle;
	
	protected static Surface grabbedSurface;
	protected static Surface focusSurface;

	///
	this()
	{	geometry = new SurfaceGeometry();
		updateDimensions();
		if (!focusSurface)
			focus();
	}
	
	/**
	 * Release focus if this Surface has focus when it's destroyed. */
	~this()
	{	if (focusSurface==this)
			focusSurface = null;
	}
	
	/**
	 * Get the pixel distance of this surface from its parent's top or left corner (outside the border). */
	float top()
	{	return offset.y;
	}
	float left() /// ditto
	{	return offset.x;
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
	float outerHeight() /// ditto
	{	return size.y;
	}

	/**
	 * Find the surface at the given coordinates.
	 * Surfaces are ordered by zIndex with higher values appearing on top.
	 * This function recurses through children and will return children, grandchildren, etc. as necessary.
	 * TODO: Add relative argument to allow x and y to be relative to another surface.
	 * Params:
	 *     x = X coordinate in pixels
	 *     y = Y coordinate in pixels
	 *     useMouseChildren = If true (the default), and a surface has mouseChildren=false, 
	 *         the children will not be searched.
	 * Returns: The surface at the coordinates (may be self), or null if coordinates are outside of this surface. */
	Surface findSurface(float x, float y, bool useMouseChildren=true)
	{	
		// Search children
		if (useMouseChildren && mouseChildren)
		{	// Sort if necessary
			if (!children.sorted(false, (Surface s){return s.style.zIndex;}))
				children.radixSort(false, (Surface s){return s.style.zIndex;});
			
			foreach(surf; children)
			{	Surface result = surf.findSurface(x, y);
				if (result)
					return result;
			}
		}
		
		// Search self
		Vec2f[4] polygon;
		getPolygon(polygon.ptr);
		if (Vec2f(x, y).inside(polygon))
			return this;
		
		return null;		
	}
	
	/**
	 * Get the geometry data used for rendering this Surface. */
	SurfaceGeometry getGeometry()
	{	return geometry;		
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
	 * Set the zIndex of this Surface to one more or less than the highest or lowest of its siblings. */
	void raise()
	{	if (parent)
			style.zIndex = amax(parent.children, (Surface s){return s.style.zIndex;}).style.zIndex + 1;
	}
	void lower() /// ditto
	{	if (parent)
			style.zIndex = amin(parent.children, (Surface s){return s.style.zIndex;}).style.zIndex - 1;	
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
			dimension[i] = style.dimension[i].toPx(parent_size[xy]);
		}
		
		// Set top or left to 0 if they and their opposite are both NaN
		if (isNaN(dimension[0]) && isNaN(dimension[2]))
			dimension[0] = 0;
		if (isNaN(dimension[1]) && isNaN(dimension[3]))
			dimension[3] = 0;
				
		// Get a bounding box that surrounds the transformed surface
		Vec4f bounds = Vec4f(float.infinity, -float.infinity, -float.infinity, float.infinity);
		if (constrain)
		{
			Vec2f[4] polygon;
			getPolygon(polygon.ptr);

			for (int i=0; i<4; i++)
			{	if (polygon[i].y < bounds[0]) // topmost
					bounds[0] = polygon[i].y;
				if (polygon[i].x > bounds[1]) // rightmost
					bounds[1] = polygon[i].x;
				if (polygon[i].y > bounds[2]) // bottommost
					bounds[2] = polygon[i].y;
				if (polygon[i].x < bounds[3]) // leftmost
					bounds[3] = polygon[i].x;
			}
			
			// Move bounds by requested move amount.
			bounds.v[0] += amount.y;	// top
			bounds.v[1] += amount.x;	// right
			bounds.v[2] += amount.y;	// bottom
			bounds.v[3] += amount.x;	// left
		}
	
		// Apply constraint
		if (constrain)
		{	if (bounds[0] < 0) // top
				amount.y -= bounds[0];
			if (bounds[3] < 0) // left
				amount.x -= bounds[3];
			
			if (bounds[1] > parent_size.x) // right
				amount.x -= bounds[1] - parent_size.x;
			if (bounds[2] > parent_size.y) // bottom
				amount.y -= bounds[2] - parent_size.y;
		}
	
		// Apply the movement
		for (int i=0; i<4; i++)
		{	int xy = (i+1) % 2;
			float multiplier = i==0||i==3 ? 1 : -1;
			if (style.dimension[i].unit == CSSValue.Unit.PERCENT)
				style.dimension[i].value = (dimension[i] + amount[xy]*multiplier) / parent_size[xy]*100;
			else
				style.dimension[i].value = dimension[i] + amount[xy]*multiplier;
		}
		
		updateDimensions(); // dragging breaks w/o this.
	}
	
	/**
	 * Update all of this Surface's dimensions, geometry, and children to prepare it for rendering. */
	void update()
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
			assert(textImage !is null);
			if (!textTexture) // create texture on first go
				textTexture = new GPUTexture(textImage, false, false, text, true);
			else
			//	textTexture.commit(textImage, false, false, text, true);
				textTexture.image = textImage;
			textTexture.padding = Vec2i(nextPow2(width)-width, -(nextPow2(height)-height));
			old_text = text;
		}
		
		geometry.setColors(style.backgroundColor, style.borderColor, style.opacity);
		geometry.setMaterials(style.backgroundImage, style.borderCenterImage, 
			style.borderImage, style.borderCornerImage, textTexture, style.opacity);
		
		// Using a z-buffer might make sorting unnecessary.  Tradeoffs?
		if (!children.sorted(true, (Surface s){return s.style.zIndex;} ))
			children.radixSort(true, (Surface s){return s.style.zIndex;} );
		
		foreach(child; children)
			child.update();
		
		resize_dirty = false;
	}

	/**
	 * Give focus to this Surface.  Only one Surface can have focus at a time.
	 * All keyboard/mouse events will be forwarded to the surface that has focus.
	 * If no Surface has focus, they will be given to the one under the mouse cursor.
	 * Also calls the onFocus callback function if set. */
	void focus() 
	{	Surface oldFocus = Surface.focusSurface;
		if(oldFocus && oldFocus.onBlur)
			oldFocus.onBlur(oldFocus);
		if(onFocus)
			onFocus(this);
		Surface.focusSurface = this;
	}
	
	/**
	 * Release focus from this surface and call the onBlur callback function if set. */
	void blur() 
	{	if (this==focusSurface)
		{	if(onBlur)
				onBlur(this);
			Surface.focusSurface = null;
		}
	}
	
	/**
	 * Trigger a keyDown event and call the onKeyDown callback function if set. 
	 * If the onKeyDown function is not set, call the parent's keyDown function. */ 
	void keyDown(dchar key, int mod=ModifierKey.NONE)
	{	bool propagate = true;
		if(onKeyDown)
			propagate = onKeyDown(this, key, mod);
		else if(parent && propagate) 
			parent.keyDown(key, mod);
	}
	
	/**
	 * Trigger a keyUp event and call the onKeyUp callback function if set. 
	 * If the onKeyUp function is not set, call the parent's keyUp function.*/ 
	void keyUp(dchar key, int mod=ModifierKey.NONE)
	{	bool propagate = true;
		if(onKeyUp)
			propagate = onKeyUp(this, key, mod);
		else if(parent && propagate) 
			parent.keyUp(key, mod);
	}
	
	/**
	 * Trigger a keyUp event and call the onKeyUp callback function if set. 
	 * If the onKeyUp function is not set, call the parent's keyUp function.*/ 
	void keyPress(dchar key, int mod=ModifierKey.NONE)
	{	bool propagate = true;
		if(onKeyPress)
			propagate = onKeyPress(this, key, mod);		
		if (propagate)
		{	if (editable)
			{	dchar[1] temp; // avoid allocation
				temp[0] = key;
				char[4] lookaside;
			//	text ~= .toString(temp, lookaside); // unfinished
			}
			if(parent) 
				parent.keyPress(key, mod);
		}
	}

	/**
	 * Trigger a mouseDown event and call the onMouseDown callback function if set. 
	 * If the onMouseDown function is not set, call the parent's mouseDown function.*/ 
	void mouseDown(byte buttons, Vec2i coordinates, char[] href=null){ 
		bool propagate = true;
		if(onMouseDown)
			propagate = onMouseDown(this, buttons, coordinates, href);
		else if(parent && propagate) 
			parent.mouseDown(buttons, coordinates, href);
	}
	
	/**
	 * Trigger a mouseUp event and call the onMouseUp callback function if set. 
	 * If the onMouseUp function is not set, call the parent's mouseUp function.*/ 
	void mouseUp(byte buttons, Vec2i coordinates, char[] href=null){ 
		bool propagate = true;
		if(onMouseUp)
			propagate = onMouseUp(this, buttons, coordinates, href);
		else if(parent && propagate) 
			parent.mouseUp(buttons, coordinates, href);
	}
	
	/**
	 * Trigger a mouseMove event and call the onMouseMove callback function if set. */ 
	void mouseMove(byte buttons, Vec2i amount, char[] href=null){
		bool propagate = true;
		if(onMouseMove)
			propagate = onMouseMove(this, buttons, amount, href);
		else if(parent && propagate) 
			parent.mouseMove(buttons, amount, href);
	}

	/**
	 * Trigger a mouseOver event and call the onMouseOver callback function if set. */ 
	void mouseOver(byte buttons, Vec2i coordinates) {
		if(!mouseIn )
		{	bool propagate = true;
				
			mouseIn = true;
			if(onMouseOver) 
				propagate = onMouseOver(this, buttons, coordinates);
			if(parent && propagate) 
				parent.mouseOver(buttons, coordinates);		
		}
	}

	/**
	 * Trigger a mouseOut event and call the onMouseOut callback function if set */ 
	void mouseOut(Surface next, byte buttons, Vec2i coordinates)
	{
		if(mouseIn)
		{	bool propagate = true;
			if(isChild(next))
				return;
			else
			{	mouseIn = false;
				if(onMouseOut)
					propagate = onMouseOut(this, buttons, coordinates);			
				if(next !is parent && parent && propagate)
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

	
	/**
	 * Return the Surface that is currently grabbing mouse input, or null if no Surfaces are. */
	static Surface getGrabbedSurface()
	{	return grabbedSurface;		
	}
	
	/**
	 * Returns: The surface that currently has focus.  Grabbed surfaces automatically have focus. */
	static Surface getFocusSurface()
	{	if (grabbedSurface)
			return grabbedSurface;
		else return focusSurface;		
	}
	
	/*
	 * Get a 4-sided polygon of the outline of this surface, after all styles and the transformation are applied.
	 * Coordinates are relative to the parent Surface.
	 * Params:
	 *     polygon = A pointer to a Vec2f[4] where the result will be stored. */
	protected void getPolygon(Vec2f *polygon)
	{	polygon[0] = Vec3f(0).transform(style.transform).vec2f + offset;			// top left
		polygon[1] = Vec3f(size.x, 0, 0).transform(style.transform).vec2f + offset;	// top right
		polygon[2] = size.vec3f.transform(style.transform).vec2f + offset;			// bottom right
		polygon[3] = Vec3f(0, size.y, 0).transform(style.transform).vec2f + offset;	// bottom left
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
	protected float parentWidth() 
	{	return parent ? parent.width() : Window.getInstance.getWidth(); 
	}
	protected float parentHeight() // ditto
	{	return parent ? parent.height() : Window.getInstance.getHeight(); 
	}

	/*
	 * Update the internally stored x, y, width, and height based on the style.
	 * This will also update the geometry, recurse through children, and call the resize event if necessary. */
	protected void updateDimensions()
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
			int bottomRight = xy==0 ? 1 : 2; // bottom or right
			
			// Ensure at least 4 of the 6 style dimensions are set.
			if (isNaN(style_dimensions[topLeft]))
			{	if (isNaN(style_dimensions[bottomRight]))
					style_dimensions[topLeft] = 0;
				if (isNaN(style_size[xy]))
					style_size[xy] = parent_size[xy];			
			}
			
			float parent_border = (parent ? parent.border[xy] : 0);
			float parent_padding = (parent ? parent.padding[xy] : 0);
			
			// Position	
			// Convert CSS style top, left, bottom, right, width, height to internal pixel x, y, width, height.
			// (at this point, at most only one of left/width/right will be NaN)
			if (isNaN(style_dimensions[topLeft])) // top or left is NaN
			{	size[xy] = style_size[xy];
				offset[xy] = parent_size[xy] - size[xy] - style_dimensions[bottomRight] + parent_border + parent_padding;
			}
			else if (isNaN(style_size[xy])) // width or height is NaN
			{	offset[xy] = style_dimensions[topLeft];
				size[xy] = (parent_size[xy] - style_dimensions[bottomRight]) - offset[xy];
			}
			else // bottom or right is NaN
			{	offset[xy] = style_dimensions[topLeft] + parent_border + parent_padding;
				size[xy] = style_size[xy];
		}	}	
		
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
}