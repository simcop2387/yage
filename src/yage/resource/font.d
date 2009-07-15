/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.font;

import tango.io.Stdout;
import tango.text.convert.Utf;
import derelict.freetype.ft;
import yage.core.math.math;
import yage.core.timer;
import yage.core.types;
import yage.core.parse;
import yage.core.object2;;
import yage.resource.image;
import yage.resource.manager;
import yage.resource.resource;
import yage.resource.texture;

/**
 * Stores a single rendered letter. */ 
struct Letter
{	dchar letter;	/// unicode letter
	short top;		/// image top offset
	short left;		/// image left offset
	short advanceX;	/// x and y distance required to move to the next letter after this one
	short advanceY;	/// ditto
	Image image; 	/// rendered image of this letter
	
	void* extra;	// used internally
	
	/**
	 * Get the utf8 representation of this letter. 
	 * Params:
	 *     lookaside = If specified, fill and return this buffer instead of allocating new memory on the heap. */
	char[] toString(char[] lookaside=null)
	{	dchar[1] temp;
		temp[0] = letter;
		return .toString(temp, lookaside);		
	}
}

/**
 * An instance of a loaded Font.
 * Fonts are typically used to render strings of text to an image. */
class Font : Resource
{
	// Used as a key to lookup cached letters.
	protected struct Key
	{	dchar letter;
		short width;
		short height;
		bool bold;
		bool italic;
		
		// Hash recognizes that most letters are two bytes or less, most sizes aren 7 bits or less
	    hash_t toHash()
	    {	ushort widthBold   = cast(ushort)((width & 0x7f | (bold<<7))<<8);
	    	ubyte heightItalic = cast(ubyte)(height & 0x7f | (italic<<7));
	    	return (letter<<16) | widthBold | heightItalic;
	    }
	    unittest {
	    	Key test = Key('A', 255, 127, false, true);
	    	assert(test.toHash() == 0x417FFF);
	    }
	    
	    int opEquals(Key s)
	    {  	return letter==s.letter && width==s.width && height==s.height && s.bold==bold && s.italic==italic;
	    }
	    int opCmp(Key s)
	    {  	 return toHash() - s.toHash();
	    }
	}
	
	protected static FT_Library library;
	protected static bool freetype_initialized = false;
	
	protected FT_Face face;
	protected char[] source;
	protected Letter[Key] cache; // Using this cache of rendered character images increases performance by about 5x.
	
	/**
	 * Construct and load the font file specified by filename.
	 * Params:
	 *     filename = Any font file supported by Freetype that exists in ResourceManager.paths. */
	this(char[] filename)
	{
		// Initialize Freetype library if not initialized
		// TODO: Move this into System?
		if (!freetype_initialized)
			if (FT_Init_FreeType(&library))
				throw new ResourceManagerException("Freetype2 Failed to load.");
		
		// Load
		source = ResourceManager.resolvePath(filename);
		auto error = FT_New_Face(library, (source~"\0").ptr, 0, &face);
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
	{	cache = null;		
	}
	
	/**
	 * Render an image of a single letter.
	 * Params:
	 *     text = A string of text to render, can be utf-8 or unencoded unicode (dchar[]).
	 *     width = The horizontal pixel size of the font to render.
	 *     height = The vertical pixel size of the font to render, if 0 it will be the same as the width.
	 *     bold = Get a bold version of the letter.  This is performed by compositing the same glyph multiple times 
	 *         horizontally and then cached.
	 *     italic = Get an italicized version of the letter.  This is performed by an image skew and then cached. */
	Letter getLetter(dchar letter, int width, int height=0, bool bold=false, bool italic=false)
	{
		Key key = Key(letter, width, height, bold, italic);
		if (key in cache)
			return cache[key];
		else
		{	Letter result;
		
			// Give our font size to freetype.
			scope error = FT_Set_Pixel_Sizes(face, width, height);   // face, pixel width, pixel height
			if (error)
				throw new ResourceManagerException("Font '{}' does not support pixel sizes of {}x{}.", source, width, height);
		
			// Render the character into the glyph slot.
			error = FT_Load_Char(face, letter, FT_LOAD_RENDER);  
			if (error)
				throw new ResourceManagerException("Font '{}' cannot render the character '{}'.", source, .toString([letter]));			
			
			scope bitmap = face.glyph.bitmap;
			ubyte[] data = (cast(ubyte*)bitmap.buffer)[0..(bitmap.width*bitmap.rows)];				
			
			// Set the values of the letter.
			if (bold)
			{	int boldness = width/8; // adjust this for boldness amount
				result.advanceX += boldness;
				
				result.image = new Image(1, bitmap.width+boldness, bitmap.rows);				
				scope embolden = new Image(data, 1, bitmap.width, bitmap.rows);
				for (int i=0; i<=boldness; i++)
					result.image.add(embolden, i, 0);
			}
			else
				result.image = new Image(data.dup, 1, bitmap.width, bitmap.rows);
			result.top = face.glyph.bitmap_top;
			result.left = face.glyph.bitmap_left;
			result.advanceX += face.glyph.advance.x>>6; // fast divide by 64
			result.advanceY = face.glyph.advance.y>>6;
			result.letter = letter;
			
			return cache[key] = result;
		}
	}

	/// Return the font filename.
	char[] toString()
	{	return source;
	}
}