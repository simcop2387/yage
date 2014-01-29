/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.image;

import tango.io.Stdout;
import tango.math.Math;
import tango.text.Unicode;
import tango.stdc.stringz;
import derelict.sdl2.sdl;
import derelict.sdl2.image;
import yage.core.object2;
import yage.core.color;

/**
 * A class for loading and manipulating images.
 * Supports loading images from any channels supported by SDL_Image.
 * Currently supports grayscale, RGB, and RGBA image data.
 * Bugs:
 * An RGB image will often be returned when loading grayscale images.  Use setFormat(IMAGE_FORMAT_GRAYSCALE) to correct this.
 * 
 * TODO: Add convolution support: http://www.php.net/manual/en/function.imageconvolution.php#77818
 * TODO: Convert to struct? */
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
	
	///The pixel format, also the bytes-per-pixel
	static enum Format
	{	GRAYSCALE=1,
		RGB=3,
		RGBA=4		
	};

	// Fields
	ubyte[] data;
	protected int width, height;
	protected byte channels;
	char[] source;
	
	// Empty Constructor, used internally
	protected this()
	{		
	}	

	/**
	 * Create a new image from existing data
	 * Params:
	 *     channels = number of color channels.
	 *     width = width in pixels
	 *     height = height in pixel */
	this(int channels, int width, int height, ubyte[] lookaside = null)
	{	int size = channels*width*height;
		if (lookaside.length < size)
			lookaside.length = size;
		data = lookaside;
		
		//data.length = channels*width*height;
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
		char* source = toStringz(filename); // garbage
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
			if(toLower(filename[length-4..length])==".bmp" && channels >= 3)
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
		Pixel4 result;	
		if (!(0<=u && u<=1) || !(0<=v && v<=1))
			return result;
		u *= (width-1);
		v *= (height-1);
		int x = cast(int)u; // should be the same as floor(u), but faster
		int y = cast(int)v;
		int u_ratio = cast(int)(u*255)-x*255;
		int v_ratio = cast(int)(v*255)-y*255;
		int u_opposite = 255 - u_ratio;
		int v_opposite = 255 - v_ratio;

		// Loop through each channel.
		for (int i=0; i<channels; i++)
		{	int ywidthx = y*width+x;
			int y1widthx = ywidthx + width;
			if (x<width-1 && y<height-1)	// Different calculations depending on what's inside array bounds.
			{	result.v[i] = cast(ubyte) ((
					(data[ywidthx*channels + i] * u_opposite + data[(ywidthx+1)*channels + i] * u_ratio) * v_opposite + 						
					(data[y1widthx*channels + i] * u_opposite + data[(y1widthx+1)*channels + i] * u_ratio) * v_ratio
				)>> 16) + 2;
			}			
			else if (x<width-1)
				result.v[i] = cast(ubyte)((
					(data[ywidthx*channels + i] * u_opposite + data[ywidthx*channels + i + channels] * u_ratio) * v_opposite + 
					(data[ywidthx*channels + i] * u_opposite + data[ywidthx*channels + i + channels] * u_ratio) * v_ratio) >> 16);
			else if (y<height-1)
				result.v[i] = cast(ubyte)(
					((data[ywidthx*channels + i] * u_opposite + data[ywidthx*channels + i] * u_ratio) * v_opposite + 
					(data[y1widthx*channels + i] * u_opposite + data[y1widthx*channels + i] * u_ratio) * v_ratio) >> 16);
			else
				result.v[i] = cast(ubyte)this[x,y][i]; 
		}
		return result;			
	}
	unittest
	{	// Complete coverage of all paths for a monochrome image (?)
		auto img = new Image([255, 0, 0, 255], 1, 2, 2);
		assert(img.bilinearFilter(0, 0).v[0] == 255);		
		assert(img.bilinearFilter(0, 1).v[0] == 0);
		assert(img.bilinearFilter(1, 0).v[0] == 0);
		assert(img.bilinearFilter(1, 1).v[0] == 255);		
		assert(img.bilinearFilter(.5, .5).v[0] == 128);
	}

	/**
	 * Crop the image.
	 * The four parameters define a box, in coordinates relative to the top left of the source image.
	 * For example, crop(0, 0, width, height) would return an exact copy of the original image.
	 * Params:
	 *     left = left side of the cropping box.  This and the other parameters can be positive or negative.
	 *     top =  top side of the cropping box.
	 *     right = right side of the cropping box
	 *     bottom = bottom side of the cropping box.
	 * Returns: A new image of the size right-left, bottom-top */
	Image crop(int left, int top, int right, int bottom)
	{
		Image result = new Image(channels, right-left, bottom-top);
		for (int x=left; x<right; x++)  // x from 0 to 4
			for (int y=top; y<bottom; y++) // y from 0 to 4
				if (0<=x && x<width && 0<=y && y<height) // if inside source image
					if (0<=x && x<result.width && 0<=y && y<result.height) // if inside dest. image.
					{	
						int s = ((y-top)*width+(x-left))*channels;
						int d = (y*result.width+x)*channels;
						result.data[d..d+channels] = data[s..s+channels];
					}
		return result;
	}
	unittest {
		auto img = new Image(3, 4, 5);
		img = img.crop(0, 0, 12, 6);
		assert(img.getWidth() == 12);
		assert(img.getHeight() == 6);
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
	ubyte[] opIndex(int i)
	{	assert(0<=i && i<width*height);
		return data[i..(i+channels)];
	}
	ubyte[] opIndexAssign(ubyte[] val, int i) /// ditto
	{	assert(0<=i && i<width*height);
		return data[i..(i+channels)] = val[0..channels];
	}

	/// Get or set the pixel at the given coordinates.
	ubyte[] opIndex(int x, int y)
	{	
		assert(0 <= x && x<width); 
		assert(0 <= y && y<height);
		
		int i = (y*width+x)*channels;
		return data[i..(i+channels)];
	}
	ubyte[] opIndexAssign(ubyte[] val, int x, int y) /// ditto
	{	assert(0 <= x && x<width); 
		assert(0 <= y && y<height);
		
		int i = (y*width+x)*channels;
		return data[i..(i+channels)] = val[0..channels];
	}

	/**
	 * Paste another image on top of this one.
	 * This operation is performed in-place and does not generate any heap activity.
	 * This also does not perform proper overlays of images with an alpha channel.
	 * Params:
	 *     img = Image to add to this one.
	 *     xoffset = x-offset of img from this image's left side.  Out of bounds values will be cropped.
	 *     yoffset = y-offset of img from this image's top side.  Out of bounds values will be cropped. */
	void overlay(Image img, int xoffset=0, int yoffset=0)
	{	assert(channels==img.channels);
	
		for (int y=0; y<img.height; y++)
		{	int yoffsety = yoffset+y;
			if (yoffsety < height && yoffsety > 0)
			{	for (int x=0; x<img.width; x++) // TODO: Replace with array slice copy.
				{	int xoffsetx = xoffset + x;
					if (xoffsetx < width && xoffsetx > 0)	
						this[xoffsetx, yoffsety][0..channels] = img[x, y][0..channels]; // TODO: convert format
		}	}	}
	}
	
	/**
	 * Overlay another image on top of this one, adding color channel values.
	 * This operation is performed in-place and does not generate any heap activity.
	 * Params:
	 *     img = Image to add to this one.
	 *     xoffset = x-offset of img from this image's left side.  Out of bounds values will be cropped.
	 *     yoffset = y-offset of img from this image's top side.  Out of bounds values will be cropped. */
	void add(Image img, int xoffset=0, int yoffset=0)
	{	assert(channels == img.channels);
	
		if (this == img)
			img.data = img.data.dup; // TODO: Use a lookaside instead
		
		int ymax = max(min(img.height+yoffset, height), 0); 
		for (int y=max(yoffset, 0); y < ymax; y++)
		{	assert(0 <= y && y<height);
			int xmax = max(min(img.width+xoffset, width), 0);
			for (int x=max(xoffset, 0); x<xmax; x++)
			{	assert(0 <= x && x<width);
				uint src = ((y-yoffset)*img.width + x - xoffset)*channels;
				uint dest = (y*width+x)*channels;
				for (int c=0; c<channels; c++)
				{	uint total = cast(int)data[dest+c] + img.data[src+c];
					data[dest+c] = total > 255 ? 255 : total;
				}
			}
		}
	}

	/**
	 * Convert a monochrome image to color and paste it over this image.
	 * This operation is performed in-place and does not generate any heap activity.
	 * This somewhat specialized function is used to accelerate text rendering.
	 * Params:
	 *     img = a monochrome image 
	 *     color = img will be converted to an RGBA image of this color before pasting.
	 *     xoffset = x-offset of img from this image's left side.  Out of bounds values will be cropped.
	 *     yoffset = y-offset of img from this image's top side.  Out of bounds values will be cropped.
	 * TODO: Make the top go to the right instead of taking the bottom to the left when skewing
	 */
	void overlayAndColor(Image img, Color color, int xoffset=0, int yoffset=0)
	{	assert(getChannels()==4);
		assert(img.getChannels()==1);
	
		uint ymax = max(min(img.height+yoffset, height), 0); 
		for (uint y=max(yoffset, 0); y < ymax; y++)
		{	assert(0 <= y && y<height);
		
			uint ywidth = y*width;
			uint xmax = max(min(img.width+xoffset, width), 0);
			for (uint x=max(xoffset, 0); x<xmax; x++)
			{	assert(0 <= x && x<width);
				
				// TODO: Multiply by color's alpha?
				uint src_alpha = img.data[(y-yoffset)*img.width + x - xoffset] * color.a;
				src_alpha = (src_alpha * 257)>>16; // fast divide by 255
				if (src_alpha > 0)
				{	
					uint dest = (ywidth+x)*channels;
					uint dst_alpha = data[dest+3];
					uint dst_ratio = (((255-src_alpha) * dst_alpha) * 257)>>16; // hack for faster divide by ~255
					
					// This is my own blending algorithm, can it be further optimized?
					uint reciprocal = 0x10001 / (src_alpha + dst_ratio); // calculate reciprocal for fast integer division.
					data[dest  ] = ((color.r*src_alpha + data[dest  ]*dst_ratio) * reciprocal)>>16; // colors
					data[dest+1] = ((color.g*src_alpha + data[dest+1]*dst_ratio) * reciprocal)>>16;
					data[dest+2] = ((color.b*src_alpha + data[dest+2]*dst_ratio) * reciprocal)>>16;

					data[dest+3] = src_alpha + dst_ratio;
				}
		}	}
	}
	unittest
	{	Image a = new Image(1, 16, 16);
		Image b = new Image(4, 8, 8);
		b.overlayAndColor(a, Color("#FFFFFF"), -4, -4);
	}
	
	/**
	 * Return a c-style pointer to the image data.
	 * The length of the array is always width*height*channels. */
	void *ptr()
	{	return data.ptr;
	}

	/**
	 * Resize this image using bilinear interpolation.
	 * Params:
	 *     width = The new width.
	 *     height = The new height.  If 0, height will be calculated automatically with aspect ratio maintained.
	 * Returns: A new image of the same type and of the new size, or an exact copy if the dimensions are the same. */
	Image resize(int width, int height=0)
	{	assert(this.width > 0);
		
		Image result = new Image();
		result.width = width;
		if (height)
			result.height = height;
		else
			result.height = width*this.height/this.width;		
		result.channels = channels;
		
		// Return a copy if there's nothing to resize, for consistency's sake
		if (result.width == this.width && result.height == this.height)
		{	result.data = this.data.dup;
			return this;
		}
		
		result.data.length = width*height*channels;

		// TODO: This is an excellent candidate for parallelization
		// Special case of a 1/2 size resize, this is 4x faster than the general case.
		if (width==this.width/2 && height==this.height/2)
		{	for (int y=0; y<height; y++)
				for (int x=0; x<width; x++)
				{	int x2 = x*2;
					int y2 = y*2;
					int a = (y2*this.width+x2)*channels;
					int b = a + channels;
					int c = ((y2+1)*this.width+x2)*channels;
					int d = c + channels;					
					int dest = (y*width+x)*channels;					
					for (int i=0; i<channels; i++)
						result.data[dest+i] = (data[a+i] + data[b+i] + data[c+i] + data[d+i]+2) / 4; // +2 to correct rounding.		
				}
		}
		else // general resize case
		{	float width1 = 1/(width-1.0f);
			float height1= 1/(height-1.0f);		
		
			for (int y=0; y<height; y++)
				for (int x=0; x<width; x++)
					result[x, y][0..channels] = bilinearFilter(x*width1, y*height1).v[0..channels];				
		}
		return result;
	}
	
	// Unfinished and untested.  TODO: modify this to return a new image in the given format, allow more than one byte per channel
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
				else
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

///
abstract class ImageBase
{
	///
	ubyte[] getBytes();
	
	///
	Image2!(T2, C2) convert(T2: real, int C2)();
	
	ImageBase load(ubyte[] data)
	{	
		// TODO: Implement this function.
		
		return new Image2!(ubyte, 4)();
	}
}

/**
 * Successor to the Image class.
 * TODO: The rest of Image's functionality should be migrated to Image2, Image deleted, and Image2 renamed as Image.
 * @param T Type of each pixel component
 * @param C number of channels. */
class Image2(T : real, int C) : ImageBase
{
	alias Image2!(T, C) ImageTC;
	
	int width, height;
	T[C][] data;
	
	protected this(){}
	
	///
	this(int width, int height, T[C][] data=null)
	{	
		if (data.length)
			assert(data.length == width*height);
		else
			data.length =  width*height;
		
		this.data = data;
		this.width = width;
		this.height = height;
	}
	
	/*
	 * Convert to a different image format. */
	override Image2!(T2, C2) convert(T2: real, int C2)()
	{
		static if (T is T2 && C is C2) // no conversion necessary
			return this;
		
		Image2!(T2, C2) result;
		int minChannels = C<C2 ? C : C2;
		
		for (int i=0; i<data.length; i++)			
		{	static if (C==1 && C2 > 1) // going from one channel to many, copy channel
				result.data[i][0..$] = cast(T2)data[i][0];
			else if (C2==1 && C > 1) // going from many channels to one, average channels
			{	float average = data[i][0];
				for (int c=1; c<C; c++)
					average += data[i][c];
				result.data[i][0] = cast(T2)(average/C);
			}
			else // copy channel for channel, ignoring missing
				for (int c=0; c<minChannels; c++)
					result.data[i][c] = cast(T2)data[i][c];
		}
	}
	
	///
	override ubyte[] getBytes()
	{	return cast(ubyte[])data;		
	}
	
	//T[1][] getChannel(int channel);
	//T[C][] getData();
	
	static if (is(T : ubyte))
	{
		Image toOldImage()
		{	return new Image(cast(ubyte[])data, C, width, height);
		}
	}
}

alias Image2!(ubyte, 4) Image4ub;
alias Image2!(ubyte, 3) Image3ub;
alias Image2!(ubyte, 1) Image1ub;
