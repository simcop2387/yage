/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:	Joe Pusderis (deformative0@gmail.com), Eric Poggel
 * License:	<a href="lgpl.txt">LGPL</a> 
 */

module yage.gui.surface;

import std.stdio;
import std.math;
import derelict.opengl.gl;
import derelict.sdl.sdl;
import derelict.opengl.glext;
import derelict.opengl.glu;
import yage.core.all;
import yage.system.device;
import yage.system.constant;
import yage.system.input;
import yage.resource.texture;
import yage.gui.style;
import yage.system.rendertarget;


const float third = 1.0/3.0;

/** 
 * Surfaces are similar to HTML DOM elements, including having text inside it, 
 * margin, padding, a border, and a background texture, including textures from a camera. 
 * Surfaces will exist in a hierarchical structure, with each having a parent and an array of children. 
 * Surfacs are positioned relative to their parent. 
 * A style struct defines most of the styles associated with the Surface. */
class Surface : Tree!(Surface)
{
	static final Style defaultStyle;
	Style style;	
	
	// internal values
	Vec2f topLeft;		// pixel distance of the topleft corner from parent's top left
	Vec2f bottomRight;	// pixel distance of the bottom right corner from parent's top left
	Vec2f offset;		// pixel distance of top left from the window's top left at 0, 0
	
	bool mouseIn; // is this used?
	
	protected Style old_style; // Used for comparison to see if dirty.
	protected Surface old_parent;
	
	protected float[72] vertices = 0; // Used for rendering
	protected float[72] tex_coords = 0;

	/// Callback functions
	void delegate(typeof(this) self) onBlur; // Unfinished
	void delegate(typeof(this) self) onFocus; //Done -- See Raise, no fall through
	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onClick; // unfinished
	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onDblCick; // unfinished
	void delegate(typeof(this) self, byte key) onKeyDown;
	void delegate(typeof(this) self, byte key) onKeyUp;
	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onMouseDown;
	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onMouseUp;
	void delegate(typeof(this) self, byte buttons, Vec2i amount) onMouseMove;
	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onMouseOver;
	void delegate(typeof(this) self, byte buttons, Vec2i coordinates) onMouseOut;
	void delegate(typeof(this) self, Vec2f amount) onResize;

	/// Constructor
	this(Surface p=null){
		parent = p;
		if(!(parent is null))
			parent.addChild(this);
		calculate();
	}
	
	// Set style dimensions from pixels.
	protected void top(float v)    { style.top    = style.topUnit   ==Style.PERCENT ? 100*v/parentHeight() : v; }
	protected void bottom(float v) { style.bottom = style.bottomUnit==Style.PERCENT ? 100*v/parentHeight() : v; }
	protected void height(float v) { style.height = style.heightUnit==Style.PERCENT ? 100*v/parentHeight() : v; }
	protected void left(float v)   { style.left   = style.leftUnit  ==Style.PERCENT ? 100*v/parentWidth() : v; }
	protected void right(float v)  { style.right  = style.rightUnit ==Style.PERCENT ? 100*v/parentWidth() : v; }
	protected void width(float v)  { style.width  = style.widthUnit ==Style.PERCENT ? 100*v/parentWidth() : v; }
	
	/**
	 * Get the calculated values of this Surface's dimensions in pixel values from the top left corner. */
	float top()   { return topLeft.y; }
	float right() { return bottomRight.x; }	/// ditto
	float bottom(){ return bottomRight.y; }	/// ditto
	float left()  { return topLeft.x; }	/// ditto
	float width() { return bottomRight.x - topLeft.x; }	/// ditto
	float height(){	return bottomRight.y - topLeft.y; }	/// ditto
	
	/// Get dimensions of this Surface's parent in pixels
	float parentWidth() { return parent ? parent.width()  : Device.getWidth(); }
	float parentHeight(){ return parent ? parent.height() : Device.getHeight(); }	/// Ditto
	


