/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.font;

import std.string;
import std.stdio;
import std.utf;
import derelict.freetype.ft;
import yage.core.math;
import yage.core.timer;
import yage.core.types;
import yage.core.parse;
import yage.resource.exception;
import yage.resource.resource;
import yage.resource.image;
import yage.resource.texture;

//Stores a single rendered letter.
private struct Letter
{	Image image;
	int top;
	int left;
	int advancex;
	int advancey;	
}

// Used as a key to lookup cached letters.
private struct Key
{	dchar letter;
	short width;
	short height;
	
	// Hash recognizes that most letters are two bytes or less, most sizes are one byte or less
    hash_t toHash()
    {	return (cast(uint)letter<<16) + ((cast(uint)width)<<8) + (cast(uint)height);    	
    }
    int opEquals(Key s)
    {  	return letter==s.letter && width==s.width && height==s.height;
    }
    int opCmp(Key s)
    {  	 return toHash() - s.toHash();
    }
}

/**
 * An instance of a loaded Font.
 * Fonts are typically used to render strings of text to an image. */
class Font
{
	protected static FT_Library library;
	protected static bool freetype_initialized = false;
	
	protected FT_Face face;
	protected char[] source;
	protected Letter[Key] cache; // Using this cache of rendered character images increases performance by about 5x.
	
	/**
	 * Construct and load the font file specified by filename.
	 * Params:
	 *     filename = Any font file supported by Freetype that exists in Resource.paths. */
	this(char[] filename)
	{
		// Initialize Freetype library if not initialized
		// TODO: Move this into Device?
		if (!freetype_initialized)
			if (FT_Init_FreeType(&library))
				throw new Exception("Freetype2 Failed to load.");
		
		// Load
		source = Resource.resolvePath(filename);
		auto error = FT_New_Face(library, toStringz(source), 0, &face );
		if (error == FT_Err_Unknown_File_Format)
			throw new ResourceLoadException("Could not open font file '" ~ source ~ "'. The format is not recognized by Freetype2.");
		else if (error)
			throw new ResourceLoadException("Freetype2 could not open font file '" ~ source ~ "'.");		
	}
	
	///
	~this()
	{	// Do freetype libraries not require any type of cleanup?
	}
	
	
	/**
	 * Render an image from text.
	 * TODO: Fix text from Right-to-Left languages from being rendered backwards.
	 * Params:
	 *     text = A string of text to render, can be utf-8 or unencoded unicode (dchar[]).
	 *     width = The horizontal pixel size of the font to render.
	 *     height = The vertical pixel size of the font to render, if 0 it will be the same as the width.
	 *     line_width = Letters will wrap to the next line after this amount (breaking on spaces), unsupported
	 *     line_height = This much space will occur between each line, defaults to 1.5x height, unsupported
	 *     image_pow2 = If true, the image returned will always have its dimensions as powers of two. */
	Image render(char[] utf8, int width, int height=0, int line_width=-1, int line_height=-1, bool image_pow2=false)
	{	dchar[] unicode = toUTF32(utf8);
		Image result = render(unicode, width, height, line_width, line_height, image_pow2);
		delete unicode;
		return result;
	}
	
	/// ditto
	Image render(dchar[] text, int width, int height=0, int line_width=-1, int line_height=-1, bool image_pow2=false) 
	{		
		// Calculate parameters
		if (line_height==-1)
			line_height = cast(int)(height*1.5);
		if (line_width==-1)
			line_width = int.max;		
		
		// Give our font size to freetype.
		auto error = FT_Set_Pixel_Sizes(face, width, height);   // face, pixel width, pixel height
		if (error)
			throw new Exception(formatString("Font '%s' does not support pixel sizes of %dx%d.", source, width, height));		
		
		/*
		 * First, we render (or retrieve from cache) all letters into an array of Letter.
		 * This allows us to calculate dimensinal information like total width/height, number of lines etc.
		 * We then allocate an image of appropriate size, composite the letters onto it, and then return it. */
		Letter[] letters; 
		int total_width = 0;
		int total_height = 0;
		int image_height = 0;
		int lines=1;	// number of lines of text.
		
		// Create a glyph for each letter and store its parameters
		foreach (c; text)
		{	
			Key key = Key(c, width, height);
			Letter letter;
			if (key in cache)
				letter = cache[key];
			else
			{	// Render the character into the glyph slot.
				error = FT_Load_Char(face, c, FT_LOAD_RENDER);  
				if (error)
					throw new Exception("Font '"~source~"' cannot render the character '"~toUTF8([c])~"'.");			
				
				auto bitmap = face.glyph.bitmap;
				ubyte[] data = (cast(ubyte*)bitmap.buffer)[0..(bitmap.width*bitmap.rows)];				
				
				// Set the values of the letter.			
				letter.image = new Image(data.dup, 1, bitmap.width, bitmap.rows);
				letter.top = face.glyph.bitmap_top;
				letter.left = face.glyph.bitmap_left;
				letter.advancex = face.glyph.advance.x>>6;
				letter.advancey = face.glyph.advance.y>>6;
				
				cache[key] = letter;
			}
			
			letters ~= letter;
			total_width+= letter.advancex;
			total_height+= letter.advancey;
		}
		
		
		// Composite all glyph images into a single image.
		// We have to do this here since we need to render them before calculating sizes.
		int img_width = image_pow2 ? nextPow2(total_width) : total_width;
		int img_height = image_pow2 ? nextPow2(line_height*lines) : line_height*lines;
		Image result = new Image(1, img_width, img_height);
		
		int advancex=0, advancey=0;
		for (int i=0; i<letters.length; i++)
		{	result.overlay(letters[i].image, advancex+letters[i].left, (advancey-letters[i].top+height));			
			advancex+= letters[i].advancex;
			advancey+= letters[i].advancey;
		}
		delete letters;
	
		return result;
	}

}