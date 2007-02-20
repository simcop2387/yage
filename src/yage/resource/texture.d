/**
 * Copyright:  (c) 2006-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.texture;


import std.string;
import std.math;
import std.stdio;
import derelict.sdl.sdl;
import derelict.sdl.image;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;
import yage.core.misc;
import yage.resource.resource;
import yage.resource.image;
import yage.system.constant;
import yage.system.device;
import yage.system.log;


/**
 * A Texture is a represenation of image data in system and video memory.
 * Each Texture has two main parts, an image stored in system memory
 * and an index that is used to reference it in video memory.
 * The process of creating a texture involves loading an image
 * (PNG, JPG, BMP, PXC, TGA, etc. are all supported), setting various OpenGL
 * options such as compression, filtering, mipmapping, etc., and finally
 * uploading it to video memory.\n\n
 * In addition to support for multiple image formats, this class can store
 * and upload images of 8-bool grayscale, 24-bool color, and 32-bool color with
 * an alpha channel.  Also, there's no need to be concerned about making
 * texture dimensions a power of two, as they're automatically resized up to
 * the next highest supported size if the non_power_of_two OpenGL extension
 * isn't supported in hardware. */
class Texture
{
	protected:

	bool compress;
	bool mipmap;
	int format;

	uint gl_index  = 0;	// opengl index of this texture
	uint width     = 0;
	uint height    = 0;
	char[] source;

	public:

	this()
	{	glGenTextures(1, &gl_index);
	}

	/**
	 * Create a Texture from an image.
	 * This is equivalent to calling the default constructor followed by upload().*/
	this(char[] filename, bool compress=true, bool mipmap=true)
	{	this();
		upload(new Image(filename), compress, mipmap);
	}

	/// Ditto
	this(Image image, bool compress=true, bool mipmap=true)
	{	this();
		upload(image, compress, mipmap);
	}

	/// Release OpenGL texture index.
	~this()
	{	Log.write("Removing texture '" ~ source ~ "' from video memory.");
		try // Because of a conflict with SDL_Quit();
		{	glDeleteTextures(1, &gl_index); }
		catch {}
	}

	/// Is texture compression used in video memory?
	bool getCompressed() { return compress; }

	/// Are mipmaps used?
	bool getMipmapped() { return mipmap; }

	/**
	 * Get the format of the Texture.
	 * See_Also: yage.system.constant */
	uint getFormat() { return format; }

	/// What is the OpenGL index of this texture?
	uint getIndex() { return gl_index; }

	/// Return the width of the Texture in pixels.
	uint getWidth() { return width; }

	/// Return the height of the Texture in pixels.
	uint getHeight() { return height; }

	/// Bind this Texture as the current OpenGL texture
	void bind(bool clamp=false, int filter=TEXTURE_FILTER_TRILINEAR)
	{	glBindTexture(GL_TEXTURE_2D, gl_index);

		// Filtering
		if (filter == TEXTURE_FILTER_DEFAULT)
			filter = TEXTURE_FILTER_TRILINEAR;	// Create option to set this later
		switch(filter)
		{	case TEXTURE_FILTER_NONE:
				if (mipmap)
					 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST);
				else glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
				break;

			case TEXTURE_FILTER_BILINEAR:
				if (mipmap)
					 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_NEAREST);
				else glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
				break;
			case TEXTURE_FILTER_TRILINEAR:
				if (mipmap)
					 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
				else glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
				break;
		}

		// Clamping
		if (clamp)
		{	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		}else // OpenGL Default
		{	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		}
	}

	/**
	 * Set the Texture from an Image.
	 * The image is uploaded into video memory and resized to a power of two if necessary.
	 * Params:
	 * image = The image to use for the Texture.
	 * compress = Compress the image in video memory.  This causes a slight loss of quality
	 * in exchange for four times less memory used.
	 * mipmap = Generate mipmaps.*/
	void upload(Image image, bool compress=true, bool mipmap=true)
	{
		this.compress = compress;
		this.mipmap = mipmap;
		this.format = image.getFormat();
		this.width = image.getWidth();
		this.height = image.getHeight();
		this.source = image.getSource();

		Log.write("Uploading image '" ~ source ~ "' to video memory.");
		glBindTexture(GL_TEXTURE_2D, gl_index);

		// Calculate formats
		uint glformat, glinternalformat;
		switch(format)
		{	case IMAGE_FORMAT_GRAYSCALE:
				glformat = GL_LUMINANCE;
				glinternalformat = compress ? GL_COMPRESSED_LUMINANCE : GL_LUMINANCE;
				break;
			case IMAGE_FORMAT_RGB:
				glformat = GL_RGB;
				glinternalformat = compress ? GL_COMPRESSED_RGB : GL_RGB;
				break;
			case IMAGE_FORMAT_RGBA:
				glformat = GL_RGBA;
				glinternalformat = compress ? GL_COMPRESSED_RGBA : GL_RGBA;;
				break;
			default:
				throw new Exception("Unknown image format.");
		}

	    // Upload image
	    if (mipmap)
			gluBuild2DMipmaps(GL_TEXTURE_2D, glinternalformat, image.getWidth(), image.getHeight(), glformat, GL_UNSIGNED_BYTE, image.get().ptr);
		else
		{
			uint max = Device.getLimit(DEVICE_MAX_TEXTURE_SIZE);
			uint newwidth = image.getWidth();
			uint newheight= image.getHeight();

			// Ensure power of two sized if required
			if (!Device.getSupport(DEVICE_NON_2_TEXTURE))
			{	if (log2(newheight) != floor(log2(newheight)))
					newheight = nextPow2(newheight);
				if (log2(newwidth) != floor(log2(newwidth)))
					newwidth = nextPow2(newwidth);
			}

			// Resize if necessary
			image.resize(mini(newwidth, max), mini(newheight, max));
			glTexImage2D(GL_TEXTURE_2D, 0, glinternalformat, image.getWidth(), image.getHeight(), 0, glformat, GL_UNSIGNED_BYTE, image.get().ptr);

	    }
	}

	/// Copy the the contents of the framebuffer into this Texture.
	void loadFrameBuffer(uint width, uint height)
	{
		// A special value of zero to stretch to the window size.
		if (width ==0) width  = Device.getWidth();
		if (height==0) height = Device.getHeight();

		// Needs to be tested.
		if (!Device.getSupport(DEVICE_NON_2_TEXTURE))
		{	this.width = nextPow2(width);
			this.height =nextPow2(height);
		}

		glBindTexture(GL_TEXTURE_2D, gl_index);
		glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 0, 0, this.width, this.height, 0);
		format = IMAGE_FORMAT_RGB;
	}
}

/**
 * A Texture that is used as a rendering target by a Camera.
 * Since not all video hardware supports non-power of two sized Textures,
 * Textures are oversized to the next power of two when necessary.
 * It is then necessary to store the size the texture wishes it was. */
class CameraTexture : Texture
{	uint requested_width   = 0;
	uint requested_height  = 0;

	this()
	{	super();
	}

	/// loadFrameBuffer is overridden to set requested_width and requested_height.
	void loadFrameBuffer(uint _width, uint _height)
	{	super.loadFrameBuffer(_width, _height);
		requested_width  =_width;
		requested_height =_height;
	}
}
