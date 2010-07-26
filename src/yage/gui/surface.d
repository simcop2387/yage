/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:	   Joe Pusderis (deformative0@gmail.com), Eric Poggel
 * License:	   <a href="lgpl3.txt">LGPL v3</a> 
 */

module yage.gui.surface;

public import derelict.sdl.sdl;

import tango.math.IEEE;
import tango.math.Math;
import tango.text.convert.Utf;
import yage.core.all;
import yage.system.log;
import yage.system.window;
import yage.resource.manager;
import yage.resource.texture;
import yage.resource.image;
import yage.resource.material;
import yage.system.input;
import yage.gui.style;
import yage.gui.textblock;
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
		
	bool editable = false; /// The text of this surface is editable.
	bool mouseChildren = true; /// Allow the mouse to interact with this Surface's children.
	int mouseX, mouseY;	/// Current position of the mouse cursor.  (Read-only for now)
	TextCursor textCursor; ///
	
	/// Callback functions
	bool delegate(Surface self) onBlur; ///
	bool delegate(Surface self) onFocus; ///
	bool delegate(Surface self, Input.MouseButton button, Vec2i coordinates) onClick; /// When a mouse button is pressed and released without moving the mouse.
	bool delegate(Surface self, Input.MouseButton button, Vec2i coordinates) onDblCick; /// TODO unfinished
	bool delegate(Surface self, int key, int modifier) onKeyDown; /// Triggered once when a key is pressed down
	bool delegate(Surface self, int key, int modifier) onKeyUp; /// Triggered once when a key is released
	
	/**
	 * Triggered when a key is pressed down and repeats at Input's key repeat rates.
	 * Unlike onKeyDown and onKeyUp, key is the unicode value of the key press, instead of the sdl key code. */
	bool delegate(Surface self, dchar key, int modifier) onKeyPress; 
	bool delegate(Surface self, Input.MouseButton button, Vec2i coordinates) onMouseDown; ///
	bool delegate(Surface self, Input.MouseButton button, Vec2i coordinates) onMouseUp; ///
	bool delegate(Surface self, Vec2i amount) onMouseMove; ///
	bool delegate(Surface self) onMouseOver; ///
	bool delegate(Surface self) onMouseOut; ///
	void delegate(Surface self, Vec2f amount) onResize; ///
	
	protected Texture textTexture;	// texture that constains rendered text image.
	
	protected Vec2f offset;			// pixel distance of the topleft corner from parent's top left, a relative offset
	protected Vec2f size;			// pixel outer width/height, which includes borders and padding.
	
	public Vec2f offsetAbsolute;	// pixel distance of top left from the window's top left at 0, 0, an absolute offset
	
	protected bool mouseIn; 		// used to track mouseover/mouseout
	protected bool mouseMoved;		// used for click() event.
	
	protected bool resizeDirty = true;
	protected bool textDirty = true;
	
	protected SurfaceGeometry geometry; // geometry used to render this surface
	public TextBlock textBlock;
	
	protected static Style defaultStyle; // Used as a cache by getDefaultStyle()	
	protected static Surface grabbedSurface; // surface that has captured the mouse
	protected static Surface focusSurface; // surface that has focus for receiving input

	/**
	 * Create a new Surface at 0, 0 with 0 width and height. */
	this()
	{	geometry = new SurfaceGeometry();
		updateDimensions(getComputedStyle());
		if (!focusSurface)
			focus();
	}
	
	/**
	 * Release focus if this Surface has focus when it's destroyed. */
	~this()
	{	if (focusSurface is this)
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
	{	float parent_width = parentWidth();
		return innerWidth() - style.paddingLeft.toPx(parent_width, false) - style.paddingRight.toPx(parent_width, false);
	}	
	float height() /// ditto
	{	float parent_height = parentHeight();
		return innerHeight() - style.paddingTop.toPx(parent_height, false) - style.paddingBottom.toPx(parent_height, false);
	}
	
	/**
	 * Get the width/height of the surface, including the width/height of the padding, but not including the border. */
	float innerWidth()
	{	float parent_width = parentWidth();
		return outerWidth() - style.borderLeftWidth.toPx(parent_width, false) - style.borderRightWidth.toPx(parent_width, false);
	}
	float innerHeight() /// ditto
	{	float parent_height = parentHeight();
		return outerHeight() - style.borderTopWidth.toPx(parent_height, false) - style.borderBottomWidth.toPx(parent_height, false);
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
	Surface findSurface(Vec2i xy, bool useMouseChildren=true)
	{	
		// Search self
		Vec2f[4] polygon;
		getPolygon(polygon);
		if (xy.toFloat().inside(polygon)) // TODO: This doesn't take clipping into account.
		{	
			// Search children
			if (useMouseChildren && mouseChildren)
			{	// Sort if necessary
				if (!children.sorted(false, (Surface s){return s.style.zIndex;}))
					children.radixSort(false, (Surface s){return s.style.zIndex;});
				
				foreach(surf; children)
				{	Surface result = surf.findSurface(xy);
					if (result)
						return result;
			}	}
			
			return this;
		}
		
		return null;		
	}	
	
	/**
	 * Get a style with all auto/null/inherit/% values replaced with absolute values. */
	Style getComputedStyle()
	{	
		Style cs = style;  // computed style
		Style pcs = parent ? parent.getComputedStyle() : getDefaultStyle();
		
		// Font and text properties
		cs.fontFamily = style.fontFamily is null ? pcs.fontFamily : style.fontFamily;
		cs.fontSize = style.fontSize == CSSValue.AUTO ? pcs.fontSize : style.fontSize;
		cs.fontStyle = style.fontStyle == Style.FontStyle.AUTO ? pcs.fontStyle : style.fontStyle;
		cs.fontWeight = style.fontWeight == Style.FontWeight.AUTO ? pcs.fontWeight : style.fontWeight;
		cs.textAlign = style.textAlign == Style.TextAlign.AUTO ? pcs.textAlign : style.textAlign;
		cs.textDecoration = style.textDecoration == Style.TextDecoration.AUTO ? pcs.textDecoration : style.textDecoration;
		
		// Dimensional properties:
		
		// Convert all sizes to pixels
		Vec2f parent_size = Vec2f(parentWidth(), parentHeight());
		cs.width = style.width.toPx(parent_size.x);
		cs.height = style.height.toPx(parent_size.y);		
		for (int i=0; i<4; i++)
		{	ubyte xy = i%2;
			float scale_by = xy==0 ? parent_size.y : parent_size.x;			
			cs.padding[i] = style.padding[i].toPx(scale_by, false);
			cs.borderWidth[i] = style.borderWidth[i].toPx(scale_by, false);			
			cs.dimension[i].value = style.dimension[i].toPx(parent_size[xy]);
		}
		
		// Ensure at least 4 of the 6 of top/right/bottom/left/width/height are set.
		for (int xy=0; xy<2; xy++)
		{	int topLeft= xy==0 ? 3 : 0; // top or left
			int bottomRight = xy==0 ? 1 : 2; // bottom or right
			if (isNaN(cs.dimension[topLeft].value))
			{	if (isNaN(cs.dimension[bottomRight].value))
					cs.dimension[topLeft] = 0;
				if (isNaN(cs.size[xy].value))
					cs.size[xy] = parent_size[xy];			
			}
		}
		return cs;
	}

	
	/**
	 * Get the geometry data used for rendering this Surface. */
	SurfaceGeometry getGeometry()
	{	return geometry;		
	}
	
	/**
	 * Get a 4-sided polygon of the outline of this surface, after all styles and the transformation are applied.
	 * Coordinates are relative to the parent Surface.
	 * Params:
	 *     polygon = A pointer to a Vec2f[4] where the result will be stored and returned.  
	 *         If null, new memory will be allocated. */
	public Vec2f[] getPolygon(in Vec2f[] polygon=null)
	{	if (polygon.length < 4)
			polygon = new Vec2f[4];
		polygon[0] = localToParent(Vec2f(0));			// top left
		polygon[1] = localToParent(Vec2f(size.x, 0));	// top right
		polygon[2] = localToParent(size);				// bottom right
		polygon[3] = localToParent(Vec2f(0, size.y));	// bottom left
		return polygon;
	}
	
	/** 
	 * When a Surface has grabMouse() enabled, the mouse cursor will be hidden this surface alone will receive all mouse input.
	 * This also mouse movement so the mouse can move infinitely without encountering any boundaries.
	 * For example, this is ideal for attaching the mouse to the look direction of a first or third-person camera. 
	 * releaseMouse() undoes the effect. */
	void grabMouse(bool grab) {
		SDL_ShowCursor(!grab);
		if (grab)
		{	focus();
			SDL_WM_GrabInput(SDL_GRAB_ON);
			grabbedSurface = this;
		}
		else
		{	SDL_WM_GrabInput(SDL_GRAB_OFF);			
			grabbedSurface = null;
			SDL_WarpMouse(mouseX+cast(int)offsetAbsolute.x, mouseY+cast(int)offsetAbsolute.y);
		}		
	}
	bool getGrabbedMouse() /// ditto
	{	return (grabbedSurface is this);
	}
	
	/**
	 * Get and set the html text displayed inside this Surface. */
	public char[] getHtml()
	{	return textBlock.getHtml();
	}
	/// ditto
	public void setHtml(char[] html)
	{	textDirty = true;
		textBlock.setHtml(html);
	}
	
	/**
	 * Convert between global, parent, and local coordinate systems.
	 * style.transform is taken into account.
	 * Params:
	 *     xy = Coordinates relative to the left side of the function name.
	 * Returns: Coordinates relative to the right side of the function name. */
	Vec2f localToParent(Vec2f xy)
	{	if (parent) /// TODO: innerXy
			return xy.vec3f.transform(style.transform).vec2f + offset;
		return xy;
	}
	Vec2f localToGlobal(Vec2f xy) /// ditto
	{	if (parent)
			return localToGlobal(localToParent(xy));  // untested
		return xy;
	}
	Vec2f parentToLocal(Vec2f xy) /// ditto
	{	Vec2f parentSize = Vec2f(parentWidth(), parentHeight());
		Vec2f extra = Vec2f(
			style.borderLeftWidth.toPx(parentSize.x, false) + style.paddingLeft.toPx(parentSize.x, false),
			style.borderTopWidth.toPx(parentSize.y, false) + style.paddingTop.toPx(parentSize.y, false));
		Vec2f innerXy = xy - offset - extra;
		
		if (parent)
		{	if (style.transform == Matrix.IDENTITY)
				return innerXy; // simple common case
			return innerXy.vec3f.transform(style.transform.inverse()).vec2f; // TODO: this fails if there's non-z rotation
		}
		return innerXy;
	}
	Vec2f globalToLocal(Vec2f xy) /// ditto
	{	if (parent)
			return parentToLocal(parent.globalToLocal(xy)); // untested
		return xy;
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
			getPolygon(polygon);

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
		
		updateDimensions(getComputedStyle()); // dragging breaks w/o this.
	}
	
	/**
	 * Update all of this Surface's dimensions, geometry, and children to prepare it for rendering. */
	void update()
	{	
		Style cs = getComputedStyle();
		updateDimensions(cs);
		if (resizeDirty)
		{	
			Vec4f border;
			Vec4f padding;
			for (int i=0; i<4; i++)
			{	border[i] = cs.borderWidth[i].value;
				padding[i] = cs.padding[i].value;
			}
			geometry.setDimensions(Vec2f(width(), height()), border, padding);
		}
		
		// Text
		if (resizeDirty || textDirty)
		{
			int width = cast(int)width();
			int height = cast(int)height();
			
			if (textBlock.update(cs, width, height))
			{	Image textImage = textBlock.render(true, editable && focusSurface is this ? &textCursor : null); // TODO: Change true to Probe.NextPow2
				
				if (textImage)
				{	if (!textTexture) // create texture on first go
						textTexture = new Texture(textImage, Texture.Format.AUTO, false, "Surface Text", true);
					else
						textTexture.setImage(textImage);
					textTexture.padding = Vec2i(nextPow2(width)-width, -(nextPow2(height)-height));
				} else
					textTexture = null;
			}
			
			textDirty = false;
		}
		
		//if (!text.length)
		//	textTexture = null;
		
		geometry.setColors(style.backgroundColor, style.borderColor, style.opacity);
		geometry.setMaterials(style.backgroundImage, style.borderCenterImage, 
			style.borderImage, style.borderCornerImage, textTexture, style.opacity);
		
		// Using a z-buffer might make sorting unnecessary.  Tradeoffs?
		if (!children.sorted(true, (Surface s){return s.style.zIndex;} ))
			children.radixSort(true, (Surface s){return s.style.zIndex;} );
		
		foreach(child; children)
			child.update();
		
		resizeDirty = false;
	}	
	
	/**
	 * Release focus from this surface and call the onBlur callback function if set. */
	void blur() 
	{	if (this is focusSurface)
		{	if(onBlur)
				onBlur(this);
			Surface.focusSurface = null;
		}
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
	 * Trigger a click event and call the onClick callback function if set. 
	 * Click events occur after a mouseDown and mouseUp when the mouse hasn't moved between the two.
	 * If the onClick function is not set, or if it returns true (propagate), call the parent's click function. 
	 * Params:
	 *     button = 
	 *     coordinates = Coordinates relative to the Surface, with style.transform taken into account.
	 *     allowFocus = Used internally to prevent focus from propagating updward */
	void click(Input.MouseButton button, Vec2i coordinates, bool allowFocus=true)
	{	bool propagate = true; // TODO: Should coordinates be relative to inner area?
		if(onClick)
			propagate = onClick(this, button, coordinates);
		if (editable)
		{	if (allowFocus && Surface.focusSurface !is this)
		    	focus(); // give focus on click if editable not already focussed.
			textCursor.position = textBlock.xyToCursor(coordinates);
			textDirty = true; // redraw
		}
		
		if(parent && propagate) 
			parent.click(button, coordinates, false);
	}

	/**
	 * Trigger a keyDown event and call the onKeyDown callback function if set. 
	 * If the onKeyDown function is not set, or if it returns true (propagate), call the parent's keyDown function. 
	 * Params:
	 *     key = SDL's key code of the pressed key.
	 *     mod = Modifier key held down while key was pressed.*/ 
	void keyDown(int key, int mod=Input.ModifierKey.NONE)
	{	bool propagate = true;
		if(onKeyDown)
			propagate = onKeyDown(this, key, mod);
		if(parent && propagate) 
			parent.keyDown(key, mod);
	}
	
	/**
	 * Trigger a keyUp event and call the onKeyUp callback function if set. 
	 * If the onKeyUp function is not set, or if it returns true (propagate), call the parent's keyUp function.
	 * Params:
	 *     key = SDL's key code of the pressed key.
	 *     mod = Modifier key held down while key was pressed.*/ 
	void keyUp(int key, int mod=Input.ModifierKey.NONE)
	{	bool propagate = true;
		if(onKeyUp)
			propagate = onKeyUp(this, key, mod);
		if(parent && propagate) 
			parent.keyUp(key, mod);
	}
	
	/**
	 * Trigger a keyPress event and call the onKeyPress callback function if set.
	 * Keypress events occur after a keyDown event and reoccur at Input's key repeat rates until after a keyUp occurs.
	 * If the onKeyPress function is not set, or if it returns true (propagate), call the parent's keyPress function.
	 * If editable is true, the TextBlock of this Surface will receive the input.
	 * Params:
	 *     key = SDL's key code of the pressed key.
	 *     mod = Modifier key held down while key was pressed.
	 *     unicode = unicode value of pressed key. */ 
	void keyPress(int key, int mod=Input.ModifierKey.NONE, dchar unicode=0) {
		bool propagate = true;
		if(onKeyPress)
			propagate = onKeyPress(this, key, mod);			
		if (editable)
		{	textBlock.input(key, mod, unicode, textCursor);
			textDirty = true;
		}
		if(parent && propagate) 
			parent.keyPress(key, mod);
	}

	/**
	 * Trigger a mouseDown event and call the onMouseDown callback function if set. 
	 * If the onMouseDown function is not set, or if it returns true (propagate), call the parent's mouseDown function.
	 * Params:
	 *     button = Current state of the mouse buttons
	 *     coordinates = Coordinates relative to the Surface, with style.transform taken into account. */
	void mouseDown(Input.MouseButton button, Vec2i coordinates) { 
		mouseMoved = false;
		bool propagate = true;
		if(onMouseDown)
			propagate = onMouseDown(this, button, coordinates);
		if(parent && propagate) 
			parent.mouseDown(button, coordinates);
	}
	
	/**
	 * Trigger a mouseUp event and call the onMouseUp callback function if set. 
	 * If the onMouseUp function is not set, or if it returns true (propagate), call the parent's mouseUp function.
	 * Params:
	 *     button = Current state of the mouse buttons
	 *     coordinates = Coordinates relative to the Surface, with style.transform taken into account. */
	void mouseUp(Input.MouseButton button, Vec2i coordinates) { 
		bool propagate = true;
		if(onMouseUp)
			propagate = onMouseUp(this, button, coordinates);
		if (!mouseMoved) // trigger the click event if the mouse button went down and up without the mouse moving.
			click(button, coordinates);		
		if(parent && propagate) 
			parent.mouseUp(button, coordinates);
	}
	
	/**
	 * Trigger a mouseMove event and call the onMouseMove callback function if set. 
	 * If the onMouseMove function is not set, or if it returns true (propagate), call the parent's mouseMove function.*/ 
	void mouseMove(Vec2i amount) {
		mouseMoved = true;
		bool propagate = true;
		if(onMouseMove)
			propagate = onMouseMove(this, amount);
		if(parent && propagate) 
			parent.mouseMove(amount);
	}

	/**
	 * Trigger a mouseOver event and call the onMouseOver callback function if set. 
	 * If the onMouseOver function is not set, or if it returns true (propagate), call the parent's mouseOver function.*/ 
	void mouseOver() {
		if(!mouseIn)
		{	bool propagate = true;				
			mouseIn = true;
			if(onMouseOver) 
				propagate = onMouseOver(this);
			if(parent && propagate) 
				parent.mouseOver();		
		}
	}

	/**
	 * Trigger a mouseOut event and call the onMouseOut callback function if set 
	 * If the onMouseOut function is not set, or if it returns true (propagate), call the parent's mouseOut function.*/  
	void mouseOut(Surface next)
	{
		if(mouseIn)
		{	
			if(isChild(next))
				return; // Don't do anything if mouseOut occurs when going into a child.
			
			mouseIn = false;
			bool propagate = true;
			if(onMouseOut)
				propagate = onMouseOut(this);			
			if(next !is parent && parent && propagate)
				parent.mouseOut(next);
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
	 * Get the default style for Surface.
	 * None of these styles will be set to AUTO. */
	static Style getDefaultStyle()
	{
		if (!defaultStyle.fontFamily)
		{	defaultStyle.fontFamily = ResourceManager.getDefaultFont();
			defaultStyle.fontSize = 12;
			defaultStyle.fontStyle = Style.FontStyle.NORMAL;
			defaultStyle.fontWeight = Style.FontWeight.NORMAL;
			defaultStyle.color = "black";
			defaultStyle.textAlign = Style.TextAlign.LEFT;
			defaultStyle.textDecoration = Style.TextDecoration.NONE;			
		}
		return defaultStyle;
	}
	
	/**
	 * Returns: The surface that currently has focus.  Grabbed surfaces automatically have focus. */
	static Surface getFocusSurface()
	{	if (grabbedSurface)
			return grabbedSurface;
		else return focusSurface;		
	}
	
	/**
	 * Return the Surface that is currently grabbing mouse input, or null if no Surfaces are. */
	static Surface getGrabbedSurface()
	{	return grabbedSurface;		
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
	{	return parent ? parent.width() : Window.getInstance().getWidth(); 
	}
	protected float parentHeight() // ditto
	{	return parent ? parent.height() : Window.getInstance.getHeight(); 
	}
	
	/*
	 * Update the internally stored x, y, width, and height based on the style.
	 * This will also update the geometry, recurse through children, and call the resize event if necessary. */
	protected void updateDimensions(Style cs)
	{
		Vec2f old_offset = offset;
		Vec2f old_size = size;
				
		// Convert style dimensions to pixels.
		Vec2f parent_size = Vec2f(parentWidth(), parentHeight());
		Vec2f style_size = Vec2f( // style size doesn't include borders and padding, but this does.
			cs.width.value + cs.borderLeftWidth.value + cs.borderRightWidth.value + cs.paddingLeft.value + cs.paddingRight.value, 
			cs.height.value + cs.borderTopWidth.value + cs.borderBottomWidth.value + cs.paddingTop.value + cs.paddingBottom.value);
		
		// Calculate size and offset from top, left, bottom, right, width, height
		// (at this point, at most only one of left/width/right will be NaN)
		for (int xy=0; xy<2; xy++)
		{	int topLeft= xy==0 ? 3 : 0; // top or left
			int bottomRight = xy==0 ? 1 : 2; // bottom or right

			float grandparent_size=0, parent_border=0, parent_padding=0;
			if (parent)
			{	grandparent_size = xy==0 ? parent.parentHeight() : parent.parentWidth();			
				parent_border = parent.style.borderWidth[xy].toPx(grandparent_size, false);
				parent_padding = parent.style.padding[xy].toPx(grandparent_size, false);
			}				
			
			if (isNaN(cs.dimension[topLeft].value)) // top or left is NaN
			{	size[xy] = style_size[xy];
				offset[xy] = parent_size[xy] - size[xy] - cs.dimension[bottomRight].value + parent_border + parent_padding;
			}
			else if (isNaN(style_size[xy])) // width or height is NaN
			{	offset[xy] = cs.dimension[topLeft].value;
				size[xy] = (parent_size[xy] - cs.dimension[bottomRight].value) - offset[xy];
			}
			else // bottom or right is NaN
			{	offset[xy] = cs.dimension[topLeft].value + parent_border + parent_padding;
				size[xy] = style_size[xy];
		}	}	
		
		// Calculate absolute offset
		if (parent)
			offsetAbsolute = parent.offsetAbsolute + offset;
		else
			offsetAbsolute = offset;
		
		// If resized
		if (size != old_size)
		{	resizeDirty = true;
			resize(size-old_size); // trigger resize event.
			//foreach (c; children)
			//	c.updateDimensions(c.getComputedStyle());
		}
	}
}