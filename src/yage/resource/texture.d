/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.texture;

import tango.math.Math;
import yage.core.math.math;
import yage.core.math.matrix;
import yage.core.math.vector;
import yage.core.object2;
import yage.resource.image;
import yage.resource.manager;
import yage.resource.resource;
import yage.system.system;
import yage.system.log;

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
	
	public enum Blend
	{
		NONE,
		ADD,
		AVERAGE,
		MULTIPLY
	}


	/// Set how this texture is blended with others in the same layer.
	int blend = Blend.NONE;

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
}


/**
 * A GPUTexture represents image data in video memory.
 *
 * Also, there's no need to be concerned about making
 * texture dimensions a power of two, as they're automatically resized up to
 * the next highest supported size if the non_power_of_two OpenGL extension
 * isn't supported in hardware.
 * 
 * TODO: Should GPUTextue inherit Image? */
class GPUTexture : IRenderTarget
{
	public bool compress;
	public bool mipmap;
	public uint format;

	public int width = 0;
	public int height = 0;
	public char[] source;
	
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
	this(char[] filename, bool compress=true, bool mipmap=true)
	{	source = ResourceManager.resolvePath(filename);		
		setImage(new Image(source), compress, mipmap, source);
	}

	/// ditto
	this(Image image, bool compress=true, bool mipmap=true, char[] source="", bool pad=false)
	{	setImage(image, compress, mipmap, source, pad);
	}

	/// Get / set the Image used by this texture.
	Image getImage()
	{	return image;		
	}
	void setImage(Image image, bool compress=true, bool mipmap=true, char[] source="", bool pad=false) /// ditto
	{	assert(image !is null);
		assert(image.getData() !is null);		
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
		dirty = true;
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