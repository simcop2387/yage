/**
 * Copyright:  (c) 2006-2007 Eric Poggel
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


/**
 * A class for loading and manipulating images.
 * Supports loading images from any format supported by SDL_Image.
 * Currently supports grayscale, RGB, and RGBA image data.
 * Bugs:
 * An RGB image will often be returned when loading grayscale images.  Use setFormat(IMAGE_FORMAT_GRAYSCALE) to correct this.
 * The load and resize functions seem to have images with widths that aren't a multiple of 4.*/
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

	/**
	 * Construct from image data in memory
	 * Params:
	 * image = a 1-dimensional array of raw image data
	 * width = height in pixels
	 * height = height in pixels
	 * format = one of the IMAGE_FORMAT_* constants from yage.system.constant*/
	this (ubyte[] image, uint width, uint height, int format)
	{	data = image;
		this.width = width;
		this.height = height;
		this.format = format;
	}

	/**
	 * Return the raw image data.
	 * Row-major order is used.  This means that the array contains all of row 1's
	 * pixels, followed by row 2's pixels, etc.*/
	ubyte[] get()
	{	return data;
	}

	/**
	 * Get the format of the image.
	 * See_Also:
	 * The IMAGE_FORMAT_* constants in system.constant. */
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

	/// Get the ith pixel in the image.
	ubyte[] opIndex(size_t i)
	in { assert(i<width*height); }
	body
	{	return data[i*format..i*format+format];
	}

	/// Get the pixel at the given coordinates.
	ubyte[] opIndex(size_t x, size_t y)
	in { assert(x<width && y<height); }
	body
	{	int i = y*width+x;
		return data[i*format..i*format+format];
	}

	///
	void *ptr()
	{	return data.ptr;
	}

	/**
	 * Resize the image via glu.
	 * Bugs:
	 * This function often produces weird results if new_width is not a multiple of 4. */
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

		delete data;
		data = image2;
		width = new_width;
		height = new_height;
	}

	/**
	 * Set the format of the image data.
	 * This is an in-place operation.
	 * Params:
	 * format = one of the IMAGE_FORMAT_* constants from yage.system.constant */
	void setFormat(int format)
	{	if (format == this.format)
			return;

		int bpp = this.format;
		ubyte[] result;

		switch (format)
		{
			case IMAGE_FORMAT_GRAYSCALE:
				// Set each pixel to the average of RGB, dropping alpha if present
				for (int i=0; i<data.length-2; i+=bpp)
					data[i/bpp] = (data[i] + data[i+1] + data[i+2]) / 3;
				data.length = width*height;
				break;
			case IMAGE_FORMAT_RGB:
				// Copy gray channel into RGB
				if (this.format == IMAGE_FORMAT_GRAYSCALE)
				{	ubyte[] temp = new ubyte[data.length];
					temp[0..length] = data[0..length];	// temp is copy of existing grayscale
					data.length = width*height*3;
					for (int i=0; i<temp.length; i++)
					{	data[i*3]   = 	// copy temp into all
						data[i*3+1] = 	// 3 channels of data
						data[i*3+2] = temp[i];
					}
					delete temp;
				}
				// Drop alpha channel (untested)
				if (this.format == IMAGE_FORMAT_RGBA)
					for (int i=0; i<data.length; i+=4)
					{	data[i*3/4] = data[i];
						data.length = width*height*3;
					}
				break;
			case IMAGE_FORMAT_RGBA:
				throw new Exception("Not implemented yet :)");
				break;
			default:
				throw new Exception("Unrecognized image format.");

		}
		this.format = format;
	}

	/**
	 * Return a new image that is a sub-image of this image.
	 * The four parameters should be in pixels.
	 * The sub-image will start with the pixels including top and left
	 * and stop just before pixels specified by bottom and right. */
	Image subImage(int top, int left, int bottom, int right)
	in	// check dimensions
	{	assert(top<bottom && left<right);
		assert(0<=top && 0<= left);
		assert(right <= width && bottom<=height);
	}body
	{	int res_width = right-left;
		int res_height= bottom-top;
		ubyte[] res_data = new ubyte[res_width*res_height*format];
		Image result = new Image(res_data, res_width, res_height, format);

		for (int y=top; y<bottom; y++)
			for (int x=left; x<right; x++)
			{	int src 	= (y*width+x)*format;
				int dest	= ((y-top)*res_width+(x-left))*format;
				res_data[dest..dest+format] = data[src..src+format];
			}
		return result;
	}

	/**
	 * Load an image from a file via SDL_Image. */
	protected void load(char[] filename)
	{
		// Attempt to load image
		source = Resource.resolvePath(filename);
		Log.write("Loading image '" ~ source ~ "'.");
		SDL_Surface *sdl_image;
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
			// Swap Red and Blue if RGB bitmap image
			if(tolower(source[length-4..length])==".bmp" && format == IMAGE_FORMAT_RGB)
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
