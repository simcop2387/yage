/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.texture;

import tango.math.Math;
import tango.io.Stdout;
import derelict.opengl.gl;
import derelict.opengl.glu;
import yage.core.closure;
import yage.core.math.math;
import yage.core.math.matrix;
import yage.core.timer;
import yage.core.math.vector;
import yage.core.object2;
import yage.resource.image;
import yage.resource.layer;
import yage.resource.manager;
import yage.resource.resource;
import yage.system.system;
import yage.system.graphics.probe;
import yage.system.log;

import yage.system.graphics.graphics;

/**
 * An instance of a GPUTexture.
 * This allows many options to be set per instance of a GPUTexture instead of
 * creating multiple copies of the GPUTexture (and consuming valuable memory)
 * just to change filtering, clamping, or relative scale. */
struct Texture
{
	public enum Filter ///
	{
		DEFAULT,	///
		NONE,		///
		BILINEAR,	///
		TRILINEAR	///
	}


	/// Set how this texture is blended with others in the same layer.
	int blend = BLEND_NONE;

	/// Property enable or disable clamping of the textures of this layer.
	/// See_Also: <a href="http://en.wikipedia.org/wiki/Texel_%28graphics%29">The Wikipedia entry for texel</a>
	bool clamp = false;

	/// Environment map?
	bool reflective = false;

	/// Property to set the type of filtering used for the textures of this layer.
	int filter = Texture.Filter.DEFAULT;

	/// Optional, the name of the sampler variable that uses this texture in the shader program.
	char[] name;
	
	///
	Matrix transform;

	/// 
	GPUTexture texture;
	
	protected static int[int] translate;

	/// Create a new TextureInstance with the parameters specified.
	static Texture opCall(GPUTexture texture, bool clamp=false, int filter=Texture.Filter.DEFAULT)
	{
		Texture result;
		result.texture = texture;
		result.clamp = clamp;
		result.filter = filter;
		return result;
	}
	
	/// deprecated.
	/// Undo state changes caused by binding this TextureInstance.
	void unbind()
	{	
		// Texture Matrix
		//if (position.length2() || scale.length2() || rotation!=0)
		{	glMatrixMode(GL_TEXTURE);
			glPopMatrix();
			glMatrixMode(GL_MODELVIEW);
		}

		// Environment Map
		if (reflective)
		{	glEnable(GL_TEXTURE_GEN_S);
			glEnable(GL_TEXTURE_GEN_T);
			glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
			glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
		}

		// Blend
		if (blend != BLEND_MULTIPLY)
			glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
		
		glBindTexture(GL_TEXTURE_2D, 0);
	}
}


/**
 * A GPUTexture represents image data in video memory.
 *
 * Also, there's no need to be concerned about making
 * texture dimensions a power of two, as they're automatically resized up to
 * the next highest supported size if the non_power_of_two OpenGL extension
 * isn't supported in hardware.*/
class GPUTexture : ExternalResource, IRenderTarget
{
	public bool compress;
	public bool mipmap;
	public uint format;

	public uint id = 0;	// opengl index of this texture
	public int width = 0;
	public int height = 0;
	public char[] source;
	
	public Image image; // if not null, the texture will be updated with this image the next time it is used.

	static uint[] garbageIds;
	
	Vec2i padding;	// padding stores how many pixels of the original texture are unused.
					// e.g. getWidth() returns the used texture + the padding.  
					// Padding is applied to the top and the right, and can be negative.
	
	bool flipped = false; // TODO: Find a better solution, use texture matrix?
	
	///
	this()
	{	super();
	}

	/**
	 * Create a GPUTexture from an image.
	 * The image will be uploaded to memory when the GPUTexture is first bound. */
	this(char[] filename, bool compress=true, bool mipmap=true)
	{	super();
		source = ResourceManager.resolvePath(filename);		
		this.compress=  compress;
		this.mipmap = mipmap;
		this.image = new Image(source);
	}

	/// ditto
	this(Image image, bool compress=true, bool mipmap=true, char[] source="", bool pad=false)
	{	super();
		this.image = image;
		this.compress=  compress;
		this.mipmap = mipmap;
		this.source = source;
		
		if (pad) // if pad instead of resize.
		{
			int new_width = nextPow2(image.getWidth());
			int new_height = nextPow2(image.getHeight());
			padding.x = (new_width - image.getWidth());
			padding.y = (new_height - image.getHeight());
							
			if (image.getWidth() != new_width || image.getHeight() != new_height)
				image = image.crop(0, 0, new_width, new_height);
		} else
			padding = Vec2i(0);
	}

	/**
	 * Release the Texture id and mark it for collection. */
	~this()
	{	dispose();
	}
	void dispose() /// ditto
	{	super.dispose();
		if (id)
		{	garbageIds ~= id;
			id = 0;
		}
		if (image)
			image = null;
	}
	
	/**
	 * Returns:  The image that's used for this texture. */
	Image getImage()
	{	return image;		
	}

	/// Is texture compression used in video memory?
	bool getCompressed() 
	{	return compress; 
	}

	/// Are mipmaps used?
	bool getMipmapped() 
	{	return mipmap; 
	}

	/**
	 * Get the format of the Texture. */
	uint getFormat()
	{	return format;
	}

	/// What is the OpenGL index of this texture?
	uint getId() 
	{	return id;
	}

	/**
	 * Returns: The width/height of the Texture in pixels. */
	override int getHeight() 
	{	return height; 
	}
	override int getWidth() /// ditto
	{	return width; 
	}

	/**
	 * Amount of padding to the top and right for non-power-of-two sized textures. */
	Vec2i getPadding()
	{	return padding;
	}
	
	///
	char[] getSource()
	{	return source;
	}

	/**
	 * Returns: Hardware vertex buffer id's from garbage collected VertexBuffer's. */
	static uint[] getGarbageIds()
	{	return garbageIds;
	}
	static void clearGarbageIds()
	{	garbageIds.length = 0;
	}
}