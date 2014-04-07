/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.graphics.texture;

import tango.math.Math;
import yage.core.math.math;
import yage.core.math.matrix;
import yage.core.math.vector;
import yage.core.object2;
import yage.resource.dds;
import yage.resource.image;
import yage.resource.manager;
import yage.system.system;
import yage.system.log;
import std.string;

/**
 * An instance of a Texture.
 * This allows many options to be set per instance of a Texture instead of
 * creating multiple copies of the Texture (and consuming valuable memory)
 * just to change filtering, clamping, or relative scale. */
struct TextureInstance  // TODO: Rename to TextureProperties
{
	enum Filter ///
	{	DEFAULT,	///
		NONE,		///
		BILINEAR,	///
		TRILINEAR	///
	}
	
	// TODO: Use these intead of Filter?
	//int minFilter;
	//int magFilter;
	
	enum Blend
	{	NONE,
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
	int filter = TextureInstance.Filter.DEFAULT;
	
	///
	Matrix transform;

	/// 
	Texture texture;
	
	///
	string toString()
	{	return std.string.format(`TextureInstance {source: "%s"}`, texture ? texture.source : "null");
	}

	/// Create a new TextureInstance with the parameters specified.
	static TextureInstance opCall(Texture texture, bool clamp=false, int filter=TextureInstance.Filter.DEFAULT)
	{
		TextureInstance result;
		result.texture = texture;
		result.clamp = clamp;
		result.filter = filter;
		return result;
	}
}


/**
 * A Texture represents image data in video memory.
 *
 * There's no need to be concerned about making
 * texture dimensions a power of two, as they're automatically resized up to
 * the next highest supported size if the non_power_of_two OpenGL extension
 * isn't supported in hardware. */
class Texture : IRenderTarget
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
	ulong width = 0;
	ulong height = 0;	
	
	protected string source;	
	protected Image image; // if not null, the texture will be updated with this image the next time it is used.
	//protected ubyte[] ddsImageData;
	protected DDSImageData* ddsImageData;
	
	
	public string ddsFile;
	
	//public string ddsFile; // if not null, a dds texture will be loaded from this file the next time the texture is used.
	Vec2ul padding;	// padding stores how many pixels of the original texture are unused.
					// e.g. getWidth() returns the used texture + the padding.  
					// Padding is applied to the top and the right, and can be negative.
	
	bool flipped = false; // TODO: Find a better solution, use texture matrix?
	bool dirty = true; // if true the texture will be reuploaded
	
	///
	this()
	{
	}
	
	/**
	 * Create a Texture from an image.
	 * The image will be uploaded to memory when the Texture is first bound. */
	this(string filename, Format format=Texture.Format.AUTO, bool mipmap=true)
	{	source = ResourceManager.resolvePath(filename);
		this.format = format;
		this.mipmap = mipmap;
		
		if (filename[$-4..$]==".dds")
		{	ddsFile = source;
			ubyte[] contents = ResourceManager.getFile(filename);
			ddsImageData = loadDDSTextureFile(contents);
		}
		else
			setImage(new Image(source), format, mipmap, source);
	}
	
	///
	this(Image image, Format format=Texture.Format.AUTO, bool mipmap=true, string source="", bool padding=false)
	{	this.format = format;
		this.mipmap = mipmap;
		setImage(image, format, mipmap, source, padding);
	}
	
	/**
	 * If the texture is loaded from a dds file instead of an image, return the unparsed dds file contents.
	 * Otherwise an empty array is returned.  */
	DDSImageData* getDDSImageData()
	{	return ddsImageData;
	}
	
	/// Get / set the Image used by this texture.
	Image getImage()
	{	return image;		
	}
	
	/// Returns true if the Texture Format includes an alpha channel.
	bool hasAlpha()
	{	return format == Format.COMPRESSED_LUMINANCE_ALPHA || format == Format.LUMINANCE8_ALPHA8 || format == Format.COMPRESSED_RGBA || format == Format.RGBA8;
	}
	
	///
	void setImage(Image image)
	{	setImage(image, format, mipmap, source, padding.length2() != 0);
	}	
	/// ditto
	void setImage(Image image, Format format, bool mipmap=true, string source="", bool pad=false) /// ditto
	{	assert(image !is null);
		assert(image.getData() !is null);
		ddsImageData = null;
		
		this.image = image;
		this.format = format;
		this.mipmap = mipmap;
		this.source = source;
		
		if (pad) // if pad instead of resize.
		{
			int new_width = nextPow2(cast(uint)image.getWidth());
			int new_height = nextPow2(cast(uint)image.getHeight());
			padding.x = (new_width - cast(uint)image.getWidth());
			padding.y = (new_height - cast(uint)image.getHeight());
							
			if (image.getWidth() != new_width || image.getHeight() != new_height)
				image = image.crop(0, 0, new_width, new_height);
		} else
			padding = Vec2ul(0);
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
	override ulong getHeight() 
	{	return height; 
	}
	override ulong getWidth() /// ditto
	{	return width; 
	}

	/**
	 * Amount of padding to the top and right for non-power-of-two sized textures. */
	Vec2ul getPadding()
	{	return padding;
	}
	
	///
	string getSource()
	{	return source;
	}
}