/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.image;

import std.string;
import derelict.sdl.sdl;
import derelict.sdl.image;
import yage.resource.exceptions;

/**
 * A class for loading and manipulating images.
 * Supports loading images from any channels supported by SDL_Image.
 * Currently supports grayscale, RGB, and RGBA image data.
 * Bugs:
 * An RGB image will often be returned when loading grayscale images.  Use setFormat(IMAGE_FORMAT_GRAYSCALE) to correct this.
 * 
 * TODO: Add convolution support: http://www.php.net/manual/en/function.imageconvolution.php#77818 */
class Image
{
	// Types
	struct Pixel(int C)
	{	ubyte v[C];
	}
	alias Pixel!(1) Pixel1;
	alias Pixel!(2) Pixel2;
	alias Pixel!(3) Pixel3;
	alias Pixel!(4) Pixel4;
	
	const int FORMAT_GRAYSCALE=1;	/// A grayscale image
	const int FORMAT_RGB=3;			/// An image with red, green, and blue color channels
	const int FORMAT_RGBA=4;		/// An image with Red, green, blue, and alpha color channels
	
	// Fields
	protected ubyte[] data;
	protected int width, height, channels;
	
	// Empty Constructor, used internally
	protected this()
	{		
	}	

	/**
	 * Create a new emtpy image.
	 * Params:
	 *     channels = number of color channels.
	 *     width = width in pixels
	 *     height = height in pixel */
	this(int channels, int width, int height)
	{	data.length = channels*width*height;
		this.channels = channels;
		this.width = width;
		this.height = height;
	}
	
	/**
	 * Construct from image data in memory.  This does not create a copy of the data.
	 * Params:
	 *     image = array of raw image data
	 *     channels = number of color channels.
	 *     width = width in pixels
	 *     height = height in pixels, if 0 it is auto-calculated from width, channels, and data's length.*/	
	this(ubyte[] data, int channels, int width, int height=0)
	{	this.data = data;
		this.channels = channels;
		this.width = width;
		if (height)
			this.height = height;
		else if (width && channels)
			this.height = data.length / (width*channels);
		else
			this.height = 0;
	}
	
	/**
	 * Construct and load image data from a file.
	 * Params:
	 *     filename = absolute or relative path of an image file supported by sdl_image.
	 * Returns: An image with the number of channels of the source image.  Paletted images are converted to nonpaletted.*/
	this(char[] filename) 
	{		
		SDL_Surface *sdl_image;
		char* source = toStringz(filename);
		scope(exit) delete source;
		scope(exit) SDL_FreeSurface(sdl_image);
		
		// Attempt to load image
		if ((sdl_image = IMG_Load(source)) is null)
			throw new ResourceException("Could not open image file '%s'.", filename);		
		width = sdl_image.w;
		height = sdl_image.h;
		
		// If loading non-paletted		
		if (sdl_image.format.palette is null)
		{	channels = sdl_image.format.BytesPerPixel;
			data = new ubyte[channels*width*height]; // [below] make a copy because SDL_FreeSurface kills original data
			data[0..length] = cast(ubyte[])sdl_image.pixels[0..data.length]; 
			
			// Swap Red and Blue if RGB bitmap image
			if(tolower(filename[length-4..length])==".bmp" && channels >= 3)
				for (int i=0; i<data.length; i+=3)
				{	ubyte swap = data[i];				
					data[i] = data[i+2];
					data[i+2] = swap;
				}	
		}
		// If loading paletted
		else
		{	scope ubyte[] pixels = cast(ubyte[])sdl_image.pixels[0..sdl_image.pitch*sdl_image.h];
			data = new ubyte[3*sdl_image.w*sdl_image.h];
			channels = 3;
			
			// Convert to rgb.
			SDL_Color *palette = sdl_image.format.palette.colors;
			for (int i=0; i<sdl_image.w*sdl_image.h; i++)
			{	data[i*3]   = palette[pixels[i]].r;
				data[i*3+1] = palette[pixels[i]].g;
				data[i*3+2] = palette[pixels[i]].b;
			}
		}
	}
	
	/**
	 * Get the pixel color value at the coordinates using bilinear interpolation.
	 * See: http://en.wikipedia.org/wiki/Bilinear_filtering
	 * Params:
	 *     u = A value betwen 0 and 1.
	 *     v = A value betwen 0 and 1.*/
	Pixel4 bilinearFilter(float u, float v)
	{	
		u *= (width-1);
		v *= (height-1);
		int x = cast(int)u; // should be the same as floor(u)
		int y = cast(int)v;
		float u_ratio = u-x;
		float v_ratio = v-y;
		float u_opposite = 1 - u_ratio;
		float v_opposite = 1 - v_ratio;
		

		// Loop through each channel.
		Pixel4 result;
		
		for (int i=0; i<channels; i++)
		{	if (x<width-1 && y<height-1)	// Different calculations depending on what's inside array bounds.
				result.v[i] = cast(ubyte)(
					(this[x,y][i]   * u_opposite + this[x+1,y][i]   * u_ratio) * v_opposite + 
					(this[x,y+1][i] * u_opposite + this[x+1,y+1][i] * u_ratio) * v_ratio);
			else if (x<width-1)
				result.v[i] = cast(ubyte)(
					(this[x,y][i] * u_opposite + this[x+1,y][i] * u_ratio) * v_opposite + 
					(this[x,y][i] * u_opposite + this[x+1,y][i] * u_ratio) * v_ratio);
			else if (y<height-1)
				result.v[i] = cast(ubyte)(
					(this[x,y][i]   * u_opposite + this[x,y][i]   * u_ratio) * v_opposite + 
					(this[x,y+1][i] * u_opposite + this[x,y+1][i] * u_ratio) * v_ratio);
			else
				result.v[i] = cast(ubyte)this[x,y][i];
		}
		return result;			
	}


