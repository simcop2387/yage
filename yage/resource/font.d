/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.font;

import std.string;
import std.stdio;
import derelict.freetype.ft;
import yage.core.math;
import yage.resource.exception;
import yage.resource.resource;
import yage.resource.image;

class Font
{
	static FT_Library library;
	static bool freetype_initialized = false;
	
	char[] source;
	FT_Face face;
	
	///
	this(char[] filename)
	{
		// Initialize Freetype library if not initialized
		// TODO: Move this into Device?
		if (!freetype_initialized)
		{	if (FT_Init_FreeType(&library))
				throw new Exception("Freetype2 Failed");
		}
		
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
	{	/// TODO: cleanup.
	}
	
	
	/**
	 * Render an image from text.
	 * Params:
	 *     text = 
	 *     width = 
	 *     height = 
	 *     line_width = Letters will wrap to the next line after this amount (breaking on spaces)
	 *     line_height = This much space will occur between each line, defaults to 1.5x height.
	 *     image_pow2 = If true, the image returned will always have its dimensions as powers of two.
	 * Returns:
	 */
	Image render(char[] text, int width, int height=0, int line_width=-1, int line_height=-1, bool image_pow2=false)
	{	
		// Calculate parameters
		if (line_height==-1)
			line_height = cast(int)(height*1.5);
		if (line_width==-1)
			line_width = int.max;		
		
		// Give our font size to freetype.
		auto error = FT_Set_Pixel_Sizes(face, width, height);   // face, pixel width, pixel height
		if (error)
			throw new Exception("Invalid font size.");
		
		// Stores a single rendered letter.
		struct Letter
		{	Image image;
			int advancex;
			int advancey; // unnecessary?
			int top;
			int left;
		}
		
		Letter[] letters; // array of all rendered letters.		
		int total_width = 0;
		int total_height = 0;
		int image_height = 0;
		int lines=1;	// number of lines of text.
		
		// Create a glyph for each letter and store its parameters
		foreach (c; text)
		{
			error = FT_Load_Char(face, c, FT_LOAD_RENDER); // Load into slot 
			if (error)
				throw new Exception("Font Error.");
			
			auto bitmap = face.glyph.bitmap;
			ubyte[] data = (cast(ubyte*)bitmap.buffer)[0..(bitmap.width*bitmap.rows)];
			
			// Set the values of the
			Letter letter;
			letter.image = new Image(data.dup, 1, bitmap.width, bitmap.rows);
			letter.top = face.glyph.bitmap_top;
			letter.left = face.glyph.bitmap_left;
			letter.advancex = total_width;
			letter.advancey = total_height;
			letters ~= letter;
			
			total_width+= face.glyph.advance.x>>6;
			total_height+= face.glyph.advance.y>>6;
		}
		
		
		// Composite all glyph images into a single image.
		// We have to do this here since we need to render them before calculating sizes.
		int img_width = image_pow2 ? nextPow2(total_width) : total_width;
		int img_height = image_pow2 ? nextPow2(line_height*lines) : line_height*lines;
		Image result = new Image(1, img_width, img_height);
		for (int i=0; i<letters.length; i++)
		{	result.overlay(letters[i].image, letters[i].advancex+letters[i].left, (letters[i].advancey-letters[i].top+height));
			delete letters[i].image;
		}
	
		return result;
	}

}