/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.texture;

import tango.math.Math;
import yage.core.format;
import yage.core.math.math;
import yage.core.math.matrix;
import yage.core.math.vector;
import yage.core.object2;
import yage.resource.image;
import yage.resource.manager;
import yage.system.system;
import yage.system.log;

/**
 * An instance of a GPUTexture.
 * This allows many options to be set per instance of a GPUTexture instead of
 * creating multiple copies of the GPUTexture (and consuming valuable memory)
 * just to change filtering, clamping, or relative scale. */
struct Texture
{
	enum Filter ///
	{
		DEFAULT,	///
		NONE,		///
		BILINEAR,	///
		TRILINEAR	///
	}
	
	// TODO: Use these intead of Filter?
	//int minFilter;
	//int magFilter;
	
	enum Blend
	{
		NONE,
		ADD,
		AVERAGE,
		MULTIPLY
	}
	
	// TODO: Use this, it will replace clamp
	enum Wrap
	{	WRAP, // GL_REPEAT (default)
		MIRROR, // GL_MIRRORED_REPEAT
		CLAMP // GL_CLAMP_TO_EDGE
		// GL_CLAMP_TO_BORDER not supported.
	}
	Wrap wrap;
	
	int blend = Blend.NONE;		/// Set how this texture is blended with others in the same pass via multi-texturing.

	/// Property enable or disable clamping of the textures of this layer.
	/// See_Also: <a href="http://en.wikipedia.org/wiki/Texel_%28graphics%29">The Wikipedia entry for texel</a>
	bool clamp = false;

	/// Environment map?
	bool reflective = false;

	/// Property to set the type of filtering used for the textures of this layer.
	int filter = Texture.Filter.DEFAULT;
	
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
	
	char[] toString()
	{	return swritef(`Texture {source: "%s"}`, texture ? texture.source : "null");
	}
}


/**
 * A GPUTexture represents image data in video memory.
 *
 * Also, there's no need to be concerned about making
 * texture dimensions a power of two, as they're automatically resized up to
 * the next highest supported size if the non_power_of_two OpenGL extension
 * isn't supported in hardware. */
class GPUTexture : IRenderTarget
{
	
	
	// See: http://developer.nvidia.com/object/nv_ogl_texture_formats.html
	enum Format
	{	AUTO,                 /// Determine the format from the source image.
		AUTO_UNCOMPRESSED,    /// Pick the best format for the image, but don't lossfully compress it.
		COMPRESSED_LUMINANCE,
		COMPRESSED_LUMINANCE_ALPHA,
		COMPRESSED_RGB,
		COMPRESSED_RGBA,
		LUMINANCE8,
		LUMINANCE8_ALPHA8,
		RGB8,
		RGBA8,
	//	LUMINANCE16_ALPHA16,  // Pre Geforce6 emulates as L8A8
	//	RGB16,
	//	RGBA16,               // Pre Geforce 8 emulates as RGBA8
	//	DEPTH16,              // GL1.4 or ARB_DEPTH_TEXTURE
	//	DEPTH24,              // GL1.4 or ARB_DEPTH_TEXTURE
	//	R16F,                 // Floats require at least GeforceFX
	//	RG16F,
	//	RGB16F,
	//	RGBA16F,
	//	R32F,
	//	RG32F,
	//	RGB32F,
	//	RGBA32F
	}
	
	Format format;
	bool mipmap;	
	int width = 0;
	int height = 0;	
	
	protected char[] source;	
	protected Image image; // if not null, the texture will be updated with this image the next time it is used.
	Vec2i padding;	// padding stores how many pixels of the original texture are unused.
					// e.g. getWidth() returns the used texture + the padding.  
					// Padding is applied to the top and the right, and can be negative.
	
	bool flipped = false; // TODO: Find a better solution, use texture matrix?
	bool dirty = true; // if true the texture will be reuploaded
	
	///
	this()
	{
	}
	
	/**
	 * Create a GPUTexture from an image.
	 * The image will be uploaded to memory when the GPUTexture is first bound. */
	this(char[] filename, Format format=GPUTexture.Format.AUTO, bool mipmap=true)
	{	source = ResourceManager.resolvePath(filename);
		this.format = format;
		this.mipmap = mipmap;
		setImage(new Image(source), format, mipmap, source);
	}
	
	this(Image image, Format format=GPUTexture.Format.AUTO, bool mipmap=true, char[] source="", bool padding=false)
	{	this.format = format;
		this.mipmap = mipmap;
		setImage(image, format, mipmap, source, padding);
	}

	/// Get / set the Image used by this texture.
	Image getImage()
	{	return image;		
	}
	
	void setImage(Image image)
	{	setImage(image, format, mipmap, source, padding.length2() != 0);
	}
	
	void setImage(Image image, Format format, bool mipmap=true, char[] source="", bool pad=false) /// ditto
	{	assert(image !is null);
		assert(image.getData() !is null);		
		this.image = image;
		this.format = format;
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
		dirty = true;
	}

	/// Are mipmaps used?
	bool getMipmapped() 
	{	return mipmap; 
	}

	/**
	 * Get the format of the Texture. */
	Format getFormat()
	{	return format;
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
}