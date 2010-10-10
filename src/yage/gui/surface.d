         /**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:	   Joe Pusderis (deformative0@gmail.com), Eric Poggel
 * License:	   <a href="lgpl3.txt">LGPL v3</a> 
 */

module yage.gui.surface;

public import derelict.sdl.sdl;

import tango.math.IEEE;
import tango.math.Math;
import tango.text.Util;
import yage.core.all;
import yage.system.log;
import yage.system.window;
import yage.resource.manager;
import yage.resource.texture;
import yage.resource.image;
import yage.resource.material;
import yage.system.input;
import yage.system.graphics.probe;
import yage.gui.style;
import yage.gui.textblock;
import yage.gui.surfacegeometry;

// For initializing freetype for unit tests
import yage.system.libraries;

/** 
 * Surfaces are similar to HTML DOM elements, including having text inside it, 
 * margin, padding, a border, and a background texture, including textures from a camera. 
 * Surfaces will exist in a hierarchical structure, with each having a parent and an array of children. 
 * They are positioned relative to their parent. 
 * A style struct defines most of the styles associated with the Surface. 
 * Floats are used for all coordinates.  Internal operations often use floats, and this also allows more precision on
 * surfaces that are scaled via style.transform.
 * 
 * TODO: If not all dimensions are specified, set to size of text or contents?  This could be slow.
 * 
 * TODO: Event examples
 * */
class Surface : Tree!(Surface)
{	
	Style style; /// Controls positioning and appearance of the Surface via CSS-like properties.
	TextBlock textBlock; /// Provides low-level access to this Surface's text.  Normally, setHtml() is all that's needed.
	TextCursor textCursor; ///
		
	bool editable = false; /// The text of this surface is editable.  If true, it can will accept focus on click or tab and keyboard events will not propagate to its parent.
	bool multiLine = true; /// TODO
	bool mouseChildren = true; /// Allow the mouse to interact with this Surface's children.
	union {
		Vec2f mouse;
		struct {
			float mouseX, mouseY;	/// Current position of the mouse cursor.  (Read-only for now)
		}
	}
	
	/// Callback functions
	void delegate() onBlur; ///
	void delegate() onFocus; ///
	void delegate(Input.MouseButton button, Vec2f coordinates) onClick; /// When a mouse button is pressed and released without moving the mouse.
	void delegate(Input.MouseButton button, Vec2f coordinates) onDblCick; /// TODO unfinished
	void delegate(int key, int modifier) onKeyDown; /// Triggered once when a key is pressed down
	void delegate(int key, int modifier) onKeyUp; /// Triggered once when a key is released
	
	/**
	 * Triggered when a key is pressed down and repeats at Input's key repeat rates.
	 * Unlike onKeyDown and onKeyUp, key is the unicode value of the key press, instead of the sdl key code. */
	void delegate(dchar key, int modifier) onKeyPress; 
	void delegate(Input.MouseButton button, Vec2f coordinates) onMouseDown; ///
	void delegate(Input.MouseButton button, Vec2f coordinates) onMouseUp; ///
	void delegate(Vec2f amount) onMouseMove; ///
	void delegate() onMouseOver; /// TODO: send surface the mouse went to?
	void delegate(Surface next) onMouseOut; ///
	void delegate() onResize; ///
		
	protected Texture textTexture;	// texture that constains rendered text image.
	
	protected bool mouseIn; 		// used to track mouseover/mouseout
	protected bool mouseMoved;		// used for click() event, has the mouse exited this surface since being pressed?
	protected bool textDirty = true;
	protected Vec4f oldBorder, oldPadding;
	protected Vec2f oldSize; // Used to see if dimensions have changed.
	protected Vec2f parent_size;		// Used for size if no parent
	
	protected SurfaceGeometry geometry; // geometry used to render this surface
		
	protected static Style defaultStyle; // Used as a cache by getDefaultStyle()	
	protected static Surface grabbedSurface; // surface that has captured the mouse
	protected static Surface focusSurface; // surface that has focus for receiving input


