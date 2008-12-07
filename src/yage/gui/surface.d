/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:	   Joe Pusderis (deformative0@gmail.com), Eric Poggel
 * License:	   <a href="lgpl.txt">LGPL</a> 
 */

module yage.gui.surface;

import std.stdio;
import std.math;
import derelict.opengl.gl;
import derelict.sdl.sdl;
import derelict.opengl.glext;
import derelict.opengl.glu;
import derelict.opengl.extension.ext.blend_color; // opengl 1.2
import yage.core.all;
import yage.core.matrix;
import yage.system.device;
import yage.system.constant;
import yage.system.input;
import yage.system.probe;
import yage.resource.texture;
import yage.resource.image;
import yage.gui.style;
import yage.system.interfaces;


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
	char[] text;
	Image textImage;
	Texture textTexture;
	
	/// This is a mirror of SDLMod (SDL's modifier key struct
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
	Vec2f topLeft;		// pixel distance of the topleft corner from parent's top left
	Vec2f bottomRight;	// pixel distance of the bottom right corner from parent's top left
	Vec2f offset;		// pixel distance of top left from the window's top left at 0, 0
	
	bool mouseIn; // used to track mouseover/mouseout
	bool _grabbed;
	
	protected Style old_style; // Used for comparison to see if dirty.
	protected Surface old_parent;
	protected float old_parent_width;
	protected float old_parent_height;
	protected char[] old_text;
	
	protected float[72] vertices = 0; // Used for rendering
	protected float[72] tex_coords = 0;

	/// Callback functions
	// TODO convert these to private and have functions to set them with such names as onBlur();
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
	{	update();		
	}
	
	~this()
	{
		// free textures?  should be done automatically by gc?
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
	 * Recalculate all properties of this Surface based on its style.
	 * TODO: Ensure vertex and tex coord assignments are 100% on the stack (see array literals).*/
	void update()
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
		
		// Ensure at least 4 of the 6 dimensions are set.
		if (isnan(left))
		{	if (isnan(right))
				left = 0.0f;
			if (isnan(width))
				width = parent_width;			
		}	
		if (isnan(top))
		{	if (isnan(bottom))
				top = 0.0f;
			if (isnan(height))
				height = parent_height;				
		}	

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
			calculateVertices();
			
			// Calculate children to update positions and offset.
			foreach (c; children)
				c.update();			
			// Call resize if resized.
			if (resized_length2 > 0)
				resize(resized_by);
		}
	}
	
	protected void calculateVertices()
	{
		// Calculate vertices
		Vec2f portion;
		
		// Portion of the Texture to use for drawing
		// This won't be necessary when we support rectangular textures.
		if (style.backgroundMaterial)
		{	portion.x = style.backgroundMaterial.padding.x/cast(float)style.backgroundMaterial.getWidth();
			portion.y = style.backgroundMaterial.padding.y/cast(float)style.backgroundMaterial.getHeight();
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
				tex_coords[0..8] = [0.0f, portion.y, portion.x, portion.y, portion.x, 0, 0, 0];
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
				// static arrays to ensure this operation is 100% on the stack.
				float[72] vertices_temp = [
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
				float[72] tex_coords_temp = [
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
				vertices[0..72] = vertices_temp[0..72];
				tex_coords[0..72] = tex_coords_temp[0..72];
				
				break;
		}		
	}
	
	/**
	 * Render this Surface a rendering target.
	 * TODO: Move this to Window?
	 * Params:
	 *     rt = TODO: Render to this target.*/
	void render(IRenderTarget rt=null) 
	{
		//if (rt)
		//	rt.bind();

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
	 * If enabled, the mousecursor will be hidden and grabbed by the application.
	 * This also allows for mouse position changes to be registered in a relative fashion,
	 * i.e. even when the mouse is at the edge of the screen.  This is ideal for attaching
	 * the mouse to the look direction of a first or third-person camera. */
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
		Input.grabbed = this._grabbed = grab;
	}
	
	bool grabbed()
	{	return _grabbed;		
	}
	
	/**
	 * Set the zIndex of this Surface to one more or less than the highest or lowest of its siblings. */
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
			update();
			
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
	 * Draw this Surface and call the Surface's onDraw method if it is not null.
	 * When finished, the draw methods of all of this Surface's children are called. */
	void draw()
	{
		if (onDraw)
			onDraw(this);
		
		// Draw the quad for this surface.
		void drawQuad(int style)
		{	
			// In case something else didn't leave it bound as 0.
			if(Probe.openGL(Probe.OpenGL.VBO))
				glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);
			
			switch(style)
			{	case Style.NONE:
		
				case Style.STRETCH:
					glDrawArrays(GL_QUADS, 0, 4);
					break;
				case Style.NINESLICE:
					glDrawArrays(GL_QUADS, 0, 36);
					break;
				default: assert(false);
			}
		}
		
		/*
		 * Set this Surface as non dirty and return whether it was previously dirty */
		bool dirty()
		{	
			// doesn't catch parent resizes
			
			bool result = false;
			if (style != old_style)
			{	old_style = style;			
				result = true;
			}
			if (parent !is old_parent)
			{	old_parent = parent;
				result = true;
			}
			if (old_parent_width != parentWidth())
			{	old_parent_width = parentWidth();
				result = true;
			}
			if (old_parent_height != parentHeight())
			{	old_parent_height = parentHeight();
				result = true;
			}
			return result;
		}
		
		
		if (style.visible)
		{			
			// Update positions
			bool is_dirty = dirty();
			if (is_dirty)
				update();			
			
			// Must be called at every draw because the surface's texture's material can have its portion change.
			// TODO: Figure out a way to only recalculate that when dirty.
			calculateVertices();
			
			// Translate to the topleft corner of this 
			glPushMatrix();
			glTranslatef(topLeft.x, topLeft.y, 0);
			
			// Draw background color
			if (style.backgroundColor.a > 0) // If backgroundColor alpha.
			{	glColor4ubv(style.backgroundColor.ub.ptr);
				glVertexPointer(2, GL_FLOAT, 0, vertices.ptr);
				drawQuad(Style.STRETCH);
				glColor4f(1, 1, 1, 1);
			}
			
			// Draw background material
			if (style.backgroundMaterial !is null)
			{	glEnable(GL_TEXTURE_2D);
				Texture tex = Texture(style.backgroundMaterial, false, TEXTURE_FILTER_BILINEAR);				
							
				if (style.backgroundMaterial.flipped) // TODO: fix this horrible hack!
				{	tex.transform = Matrix([
						1f, 0, 0, 0,
						0,-1, 0, 0,
						0, 0, 1, 0,
						0, 0, 0, 1
					]);
					float portion = style.backgroundMaterial.padding.y/cast(float)style.backgroundMaterial.getHeight();
					tex.position = Vec2f(0, -1 + portion);
				}
				tex.bind();
				glVertexPointer(2, GL_FLOAT, 0, vertices.ptr);
				glTexCoordPointer(2, GL_FLOAT, 0, tex_coords.ptr);
				drawQuad(style.backgroundRepeat);				
				tex.unbind();
			}
			
			// Update Text
			// TODO: check style font properties for changes also; font size, family, text align
			if (style.fontFamily)
				if (is_dirty || text != old_text)
				{	textImage = style.fontFamily.render(text, cast(int)style.fontSize, cast(int)style.fontSize, cast(int)width(), -1, style.textAlign, true);
					if (!textTexture.texture)
						textTexture = Texture(new GPUTexture(textImage, false, false, text), true, TEXTURE_FILTER_BILINEAR);
					else
						textTexture.texture.create(textImage, false, false);
					old_text = text;
				}
			
			// Draw Text
			if (textTexture.texture)
			{					
				float ws = textImage.getWidth();
				float hs = textImage.getHeight();				
				float[8] vertices = [0.0f, hs, ws, hs, ws, 0, 0, 0];
				float[8] tex_coords=[0.0f, 1, 1, 1, 1, 0, 0, 0];
				
				// Apply States
				glEnable(GL_TEXTURE_2D);
				textTexture.bind();
				
				glPushMatrix();
				glVertexPointer(2, GL_FLOAT, 0, vertices.ptr);
				glTexCoordPointer(2, GL_FLOAT, 0, tex_coords.ptr);
				
				// This extension is available as of OpenGL 1.1 or 1.2 and allows drawing colored text in a single pass.
				if (Probe.openGL(Probe.OpenGL.BLEND_COLOR))
				{	
					// Apply states
					Vec4f color = style.color.vec4f;	
					glBlendFunc(GL_CONSTANT_COLOR_EXT, GL_ONE_MINUS_SRC_COLOR);
					glBlendColorEXT(color.r, color.g, color.b, 1);
					glColor3f(color.a, color.a, color.a);
				
					glDrawArrays(GL_QUADS, 0, 4);
					
					// Revert states
					glColor4f(1, 1, 1, 1);
					glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA); // reset blend function
				} else
				{
					/// TODO: see http://dsource.org/projects/arclib/browser/trunk/arclib/freetype/freetype/font.d
				}
				
				// Revert States
				glPopMatrix();
				textTexture.unbind();
			}			
			
			glDisable(GL_TEXTURE_2D);
				
			// Using a zbuffer might make this unecessary.  tradeoffs?
			if (!children.sorted(true, (Surface s){return s.style.zIndex;} ))
				children.radixSort(true, (Surface s){return s.style.zIndex;} );
			
			// Recurse through and draw children.
			foreach(surf; children)
				surf.draw();
			
			glPopMatrix();
		}
	}
	
	/**
	 * Release focus from this surface and call the onBlur callback function if set. */
	void blur(){
		if(onBlur)
			onBlur(this);
		Input.surfaceLock = null;
	}
	
	/**
	 * Trigger a keyDown event and call the onKeyDown callback function if set. 
	 * If the onKeyDown function is not set, call the parent's keyDown function. */ 
	void keyDown(int key, int mod=ModifierKey.NONE)
	{	if(onKeyDown)
			onKeyDown(this, key, mod);
		else if(parent !is null) 
			parent.keyDown(key, mod);
	}
	
	/**
	 * Trigger a keyUp event and call the onKeyUp callback function if set. 
	 * If the onKeyUp function is not set, call the parent's keyUp function.*/ 
	void keyUp(int key, int mod=ModifierKey.NONE)
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