	/**
	 * Recalculate all properties of this Surface based on its style.*/
	void calculate()
	{			
		// Calculate real values from percents
		float parent_width = parentWidth();
		float parent_height= parentHeight();
		
		float top   = style.topUnit    == Style.PERCENT ? style.top   * parent_height*.01f : style.top;
		float right = style.rightUnit  == Style.PERCENT ? style.right * parent_width *.01f : style.right;
		float bottom= style.bottomUnit == Style.PERCENT ? style.bottom* parent_height*.01f : style.bottom;
		float left  = style.leftUnit   == Style.PERCENT ? style.left  * parent_width *.01f : style.left;
		float width = style.widthUnit  == Style.PERCENT ? style.width * parent_width *.01f : style.width;
		float height= style.heightUnit == Style.PERCENT ? style.height* parent_height*.01f : style.height;

		Vec2f resized_by = Vec2f(this.width(), this.height());
		Vec2f offset_by = offset;
		
		// Ensure top and left are set if bottom and right are not.
		if (isnan(left) && isnan(right))
			left = 0.0f;
		if (isnan(top) && isnan(bottom))
			top = 0.0f;

		// If left side is anchored
		if (!isnan(left))
		{	topLeft.x = left;
			if (!isnan(width)) // if width
				bottomRight.x = left + width;
			else if (isnan(right)) // if not width and not right
			{} // TODO: Figure out what default size should be.  size to contents?
		}
		
		// If right side is anchored
		if (!isnan(right))
		{	bottomRight.x = parent_width - right;
			if (isnan(left)) // if not left
			{	if (!isnan(width)) // if width
					topLeft.x = parent_width - right - width;
				else
				{} // TODO: Figure out what default size should be.  size to contents?
		}	}
		
		// If top side is anchored
		if (!isnan(top))
		{	topLeft.y = top;
			if (!isnan(height)) // if Height
				bottomRight.y =top + height;
			else if (isnan(bottom)) // if not Height and not bottom
			{} // TODO: Figure out what default size should be.  size to contents?
		}
		// If bottom side is anchored
		if (!isnan(bottom))
		{	bottomRight.y = parent_height - bottom;
			if (isnan(top)) // if not top
			{	if (!isnan(height)) // if Height
					topLeft.y = parent_height - bottom - height;
				else
				{} // TODO: Figure out what default size should be.  size to contents?
		}	}
		
		// Calculate offset
		if (parent)
			offset = parent.offset + topLeft;
		else
			offset = topLeft;
		
		// See if anything has changed.
		resized_by = Vec2f(this.width(), this.height()) - resized_by;
		offset_by = offset - offset_by;		
		float resized_length2 = resized_by.length2();
		if (resized_length2 > 0 || offset_by.length2() > 0)
		{	
			// Calculate vertices
			Vec2f portion;
			
			// Portion of the Texture to use for drawing
			// This won't be necessary when we support rectangular textures.
			if (style.backgroundMaterial)
			{	portion.x = style.backgroundMaterial.requested_width/cast(float)style.backgroundMaterial.getWidth();
				portion.y = style.backgroundMaterial.requested_height/cast(float)style.backgroundMaterial.getHeight();
			} else
			{	portion.x = 1;
				portion.y = 1;
			}
			
			switch(style.backgroundRepeat)
			{
				case Style.STRETCH:
					float w = this.width();
					float h = this.height();
					vertices[0..8] = [0.0f, h, w, h, w, 0, 0, 0];
					tex_coords[0..8] = [0.0f, 0, portion.x, 0, portion.x, portion.y, 0, portion.y];						
					break;
				case Style.NINESLICE:
					
					// For vertex cooordinates
					Vec2f vert1 = Vec2f(style.backgroundPositionX, style.backgroundPositionY);
					Vec2f vert2 = Vec2f(width-style.backgroundPositionX, height-style.backgroundPositionY);
					
					// For texture coordinates
					Vec2f tex1 = Vec2f(portion.x*third, portion.y*third);
					Vec2f tex2 = Vec2f(portion.x*third*2, portion.y*third*2);
					
					// 0    3
					// |	^
					// V	|
					// 1<---2
					// TODO: Use same array for both using glScalef, once portion becomes unnecessary.
					// TODO: Ensure this operation is 100% on the stack.
					vertices[0..72] = [
						0.0f, 0, 0, vert1.y, vert1.x, vert1.y, vert1.x, 0,						// top left
						vert1.x, 0, vert1.x, vert1.y, vert2.x, vert1.y, vert2.x, 0,				// top
						vert2.x, 0, vert2.x, vert1.y, width, vert1.y, width, 0,					// top right							
						0.0f, vert1.y, 0, vert2.y, vert1.x, vert2.y, vert1.x, vert1.y,			// left
						vert1.x, vert1.y, vert1.x, vert2.y, vert2.x, vert2.y, vert2.x, vert1.y,	// center
						vert2.x, vert1.y, vert2.x, vert2.y, width, vert2.y, width, vert1.y,		// right							
						0.0f, vert2.y, 0, height, vert1.x, height, vert1.x, vert2.y,			// bottom left			
						vert1.x, vert2.y, vert1.x, height, vert2.x, height, vert2.x, vert2.y,	// bottom
						vert2.x, vert2.y, vert2.x, height, width, height, width, vert2.y		// bottom right
						];						
					tex_coords[0..72] = [
						0.0f, 0, 0, tex1.y, tex1.x, tex1.y, tex1.x, 0,							// top left
						tex1.x, 0, tex1.x, tex1.y, tex2.x, tex1.y, tex2.x, 0,					// top
						tex2.x, 0, tex2.x, tex1.y, portion.x, tex1.y, portion.x, 0,				// top right	
						0.0f, tex1.y, 0, tex2.y, tex1.x, tex2.y, tex1.x, tex1.y,				// left
						tex1.x, tex1.y, tex1.x, tex2.y, tex2.x, tex2.y, tex2.x, tex1.y,			// center
						tex2.x, tex1.y, tex2.x, tex2.y, portion.x, tex2.y, portion.x, tex1.y,	// right				
						0.0f, tex2.y, 0, portion.y, tex1.x, portion.y, tex1.x, tex2.y,			// bottom left
						tex1.x, tex2.y, tex1.x, portion.y, tex2.x, portion.y, tex2.x, tex2.y,	// bottom
						tex2.x, tex2.y, tex2.x, portion.y, portion.x, portion.y, portion.x, tex2.y // bottom right
						];
					break;
			}			
			
			// Calculate children to update positions and offset.
			foreach (c; children)
				c.calculate();			
			// Call resize if resized.
			if (resized_length2 > 0)
				resize(resized_by);
		}
	}
	
