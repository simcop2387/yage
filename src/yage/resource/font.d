/**
 * Copyright:  (c) 2005-2008 Eric Poggel
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
import yage.resource.exceptions;
import yage.resource.image;
import yage.resource.manager;
import yage.resource.resource;
import yage.resource.texture;



/**
 * An instance of a loaded Font.
 * Fonts are typically used to render strings of text to an image. */
class Font : Resource
{
	// Stores a single rendered letter.
	protected struct Letter
	{	Image image;
		int top;
		int left;
		int advancex;
		int advancey;
		dchar letter;
		
		char[] toString()
		{	return toUTF8([letter]);		
		}
	}

	// Used as a key to lookup cached letters.
	protected struct Key
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

	protected struct Line
	{	Letter[] letters;
		int width;
	}
	
	protected static FT_Library library;
	protected static bool freetype_initialized = false;
	
	protected static char[] br_char = " *()-+=/\\,.;:|()[]{}<>";
	
	protected FT_Face face;
	protected char[] source;
	protected Letter[Key] cache; // Using this cache of rendered character images increases performance by about 5x.
	
	///
	enum TextAlign
	{	LEFT = 0,
		CENTER = 1,
		RIGHT = 2		
	}
	
	/**
	 * Construct and load the font file specified by filename.
	 * Params:
	 *     filename = Any font file supported by Freetype that exists in ResourceManager.paths. */
	this(char[] filename)
	{
		// Initialize Freetype library if not initialized
		// TODO: Move this into Device?
		if (!freetype_initialized)
			if (FT_Init_FreeType(&library))
				throw new ResourceManagerException("Freetype2 Failed to load.");
		
		// Load
		source = ResourceManager.resolvePath(filename);
		auto error = FT_New_Face(library, toStringz(source), 0, &face );
		if (error == FT_Err_Unknown_File_Format)
			throw new ResourceManagerException("Could not open font file '%s'. The format is not recognized by Freetype2.", source);
		else if (error)
			throw new ResourceManagerException("Freetype2 could not open font file '%s'.", source);		
	}
	
	//
	~this()
	{	// Do freetype libraries not require any type of cleanup?
	}
	
	/**
	 * Clear the cache of rendered letters.
	 * Characters of text are cached as they're rendered.
	 * This allows a tremendous speedup in rendering speed, but uses extra memory.
	 * Calling this function should not usually be necessary. */
	void clearCache()
	{
		
	}
	
	/**
	 * Render an image from text.
	 * TODO: Fix text from Right-to-Left languages from being rendered backwards.
	 * Params:
	 *     text = A string of text to render, can be utf-8 or unencoded unicode (dchar[]).
	 *     width = The horizontal pixel size of the font to render.
	 *     height = The vertical pixel size of the font to render, if 0 it will be the same as the width.
	 *     line_width = Letters will wrap to the next line after this many pixels (breaking on spaces), unsupported
	 *     line_height = This much space will occur between each line, defaults to 1.5x height, unsupported
	 *     align = unsupported
	 *     image_pow2 = If true, the image returned will always have its dimensions as powers of two. */
	Image render(char[] utf8, int width, int height=0, int line_width=-1, int line_height=-1, uint text_align=TextAlign.LEFT, bool image_pow2=false)
	{	dchar[] unicode = toUTF32(utf8);
		Image result = render(unicode, width, height, line_width, line_height, text_align, image_pow2);
		delete unicode;
		return result;
	}
	
	/// ditto
	Image render(dchar[] text, int width, int height=0, int line_width=-1, int line_height=-1, uint text_align=TextAlign.LEFT, bool image_pow2=false) 
	{
		// Calculate parameters
		if (line_height==-1)
			line_height = cast(int)(height*1.5);
		if (line_width==-1)
			line_width = int.max;		
		
		// Give our font size to freetype.
		auto error = FT_Set_Pixel_Sizes(face, width, height);   // face, pixel width, pixel height
		if (error)
			throw new ResourceManagerException("Font '%s' does not support pixel sizes of %dx%d.", source, width, height);		
		
		/*
		 * First, we render (or retrieve from cache) all letters into an array of Letter.
		 * This allows us to calculate dimensinal information like total width/height, number of lines etc.
		 * We then allocate an image of appropriate size, composite the letters onto it, and then return it. */
		Letter[] letters;
		
		// Create a glyph for each letter and store its parameters
		int current_line_width = 0;
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
					throw new ResourceManagerException("Font '%s' cannot render the character '%s'.", source, toUTF8([c]));			
				
				auto bitmap = face.glyph.bitmap;
				ubyte[] data = (cast(ubyte*)bitmap.buffer)[0..(bitmap.width*bitmap.rows)];				
				
				// Set the values of the letter.			
				letter.image = new Image(data.dup, 1, bitmap.width, bitmap.rows);
				letter.top = face.glyph.bitmap_top;
				letter.left = face.glyph.bitmap_left;
				letter.advancex = face.glyph.advance.x>>6;
				letter.advancey = face.glyph.advance.y>>6;
    			letter.letter = c;
				
				cache[key] = letter;
			}
			
			letters ~= letter;
		}
		
		// Convert letters to lines
		Line[] lines;
		lines.length = lines.length + 1;
		foreach (i, letter; letters)
		{	
			// Advance to next line if necessary
			if (lines[$-1].width + letter.advancex > line_width)
				lines.length = lines.length + 1;
			if (letter.letter == '\n')
			{	lines.length = lines.length + 1;
				continue;
			}
	
			// If a possible breaking character
			if (find(br_char, letter.letter) != -1) // if this letter is a breaking charater
			{	int line_width2 = lines[$-1].width;
				bool skip = false;
				for (int j=i+1; j<letters.length; j++) // look ahead for more breaking characters
				{					
					// if there are more before the line is too long, continue
					if (find(br_char, letters[j].letter) != -1) 
						break;
					
					// if not, break on this character
					line_width2 += letters[j].advancex;
					if (line_width2 > line_width)
					{	lines.length = lines.length + 1;
						skip = true;
						break;
					}
				}
				if (skip)
					continue;
			}
			
			// If a printable character, add it to the line.
			if (letter.letter > 31)
			{	Line* line = &lines[$-1];			
				line.letters ~= letter;
				line.width += letter.advancex;
			}
		}
		
		
		// Create image target where glyphs will be compisited.
		int img_width = image_pow2 ? nextPow2(line_width) : line_width;
		int img_height = image_pow2 ? nextPow2(line_height*lines.length) : line_height*lines.length;
		Image result = new Image(1, img_width, img_height);
		
		
		foreach (i, line; lines)
		{				
			// Calculate align offset
			int align_offset = 0;
			if (text_align == TextAlign.CENTER)
				align_offset = (line_width-line.width) / 2;
			else if (text_align == TextAlign.RIGHT)
				align_offset = (line_width-line.width);
			
			// Composite letters onto main image.
			int advancex=0, advancey=0;
			foreach (j, letter; line.letters)
			{	result.overlay(letter.image, align_offset+advancex+letter.left, i*line_height + (advancey-letter.top+height));			
				advancex+= letter.advancex;
				advancey+= letter.advancey;
			}
		}
		
		delete lines;
		delete letters;
	
		return result;
	}

}