	/**
	 * Create a new Surface at 0, 0 with 0 width and height. */
	this(Surface parent=null)
	{	geometry = new SurfaceGeometry();
		if (parent)
			parent.addChild(this);
	}	
	this (char[] style, Surface parent=null) /// ditto
	{	this(parent);
		this.style.set(style);
	}
	this (char[] style, char[] html, Surface parent=null) /// ditto
	{	this(parent);
		this.style.set(style);
		setHtml(html);
	}
	
	/**
	 * Release focus if this Surface has focus when it's destroyed. */
	~this()
	{	if (focusSurface is this)
			focusSurface = null;
	}
	
	/**
	 * Get the calculated pixel distance of this surface from its parent's 
	 * top, right, bottom, or left corner (inside the parent's border and padding). */
	float top()
	{	if (isNaN(style.top.value))
		{	if (!isNaN(style.height.value) && !isNaN(style.bottom.value))			
			{	float parent_height = parentHeight(); // calculate width from left/right, padding, and border width.
				return parent_height - style.height.toPx(parent_height, false) - style.bottom.toPx(parent_height, false) 
					- extraTop() - extraBottom();
			}
			else return 0; // not enough info to calculate top
		}	
		return style.top.toPx(parentHeight(), false);
	}
	float right() /// ditto
	{	if (isNaN(style.right.value))
		{	if (!isNaN(style.width.value) && !isNaN(style.left.value))			
			{	float parent_width = parentWidth(); // calculate width from left/right, padding, and border width.
				return parent_width - style.width.toPx(parent_width, false) - style.left.toPx(parent_width, false) 
					- extraLeft() - extraRight();
			}
			else return 0; // not enough info to calculate right
		}	
		return style.right.toPx(parentWidth(), false);
	}
	float bottom() /// ditto
	{	if (isNaN(style.bottom.value))
		{	if (!isNaN(style.height.value) && !isNaN(style.top.value))			
			{	float parent_height = parentHeight(); // calculate width from left/right, padding, and border width.
				return parent_height - style.height.toPx(parent_height, false) - style.top.toPx(parent_height, false) 
					- extraTop() - extraBottom();
			}
			else return 0; // not enough info to calculate bottom
		}	
		return style.bottom.toPx(parentHeight(), false);
	}
	float left() /// ditto
	{	if (isNaN(style.left.value))
		{	if (!isNaN(style.width.value) && !isNaN(style.right.value))			
			{	float parent_width = parentWidth(); // calculate width from left/right, padding, and border width.
				return parent_width - style.width.toPx(parent_width, false) - style.right.toPx(parent_width, false) 
					- extraLeft() - extraRight();
			}
			else return 0; // not enough info to calculate left
		}	
		return style.left.toPx(parentWidth(), false);
	}
	
	/**
	 * Get the calculated inner-most width/height of the surface.  Just as with CSS, this is the width/height inside the padding. */
	float width()
	{	if (isNaN(style.width.value))
		{	if (!isNaN(style.left.value) && !isNaN(style.right.value))
			{	float parent_width = parentWidth(); // calculate width from left/right, padding, and border width.
				return parent_width - style.left.toPx(parent_width, false) - style.right.toPx(parent_width, false) 
					- extraLeft() - extraRight();
			}
			else return 0; // not enough info to calculate width
		}
		return style.width.toPx(parentWidth(), false);
	}	
	float height() /// ditto
	{	if (isNaN(style.height.value))
		{	if (!isNaN(style.top.value) && !isNaN(style.bottom.value))			
			{	float parent_height = parentHeight(); // calculate height from top/bottom, padding, and border height.
				return parent_height - style.top.toPx(parent_height, false) - style.bottom.toPx(parent_height, false) 
					- extraTop() - extraBottom();
			}
			else return 0; // not enough info to calculate height
		}	
		return style.height.toPx(parentHeight(), false);
	}
	
