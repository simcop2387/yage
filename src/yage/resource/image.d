/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.image;

import derelict.sdl.sdl;
import derelict.sdl.image;
import std.string;
import derelict.opengl.gl;
import derelict.opengl.glu;
import yage.core.misc;
import yage.resource.resource;
import yage.system.device;
import yage.system.constant;
import yage.system.log;


/// A class for loading and manipulating images.
class Image
{
	protected char[] source;
	protected ubyte[] data;
	protected uint width, height;
	protected int format;

	/// Construct and load image data from filename.
	this(char[] filename)
	{	load(filename);
	}

	/// Construct from image data in memory
	this (ubyte[] image, uint width, uint height, int format)
	{	data = image;
		this.width = width;
		this.height = height;
		this.format = format;
	}

	/// Get the raw image data.
	ubyte[] get()
	{	return data;
	}

	/**
	 * Get the format of the image.
	 * See Also:
	 * The IMAGE_FORMAT constants in system.constant. */
	int getFormat()
	{	return format;
	}

	/// Get the height of the image in pixels.
	int getHeight()
	{	return height;
	}

	/// Get the name of the file the image was loaded from, or an empty string if loaded from memory.
	char[] getSource()
	{	return source;
	}

	/// Get the width of the image in pixels.
	int getWidth()
	{	return width;
	}

	/// Resize the image via glu.
	void resize(int new_width, int new_height)
	{
		// Return if nothing to do
		if (width==new_width && height==new_height)
			return;

		// Translate format to glformat
		int[int] translate;
		translate[IMAGE_FORMAT_GRAYSCALE] = GL_LUMINANCE;
		translate[IMAGE_FORMAT_RGB] = GL_RGB;
		translate[IMAGE_FORMAT_RGBA] = GL_RGBA;
		int glformat = translate[format];

		// Resize the image.
		ubyte[] image2 = new ubyte[new_width*new_height*format];
		gluScaleImage(glformat, width, height, GL_UNSIGNED_BYTE, data.ptr, new_width, new_height, GL_UNSIGNED_BYTE, image2.ptr);
		data = image2;
		width = new_width;
		height = new_height;
	}

	/**
	 * Load an image from a file via SDL_Image. */
	protected void load(char[] filename)
	{
		// Attempt to load image
		source = Resource.resolvePath(filename);
		Log.write("Loading image '" ~ source ~ "'.");
		SDL_Surface *sdl_image;
		std.stdio.writefln(source);
		if ((sdl_image = IMG_Load(toStringz(source))) is null)
			throw new Exception("Could not open image file '" ~ source ~ "'.");
		width = sdl_image.w;
		height= sdl_image.h;

		// If loading non-paletted
		ubyte *pixels = cast(ubyte*)sdl_image.pixels;
		if (sdl_image.format.palette is null)
		{
			int[int] translate;
			translate[1] = IMAGE_FORMAT_GRAYSCALE;
			translate[3] = IMAGE_FORMAT_RGB;
			translate[4] = IMAGE_FORMAT_RGBA;
			format = translate[sdl_image.format.BytesPerPixel];
			data.length = sdl_image.pitch*height;
			// Swap Red and Blue if boolmap image
			if(tolower(source[length-4..length])==".bmp")
				for (int i=0; i<data.length; i+=3)
				{	data[i]   = pixels[i+2];
					data[i+1] = pixels[i+1];
					data[i+2] = pixels[i];
				}
			else
				memcpy(&data[0], sdl_image.pixels, data.length);
		}
		// If loading paletted, convert to RGB
		else
		{	format = IMAGE_FORMAT_RGB;
			data.length = 3*width*height;
			SDL_Color *palette =sdl_image.format.palette.colors;
			for (int i=0; i<width*height; i++)
			{	data[i*3]   = palette[pixels[i]].r;
				data[i*3+1] = palette[pixels[i]].g;
				data[i*3+2] = palette[pixels[i]].b;
		}	}

		SDL_FreeSurface(sdl_image);
	}
}