	/**
	 * Return the raw image data.
	 * The array length is always width*height*C.
	 * Row-major order is used.  This means that the array contains all of row 1's
	 * pixels, followed by row 2's pixels, etc.*/
	ubyte[] getData()
	{	return data;		
	}
	
	/// Get the number of color channels.
	int getChannels()
	{	return channels;		
	}

	/// Get the width or height of the image in pixels.
	int getWidth()
	{	return width;		
	}
	int getHeight() /// ditto.
	{	return height;
	}
	

	/// Get or set the ith pixel in the image.
	ubyte[] opIndex(size_t i)
	in { assert(i<width*height); }
	body
	{	return data[i..(i+channels)];
	}
	ubyte[] opIndexAssign(ubyte[] val, size_t i) /// ditto
	in { assert(i<width*height); }
	body
	{	return data[i..(i+channels)] = val[0..channels];
	}

	/// Get or set the pixel at the given coordinates.
	ubyte[] opIndex(size_t x, size_t y)
	in { assert(x<width && y<height); }
	body
	{	int i = (y*width+x)*channels;
		return data[i..(i+channels)];
	}
	ubyte[] opIndexAssign(ubyte[] val, size_t x, size_t y)	/// ditto
	in { assert(x<width && y<height); }
	body
	{	int i = (y*width+x)*channels;
		return data[i..(i+channels)] = val[0..channels];
	}

	/**
	 * Paste another image on top of this one.
	 * This does not make a copy. */
	void overlay(Image img, int xoffset=0, int yoffset=0)
	{
		for (int x=0; x<img.width; x++)
		{	int xoffsetx = xoffset + x;
			if (xoffsetx < width && xoffsetx > 0)
			{	for (int y=0; y<img.height; y++)
				{	// TODO: Replace with array slice copy.
					int yoffsety = yoffset+y;
					if (yoffsety < height && yoffsety > 0)
						this[xoffsetx, yoffsety][0..channels] = img[x, y][0..channels]; // TODO: convert format
		}	}	}
	}

	
	/**
	 * Return a c-style pointer to the image data.
	 * The length of the array is always width*height*channels. */
	void *ptr()
	{	return data.ptr;
	}

	/**
	 * Resize this image using bilinear interpolation.
	 * This is 5.5x faster than gluScaleImage (which also uses a bilinear filter when enlarging) in resizing from 32x32 to 512x512.  
	 * Params:
	 *     width = The new width.
	 *     height = The new height.  If 0, height will be calculated automatically with aspect ratio maintained.
	 * Returns: A new image of the same type and of the new size, or an exact copy if the dimensions are the same. */
	Image resize(int width, int height=0)
	{	Image result = new Image();
		result.width = width;
		if (height)
			result.height = height;
		else
			result.height = width*this.height/this.width;		
		result.channels = channels;
		
		// Return a copy if there's nothing to resize.
		if (result.width == this.width && result.height == this.height)
		{	result.data = this.data.dup;
			return this;
		}
		
		result.data.length = width*height*channels;
		float width1 = 1/(width-1.0f);
		float height1= 1/(height-1.0f);		
		
		for (int y=0; y<height; y++)
			for (int x=0; x<width; x++)
			{	//int i = (y*this.width+x)*channels;
				//std.stdio.writefln(x, " ", y, " ", result[x, y]);
				result[x, y][0..channels] = bilinearFilter(x*width1, y*height1).v[0..channels];	
			}
		
		return result;
	} 

	// TODO: modify this to return a new image in the given format.
	Image setFormat(int channels)
	{	if (channels == this.channels)
			return this;

		Image result = new Image(channels, width, height);
	
		switch (channels)
		{
			case 1:
				// Set each pixel to the average of RGB, dropping alpha if present
				for (int i=0; i<data.length-this.channels-1; i+=this.channels)
				{	int sum=0;
					for (int j=0; j<this.channels; j++)
						sum += data[i+j];
					result.data[i/this.channels] = cast(ubyte)(sum / this.channels);
				}
				this = result;
				break;
			case 3:
				// Copy gray channel into RGB
				if (this.channels == 1)
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
				if (this.channels == 4)
					for (int i=0; i<data.length; i+=4)
					{	data[i*3/4] = data[i];
						data.length = width*height*4;
					}
				break;
			case 4:
				throw new ResourceException("Not implemented yet :)");
				break;
			default:
				throw new ResourceException("Unrecognized image format.");
	
		}
		this.channels = channels;
		
		return this;
	}
	/**
	 * Return a new image that is a sub-image of this image.
	 * TODO: Replace this with crop.
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
		ubyte[] res_data = new ubyte[res_width*res_height*channels];
		Image result = new Image(res_data, res_width, res_height, channels);

		for (int y=top; y<bottom; y++)
			for (int x=left; x<right; x++)
			{	int src 	= (y*width+x)*channels;
				int dest	= ((y-top)*res_width+(x-left))*channels;
				res_data[dest..dest+channels] = data[src..src+channels];
			}
		
		return result;
	}
}