	/// Get the width/height needed to contain all descendants of this Surface.  This is currently broken and causes a stack overflow.
	float contentWidth()
	{	float maxChild = 0;
		foreach (c; children)
		{	float offset = c.offsetX() + c.contentWidth();
			if (offset > maxChild)
				maxChild = offset;
		}
		float w = width();
		return w > maxChild ? w : maxChild;
	}
	
	float contentHeight() /// ditto
	{	float maxChild = 0;
		foreach (c; children)
		{	float offset = c.offsetY() + c.contentHeight();
			if (offset > maxChild)
				maxChild = offset;
		}
		float h = height();
		return h > maxChild ? h : maxChild;
	}
		
	/// Get the distance of this Surface's top/left from it's parent's top or left corner.
	float offsetX()
	{	if (parent)
			return left() + parent.extraLeft();		
		return left();
	}	
	float offsetY() /// ditto
	{	if (parent)
			return top() + parent.extraTop();		
		return top();
	}
	
	/**
	 * Get the calculated width/height of the surface, including the width/height of the padding, but not including the border. */
	float innerWidth()
	{	float parent_width = parentWidth();
		return width() + style.paddingLeft.toPx(parent_width, false) + style.paddingRight.toPx(parent_width, false);
	}
	float innerHeight() /// ditto
	{	float parent_height = parentHeight();
		return height() + style.paddingTop.toPx(parent_height, false) + style.paddingBottom.toPx(parent_height, false);
	}
	
	/**
	 * Get the calculated width/height of the surface, including both the padding and the border.
	 * This is the same as the distance from top to bottom and left to right. */
	float outerWidth() 	
	{	float parent_width = parentWidth();
		return innerWidth + style.borderLeftWidth.toPx(parent_width, false) + style.borderRightWidth.toPx(parent_width, false);
	}
	float outerHeight() /// ditto
	{	float parent_height = parentHeight();
		return innerHeight + style.borderTopWidth.toPx(parent_height, false) + style.borderBottomWidth.toPx(parent_height, false);
	}
	
	unittest {
		Surface a = new Surface("width: 1000; height: 800; padding: 10px; border-width: 20px");
		Surface b = new Surface("top: 100px; right: 90px; bottom: 80px; left: 70px; padding: 20px; border-width: 10px", a);
		Surface c = new Surface("width: 50%; height: 50%; bottom: 20px; right: 20px; padding: 10px; border-width: 5px", b);
		
		assert(a.top() == 0 && a.bottom() == 0);
		assert(a.left() == 0 && a.right() == 0);
		assert(a.width() == 1000 && a.height() == 800);
		assert(a.innerWidth() == 1020 && a.innerHeight() == 820);
		assert(a.outerWidth() == 1060 && a.outerHeight() == 860);
		
		assert(b.top() == 100 && b.bottom() == 80);
		assert(b.left() == 70 && b.right() == 90);
		assert(b.width() == 780 && b.height() == 560);
		assert(b.innerWidth() == 820 && b.innerHeight() == 600);
		assert(b.outerWidth() == 840 && b.outerHeight() == 620);
		/*
		Log.trace(c.top(), " ", c.bottom());
		assert(c.top() == 370 && c.bottom() == 20);
		assert(c.left() == 260 && c.right() == 20);
		assert(c.width() == b.width()/2 && c.height() == b.height()/2);
		assert(c.innerWidth() == 820 && c.innerHeight() == 600);
		assert(c.outerWidth() == 840 && c.outerHeight() == 620);
		*/
	}