	/*
	 * Set this Surface as non dirty. 
	 * Returns: Was the surface previously dirty? */
	protected bool dirty()
	{	bool result = false;
		if (style != old_style)
		{	old_style = style;			
			result = true;
		}
		if (parent !is old_parent)
		{	old_parent = parent;
			result = true;
		}
		return result;
	}
	
	/**
	 * Render this Surface 
	 * Params:
	 *     rt = TODO: Render to this target.*/
	void render(IRenderTarget rt=null) 
	{
		//if (rt)
		//	rt.bind();
		
		//calculate(); // TODO: use dirty flag to only calculate when necessary.
		
		glPushAttrib(0xFFFFFFFF);	// all attribs
		glDisableClientState(GL_NORMAL_ARRAY);
		
		// Setup the viewport in orthogonal mode,
		// with dimensions 0..width, 0..height
		// with 0,0 being at the top left.
		glViewport(0, 0, cast(int)Device.size.x, cast(int)Device.size.y);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0, Device.size.x, Device.size.y, 0, -1, 1);
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
		
		//if (rt)
		//	rt.unbind();
	}
	
	void draw()
	{
		if(style.visible)
		{
			if (dirty)
				calculate();
			
			
				
			glPushMatrix();
			glTranslatef(topLeft.x, topLeft.y, 0);
			glVertexPointer(2, GL_FLOAT, 0, vertices.ptr);
			glTexCoordPointer(2, GL_FLOAT, 0, tex_coords.ptr);	
			
			void draw2()
			{	switch(style.backgroundRepeat)
				{	case Style.STRETCH:
						glDrawArrays(GL_QUADS, 0, 4);						
						break;
					case Style.NINESLICE:
						glDrawArrays(GL_QUADS, 0, 36);
						break;
					default:
						throw new Exception("Not a valid fill type");
						break;	
				}
			}
			
			if (style.backgroundColor.a > 0) // If backgroundColor alpha.
			{	glColor4ubv(style.backgroundColor.ub.ptr);
				draw2();
				glColor4ubv(Color(0xFFFFFFFF).ub.ptr);				
			}
			
			if (style.backgroundMaterial !is null)
			{	glEnable(GL_TEXTURE_2D);
				Texture(style.backgroundMaterial, true, TEXTURE_FILTER_BILINEAR).bind();
				draw2();
				glDisable(GL_TEXTURE_2D);
				Texture(style.backgroundMaterial, true, TEXTURE_FILTER_BILINEAR).unbind();
			}
			
			// Using a zbuffer might make this unecessary.  tradeoffs?
			if (!children.sorted(true, (Surface s){return s.style.zIndex;} ))
				children.radixSort(true, (Surface s){return s.style.zIndex;} );
			
			foreach(surf; children)
				surf.draw();
			
			glPopMatrix();
		}
	}
	
	/**
	 * Set the zIndex of this Surface to the highest or lowest of its siblings. */
	void raise()
	{	this.style.zIndex = amax(parent.children, (Surface s){return s.style.zIndex;}).style.zIndex + 1;
	}
	void lower() /// Ditto
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
		// Ensure top and left are set in the stle if bottom and right are not.  This is required for moving.
		if (isnan(style.left) && isnan(style.right))
			style.left = 0.0f;
		if (isnan(style.top) && isnan(style.bottom))
			style.top = 0.0f;
		
		// Calculate real values from percents
		float parent_width = parentWidth();
		float parent_height= parentHeight();
		float percent_width  = 100/parent_width;
		float percent_height = 100/parent_height;
		
		// Update dimension styles with new positions.
		if (!isnan(style.left))
			style.left += amount.x * (style.leftUnit==Style.PERCENT ? percent_width : 1.0f);
		if (!isnan(style.right))
			style.right -= amount.x * (style.rightUnit==Style.PERCENT ? percent_width : 1.0f);
		if (!isnan(style.top))
			style.top += amount.y * (style.topUnit==Style.PERCENT ? percent_height : 1.0f);
		if (!isnan(style.bottom))
			style.bottom -= amount.y * (style.bottomUnit==Style.PERCENT ? percent_height : 1.0f);
		
		// if constrain dragging to parent dimensions.
		if (constrain)	
		{
			// The constraints require the current calculations.
			calculate();
			
			if (!isnan(style.left))
			{	if (style.left < 0)
					style.left = 0;			
				if (right() > parent_width)
					left(parent_width - width());
			}
			if (!isnan(style.right))
			{	if (style.right < 0)
					style.right = 0;
				if (left() < 0)
					right(parent_width - width());
			}
			if (!isnan(style.top))
			{	if (style.top < 0)
					style.top = 0;			
				if (bottom() > parent_height)
					top(parent_height - height());
			}	
			if (!isnan(style.bottom))
			{	if (style.bottom < 0)
					style.bottom = 0;
				if (top() < 0)
					bottom(parent_height - height());
			}
		}
	}
	
	/** If enabled, the mousecursor will be hidden and grabbed by the application.
	 *  This also allows for mouse position changes to be registered in a relative fashion,
	 *  i.e. even when the mouse is at the edge of the screen.  This is ideal for attaching
	 *  the mouse to the look direction of a first or third-person camera. */
	void grabMouse(bool grab) {
		if (grab){
			focus();
			SDL_WM_GrabInput(SDL_GRAB_ON);
			SDL_ShowCursor(false);
		}
		else{
			blur(); // should this be done?
			SDL_WM_GrabInput(SDL_GRAB_OFF);
			SDL_ShowCursor(true);
		}
		Input.grabbed = grab;
	}
	
	/**
	 * Find the surface at the given coordinates.
	 * Surfaces are ordered by zIndex with higher values appearing on top.
	 * This function recurses through children and will return children, grandchildren, etc. as necessary.
	 * TODO: Add relative argument.
	 * Returns: The surface, or self if no surface at the coordinates, or null if coordinates are outside self. */
	Surface findSurface(float x, float y)
	{	if (Vec2f(x, y).inside(offset, offset - topLeft + bottomRight))
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
	 * Give focus to this Surface.  Only one Surface can have focus at a time.
	 * All keyboard/mouse events will be forwarded to the surface that has focus.
	 * If no Surface has focus, they will be given to the one under the mouse cursor.
	 * Also calls the onFocus callback function if set. */
	void focus(){
		if(onFocus)
			onFocus(this);
		Input.surfaceLock = this;
	}
	
	/**
	 * Release focus from this surface and call the onBlur callback function if set. */
	void blur(){
		if(onBlur)
			onBlur(this);
		Input.surfaceLock = null;
	}
	
	/**
	 * Trigger a keyDown event and call the onKeyDown callback function if set. */ 
	void keyDown(byte key){
		if(onKeyDown)
			onKeyDown(this, key);
		else if(parent !is null) 
			parent.keyDown(key);
	}
	
	/**
	 * Trigger a keyUp event and call the onKeyUp callback function if set. */ 
	void keyUp(byte key){
		if(onKeyUp)
			onKeyUp(this, key);
		else if(parent !is null) 
			parent.keyUp(key);
	}

	/**
	 * Trigger a mouseDown event and call the onMouseDown callback function if set. */ 
	void mouseDown(byte buttons, Vec2i coordinates){ 
		if(onMouseDown)
			onMouseDown(this, buttons, coordinates);
		else if(parent !is null) 
			parent.mouseDown(buttons, coordinates);
	}
	
	/**
	 * Trigger a mouseUp event and call the onMouseUp callback function if set. */ 
	void mouseUp(byte buttons, Vec2i coordinates){ 
		if(onMouseUp)
			onMouseUp(this, buttons, coordinates);
		else if(parent !is null) 
			parent.mouseUp(buttons, coordinates);
	}
	
	/**
	 * Trigger a mouseOver event and call the onMouseOver callback function if set. */ 
	void mouseOver(byte buttons, Vec2i coordinates){
		if(mouseIn == false){
			if(parent !is null) 
				parent.mouseOver(buttons, coordinates);			
			mouseIn = true;
			if(onMouseOver) 
				onMouseOver(this, buttons, coordinates);
		}
	}
	
	/**
	 * Trigger a mouseMove event and call the onMouseMove callback function if set. */ 
	void mouseMove(byte buttons, Vec2i rel){
		if(onMouseMove)
			onMouseMove(this, buttons, rel);
		else if(parent !is null) 
			parent.mouseMove(buttons, rel);
	}

	/**
	 * Trigger a mouseOut event and call the onMouseOut callback function if set */ 
	void mouseOut(Surface next, byte buttons, Vec2i coordinates)
	{
		if(mouseIn)
		{
			if(isChild(next))
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
	 * Trigger a resize event and call the onResize callback function if set */ 
	void resize(Vec2f amount)
	{	if (onResize)
			onResize(this, amount);
	}
	
}