	/**
	 * Find the surface at the given coordinates.
	 * Surfaces are ordered by zIndex with higher values appearing on top.
	 * This function recurses through children and will return children, grandchildren, etc. as necessary.
	 * Surfaces with style.display=false are not searched.
	 * Params:
	 *     xy = coordinate in pixels, in this Surface's parent's coordinate system.
	 *     useMouseChildren = If true (the default), and a surface has mouseChildren=false, 
	 *         the children will not be searched.
	 * Returns: The surface at the coordinates (may be self), or null if coordinates are outside of this surface. */
	Surface findSurface(Vec2f xy, bool useMouseChildren=true)
	{	
		if (!style.display)
			return null;
		
		// Search self
		Vec2f[4] polygon;
		getPolygon(polygon);
		bool inside = xy.inside(polygon);

		// Search children before self
		if (useMouseChildren && mouseChildren)
		{	
			if (inside || style.overflow == Style.Overflow.VISIBLE)
			{	// Sort by zIndex if necessary
				if (!children.sorted(false, (Surface s){return s.style.zIndex;}))
					children.radixSort(false, (Surface s){return s.style.zIndex;});				
				foreach(child; children)
				{	Surface result = child.findSurface(parentToLocal(xy.vec2f));
					if (result)
						return result;
		}	}	}
		
		if (inside)			
			return this;
				
		return null;		
	}
	unittest
	{	
		Surface a = new Surface("width: 1000px; height: 1000px");
		Surface b = new Surface("top: 5px; left: 5px; width: 500px; height: 500px", a); // + 5
		Surface c = new Surface("top: 10px; left: 10px; padding: 20px; width: 500px; height: 500px", b); // + 30
		Surface d = new Surface("top: 20px; left: 20px; padding: 40px; border-width: 80; width: 500px; height: 500px", c); // + 140
		a.update();
		
		assert(a.findSurface(Vec2f(3, 3)) is a);
		assert(a.findSurface(Vec2f(8, 3)) is a);
		assert(a.findSurface(Vec2f(8, 8)) is b);
		assert(a.findSurface(Vec2f(38, 38)) is c);
		assert(a.findSurface(Vec2f(180, 180)) is d);	
	}
	
	/**
	 * Get a style with all auto/null/inherit/% values replaced with absolute values. */
	Style getComputedStyle()
	{	
		Style cs = style;  // computed style
		Style pcs = parent ? parent.getComputedStyle() : getDefaultStyle();
		
		// Font and text properties
		cs.color = style.color.get() is null ? pcs.color : style.color;
		cs.fontFamily = style.fontFamily is null ? pcs.fontFamily : style.fontFamily;
		cs.fontSize = style.fontSize == CSSValue.AUTO ? pcs.fontSize : style.fontSize;
		cs.fontStyle = style.fontStyle == Style.FontStyle.AUTO ? pcs.fontStyle : style.fontStyle;
		cs.fontWeight = style.fontWeight == Style.FontWeight.AUTO ? pcs.fontWeight : style.fontWeight;
		cs.textAlign = style.textAlign == Style.TextAlign.AUTO ? pcs.textAlign : style.textAlign;
		cs.textDecoration = style.textDecoration == Style.TextDecoration.AUTO ? pcs.textDecoration : style.textDecoration;		
		
		// Dimensional properties:
		
		// Convert all sizes to pixels
		Vec2f parent_size = parentSize();
		cs.width = width();
		cs.height = height();
		cs.top = top();
		cs.left = left();
		
		Vec4f e = extra(); // border + padding in pixels
		if (isNaN(cs.bottom.value))
			cs.bottom.value = parent_size.y - cs.top.value - cs.height.value - e.top - e.bottom;
		if (isNaN(cs.right.value))
			cs.right.value = parent_size.x - cs.left.value - cs.width.value - e.left - e.right;
		
		return cs;
	}
	
	/**
	 * Get the geometry data (vertices/triangles/Materials) used for rendering this Surface. */
	SurfaceGeometry getGeometry()
	{	return geometry;		
	}
	
	/**
	 * Get a 4-sided polygon of the outline of this surface, after all styles and the transformation are applied.
	 * Coordinates are relative to the parent Surface.
	 * Params:
	 *     polygon = A pointer to a Vec2f[4] where the result will be stored and returned.  
	 *         If null, new memory will be allocated. 
	 * Returns:
	 *     A polygon in the parent's coordinate system. */
	Vec2f[] getPolygon(in Vec2f[] polygon=null)
	{	if (polygon.length < 4)
			polygon = new Vec2f[4];
	
		Vec2f parentSize = parentSize();
		float top = extraTop();
		float left = extraLeft();
		Vec2f size = Vec2f(outerWidth(), outerHeight());
				
		polygon[0] = localToParent(Vec2f(-left, -top));			// top left
		polygon[1] = localToParent(Vec2f(size.x-left, -top));	// top right
		polygon[2] = localToParent(Vec2f(size.x-left, size.y-top));// bottom right
		polygon[3] = localToParent(Vec2f(-left, size.y-top));// bottom left
		
		// TODO: size may be null
		debug foreach(p; polygon)
			assert(!isNaN(p.x) && !isNaN(p.y));
		
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
			grabbedSurface = null; // [below] Move mouse back to pre-grabbed position
			Vec2i globalMouse = localToGlobal(Vec2f(mouseX, mouseY)).vec2i;
			SDL_WarpMouse(globalMouse.x, globalMouse.y);
		}		
	}
	bool getGrabbedMouse() /// ditto
	{	return (grabbedSurface is this);
	}
	
	/**
	 * Get and set the html text displayed inside this Surface. */
	char[] getHtml()
	{	return textBlock.getHtml();
	}
	void setHtml(char[] html) /// ditto
	{	textDirty = true;
		textBlock.setHtml(html);
	}
	
	/**
	 * Is s an ancestor of this surface? */
	bool isAncestor(Surface s)
	{	if (parent is s)
			return true;
		if (!parent)
			return false;
		return parent.isAncestor(s);
	}
	
	/**
	 * Convert between global, parent, and local coordinate systems.
	 * style.transform is taken into account.
	 * Params:
	 *     xy = Coordinates relative to the left side of the function name.
	 * Returns: Coordinates relative to the right side of the function name. */
	Vec2f localToParent(Vec2f xy)
	{	if (parent && style.transform != Matrix.IDENTITY)
			xy = xy.vec3f.transform(style.transform).vec2f;
		Vec2f parent_size = parentSize();
		xy += Vec2f(left(), top());
		xy += Vec2f(
			style.borderLeftWidth.toPx(parent_size.x, false) + style.paddingLeft.toPx(parent_size.x, false),
			style.borderTopWidth.toPx(parent_size.y, false) + style.paddingTop.toPx(parent_size.y, false));		
		return xy;
	}
	Vec2f localToGlobal(Vec2f xy) /// ditto
	{	if (parent)
			return parent.localToGlobal(localToParent(xy));  // untested
		return xy;
	}
	Vec2f parentToLocal(Vec2f xy) /// ditto
	{	Vec2f parent_size = parentSize();
		xy -= Vec2f(left(), top());
		xy -= Vec2f(
			style.borderLeftWidth.toPx(parent_size.x, false) + style.paddingLeft.toPx(parent_size.x, false),
			style.borderTopWidth.toPx(parent_size.y, false) + style.paddingTop.toPx(parent_size.y, false));		
		if (parent && style.transform != Matrix.IDENTITY)
			return xy.vec3f.transform(style.transform.inverse()).vec2f; // TODO: this fails if there's non-z rotation		
		return xy;
	}
	Vec2f globalToLocal(Vec2f xy) /// ditto
	{	if (parent)
			return parentToLocal(parent.globalToLocal(xy)); // untested
		return xy;
	}
	unittest
	{	Surface a = new Surface("width: 1000px; height: 1000px");
		Surface b = new Surface("top: 5px; left: 5px", a); // + 5
		Surface c = new Surface("top: 10px; left: 10px; padding: 19px", b); // + 29
		Surface d = new Surface("top: 20px; left: 20px; padding: 40px; border-width: 80px", c); // + 140
		a.update();
		
		assert(d.parentToLocal(Vec2f(0, 140)) == Vec2f(-140, 0));
		
		assert(a.globalToLocal(Vec2f(0, 5)) == Vec2f(0, 5));
		assert(b.parentToLocal(Vec2f(0, 5)) == Vec2f(-5, 0));
		assert(c.globalToLocal(Vec2f(0, 34)) == Vec2f(-34, 0));
		assert(d.globalToLocal(Vec2f(0, 174)) == Vec2f(-174, 0));
		
		assert(a.localToGlobal(Vec2f(0, 5)) == Vec2f(0, 5));
		assert(b.localToGlobal(Vec2f(-5, 0)) == Vec2f(0, 5));
		assert(c.localToGlobal(Vec2f(0, 0)) == Vec2f(34, 34));
		assert(d.localToGlobal(Vec2f(-174, 0)) == Vec2f(0, 174));
		
		d.style.transform = d.style.transform.move(Vec3f(20, 30, 0));
		assert(d.localToGlobal(Vec2f(-174, 0)) == Vec2f(20, 204));
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
		Vec2f parent_size = parentSize();	
		Vec4f dimension = Vec4f(top(), right(), bottom(), left());
		
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
	}
	
	/**
	 * Update all of this Surface's dimensions, geometry, and children to prepare it for rendering.
	 * Params:
	 *     parentSize = If specified, this size will be used for the parent dimensions (and therefore percent calculations) */
	void update(Vec2f* parentSize = null)
	{	
		// Get computed style
		if (parentSize)
			parent_size = *parentSize;
		Style cs = getComputedStyle();		
		Vec4f border;
		Vec4f padding;
		Vec2f size = Vec2f(cs.width.value, cs.height.value);
		for (int i=0; i<4; i++)
		{	border[i] = cs.borderWidth[i].value;
			padding[i] = cs.padding[i].value;
		}
		
		// Update geometry if sizes have changed.
		if (size != oldSize || border != oldBorder || padding != oldPadding)
		{	geometry.setDimensions(size, border, padding);
			resize(); // trigger resize event.
		}
		
		
		// Update text if size or text has changed.
		if (size != oldSize || textDirty)
		{	int width = cast(int)size.x;
			int height = cast(int)size.y;
			
			if (textBlock.update(cs, width, height)) // TODO: Probe for non power of 2 texture size support.
			{	// Probe.feature(Probe.Feature.NON_2_TEXTURE) requires an OpenGL context, 
				Image textImage = textBlock.render(true, editable && focusSurface is this ? &textCursor : null);
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
		
		// TODO: Only if dirty?
		geometry.setColors(style.backgroundColor, style.borderColor, style.opacity);
		geometry.setMaterials(style.backgroundImage, style.borderCenterImage, 
			style.borderImage, style.borderCornerImage, textTexture, style.opacity);
		
		// Using a z-buffer might make sorting unnecessary.  Tradeoffs?
		if (!children.sorted(true, (Surface s){return s.style.zIndex;} ))
			children.radixSort(true, (Surface s){return s.style.zIndex;} );
		
		oldBorder = border;
		oldPadding = padding;
		oldSize = size;
		
		foreach(child; children)
			if (child.style.display)
				child.update();
	}	
	
	/**
	 * Release focus from this surface.  This is caulled automatically only if the onBlur callback isn't set. */
	void blur() 
	{	if (this is focusSurface)
			Surface.focusSurface = null;
	}

	/**
	 * Give focus to this Surface.  Only one Surface can have focus at a time.
	 * All keyboard/mouse events will be forwarded to the surface that has focus.
	 * If no Surface has focus, they will be given to the one under the mouse cursor.
	 * Also calls the onFocus callback function if set. */
	void focus() 
	{	Surface oldFocus = Surface.focusSurface;
		if (oldFocus)
		{	if (oldFocus.onBlur)
				oldFocus.onBlur();
			else
				oldFocus.blur();
		}
		Surface.focusSurface = this;
	}
	
	/** 
	 * Trigger a click event.  This is caulled automatically only if the onClick callback isn't set.
	 * Click events occur after a mouseDown and mouseUp event if the mouse hasn't left the surface between the two.
	 * By default, this will call the parent's click function. 
	 * Params:
	 *     button = 
	 *     coordinates = Coordinates relative to the Surface, with style.transform taken into account.
	 *     allowFocus = Used internally to prevent focus from propagating updward */
	void click(Input.MouseButton button, Vec2f coordinates, bool allowFocus=true)
	{	if (editable)
		{	if (allowFocus && Surface.focusSurface !is this)
		    	focus(); // give focus on click if editable not already focused.
			textCursor.position = textBlock.xyToCursor(coordinates.vec2i);
			textDirty = true; // redraw
		}		
		if (parent) 
		{	if (parent.onClick)
				parent.onClick(button, localToParent(coordinates));
			else
				parent.click(button, localToParent(coordinates), false);
		}
	}

	/**
	 * Trigger a keyDown event.  This is caulled automatically only if the onKeyDown callback isn't set.
	 * By default, this will call the parent's keyDown function. 
	 * Params:
	 *     key = SDL's key code of the pressed key.
	 *     mod = Modifier key held down while key was pressed.*/ 
	void keyDown(int key, int mod=Input.ModifierKey.NONE)
	{	if (parent && !editable) 
		{	if (parent.onKeyDown)
				parent.onKeyDown(key, mod);
			else 
				parent.keyDown(key, mod);
		}
	}
	
	/**
	 * Trigger a keyUp event.  This is caulled automatically only if the onKeyUp callback isn't set.
	 * By default, this will call the parent's keyUp function.
	 * Params:
	 *     key = SDL's key code of the pressed key.
	 *     mod = Modifier key held down while key was pressed.*/ 
	void keyUp(int key, int mod=Input.ModifierKey.NONE)
	{	if (parent && !editable) 
		{	if (parent.onKeyUp)
				parent.onKeyUp(key, mod);
			else
				parent.keyUp(key, mod);
		}
	}
	
	/**
	 * Trigger a keyPress event.  This is caulled automatically only if the onKeyPress callback isn't set.
	 * Keypress events occur after a keyDown event and reoccur at Input's key repeat rates until after a keyUp occurs.
	 * If the onKeyPress function is not set, or if it returns true (propagate), call the parent's keyPress function.
	 * If editable is true, the TextBlock of this Surface will receive the input.
	 * Params:
	 *     key = SDL's key code of the pressed key.
	 *     mod = Modifier key held down while key was pressed.
	 *     unicode = unicode value of pressed key. */ 
	void keyPress(int key, int mod=Input.ModifierKey.NONE, dchar unicode=0) {
		if (editable)
		{	textBlock.input(key, mod, unicode, textCursor);
			textDirty = true;
		}
		else if (parent) 
		{	if (parent.onKeyPress)
				parent.onKeyPress(key, mod);
			else
				parent.keyPress(key, mod);
		}
	}

	/**
	 * Trigger a mouseDown event.  This is caulled automatically only if the onMouseDown callback isn't set.
	 * By default, this will call the parent's mouseDown function.
	 * Params:
	 *     button = Current state of the mouse buttons
	 *     coordinates = Coordinates relative to the Surface, with style.transform taken into account. */
	void mouseDown(Input.MouseButton button, Vec2f coordinates) {
		mouseMoved = false;
		if (parent) 
		{	if (parent.onMouseDown)
				parent.onMouseDown(button, localToParent(coordinates));
			else
				parent.mouseDown(button, localToParent(coordinates));
		}
	}
	
	/**
	 * Trigger a mouseUp event.  This is caulled automatically only if the onMouseUp callback isn't set.
	 * By default, this will call the parent's mouseUp function.
	 * Params:
	 *     button = Current state of the mouse buttons
	 *     coordinates = Coordinates relative to the Surface, with style.transform taken into account. 
	 *     allowClick = Used internally to prevent click event from propagating from here (it already propagates from click(). */
	void mouseUp(Input.MouseButton button, Vec2f coordinates, bool allowClick=true) { 		
		if (!mouseMoved && allowClick) // trigger the click event if the mouse button went down and up without the mouse moving.
		{	if (onClick)
				onClick(button, coordinates);
			else
				click(button, coordinates);
		}
		if(parent)
		{	if (parent.onMouseUp)
				parent.onMouseUp(button, localToParent(coordinates));
			else
				parent.mouseUp(button, localToParent(coordinates), false);
		}
	}
	
	/**
	 * Trigger a mouseMove event.  This is caulled automatically only if the onMouseMove callback isn't set.
	 * By default, this will call the parent's mouseMove function.*/ 
	void mouseMove(Vec2f amount) {
		if( parent)
		{	if (parent.onMouseMove)
				parent.onMouseMove(amount);
			else
				parent.mouseMove(amount);
		}
	}

	/**
	 * Trigger a mouseOver event.  This is caulled automatically only if the onMouseOver callback isn't set.
	 * By default, this will call the parent's mouseOver function.*/ 
	void mouseOver() {
		mouseMoved = true;
		if(!mouseIn)
		{	mouseIn = true;			
			if (parent) 
			{	if (parent.onMouseOver)
					parent.onMouseOver();
				else
					parent.mouseOver();	
		}	}
	}

	/**
	 * Trigger a mouseOut event.  This is caulled automatically only if the onMouseOut callback isn't set.
	 * By default, this will call the parent's mouseOut function.*/  
	void mouseOut(Surface next)
	{	mouseMoved = true;	
		if (mouseIn)
		{	if (isChild(next))
				return; // Don't do anything if mouseOut occurs when going into a child.			
			mouseIn = false;				
			if (next !is parent && parent)
			{	if (parent.onMouseOut)
					parent.onMouseOut(next);
				else
					parent.mouseOut(next);
		}	}
	}

	/**
	 * Trigger a resize event.  This is caulled automatically only if the onClick callback isn't set.
	 * This is called automatically after the resize occurs. */ 
	void resize()
	{
	}

	/**
	 * Get the default style for Surface.
	 * None of these styles will be set to AUTO. */
	static Style getDefaultStyle()
	{	if (!defaultStyle.fontFamily) // Create on first request
		{	defaultStyle.fontFamily = ResourceManager.getDefaultFont(); // TODO: This prevents surfaces from being constructed before freetype!.
			defaultStyle.fontSize = 12;
			defaultStyle.fontStyle = Style.FontStyle.NORMAL;
			defaultStyle.fontWeight = Style.FontWeight.NORMAL;
			defaultStyle.color = Color.BLACK;
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
	
	protected float parentWidth() // deprecated
	{	return parent ? parent.width() : parent_size.x; 
	}
	protected float parentHeight() // deprecated
	{	return parent ? parent.height() : parent_size.y; 
	}
	
	// Get the amount of margin+padding on each side.
	protected Vec4f extra()
	{	Vec2f parent_size = parentSize();
		return Vec4f(
			style.paddingTop.toPx(parent_size.y, false) + style.borderTopWidth.toPx(parent_size.y, false),
			style.paddingRight.toPx(parent_size.x, false) + style.borderRightWidth.toPx(parent_size.x, false),
			style.paddingBottom.toPx(parent_size.y, false) + style.borderBottomWidth.toPx(parent_size.y, false),
			style.paddingLeft.toPx(parent_size.x, false) + style.borderLeftWidth.toPx(parent_size.x, false));
	}
	
	// Border plus padding width for each of the edges
	protected float extraTop()
	{	float parent_height = parentHeight();
		return style.paddingTop.toPx(parent_height, false) + style.borderTopWidth.toPx(parent_height, false);
	}
	protected float extraRight()
	{	float parent_width = parentWidth();
		return style.paddingRight.toPx(parent_width, false) + style.borderRightWidth.toPx(parent_width, false);
	}
	protected float extraBottom()
	{	float parent_height = parentHeight();
		return style.paddingBottom.toPx(parent_height, false) + style.borderBottomWidth.toPx(parent_height, false);
	}
	protected float extraLeft()
	{	float parent_width = parentWidth();
		return style.paddingLeft.toPx(parent_width, false) + style.borderLeftWidth.toPx(parent_width, false);
	}
	
	// Get dimensions of this Surface's parent in pixels
	protected Vec2f parentSize()
	{	if (parent)
			return Vec2f(parent.width(), parent.height());
		return parent_size;
	}
}