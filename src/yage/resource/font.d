/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.font;

import tango.io.device.File;
import tango.io.FilePath;
import tango.io.device.TempFile;
import tango.text.convert.Utf;
import tango.math.Math;

import derelict.freetype.ft;

import yage.core.math.math;
import yage.core.timer;
import yage.core.types;
import yage.core.object2;
import yage.resource.image;
import yage.resource.manager;
import yage.resource.graphics.texture;
import yage.system.libraries;
import yage.system.log;

/**
 * Stores a single rendered letter. */ 
struct Letter
{	dchar letter;	/// unicode letter
	int top;		/// image top offset
	int left;		/// image left offset
	int advanceX;	/// x and y distance in pixels required to move to the next letter after this one
	int advanceY;	/// ditto
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
class Font
{
	// Used as a key to lookup cached letters.
	protected struct Key
	{	dchar letter;
		int width;
		int height;
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
	    {  	 return cast(int)(toHash()) - cast(int)(s.toHash());
	    }
	}
	
	protected static FT_Library library;
	
	protected FT_Face face;
	protected string resourceName;
	protected Letter[Key] cache; // Using this cache of rendered character images increases performance by about 5x.
	
	/**
	 * Construct and load the font file specified by filename.
	 * Params:
	 *     filename = Any font file supported by Freetype that exists in ResourceManager.paths. */
	this(string filename)
	{
		// Initialize Freetype library if not initialized
		uint error;
		if (!library)
		{	error = FT_Init_FreeType(&library); // TODO: FT_DONE_LIBRARY
			if (error)
				throw new ResourceException("Freetype2 Failed to load.  Error code %s", error);
		}
		
		//ubyte[] contents = cast(ubyte[])File.get(resourceName);	
		//this(cast(ubyte[])File.get(resourceName), resourceName);
		
		// Load
		resourceName = ResourceManager.resolvePath(filename);
		error = FT_New_Face(library, (resourceName~'\0').ptr, 0, &face);
		if (error == FT_Err_Unknown_File_Format)
			throw new ResourceException("Could not open font file '%s'. The format is not recognized by Freetype2.", resourceName);
		else if (error)
			throw new ResourceException("Freetype2 could not open font file '%s'.  Error code %d.", resourceName, error);
		else if(face is null)
			throw new ResourceException("Freetype2 could not open font file '%s'.", resourceName);
	}
	
	/**
	 * Contstruct and load font file data directly from memory.
	 * Params:
	 *     data = 
	 *     resourceName = */
	this(ubyte[] data, string resourceName="")
	{
		// Initialize Freetype library if not initialized
		uint error;
		if (!library)
		{	Libraries.loadFreeType();
			
			error = FT_Init_FreeType(&library); // TODO: Call FT_Done_FreeType at some point.
			if (error)
				throw new ResourceException("FreeType2 Failed to load.  Error code %s", error);
		}
		
		// HACK: write a temporary file and then read it. Not possible to use TempFile because
		//       that returns an absolute path and the constructor expects a relative path.
		string tempFilePath = "TEMPORARY~FONT";
		File.set(tempFilePath, data);
		
		this(tempFilePath);
		//FilePath(tempFile).remove(); // freetype maintains lock, can't delete.
		this.resourceName = resourceName;
		
		(new FilePath(tempFilePath.dup)).remove();

		/*
		// Use freetype's API to load the font directly from memory.  This breaks for unknown reasons.
		this.resourceName = resourceName;
		auto error = FT_New_Memory_Face(library, data.ptr, data.length, 0, &face);
		if (error == FT_Err_Unknown_File_Format)
			throw new ResourceException("Could not open font file '%s'. The format is not recognized by Freetype2.", resourceName);
		else if (error)
			throw new ResourceException("Freetype2 could not open font file '%s'.  Error code %d.", resourceName, error);
		else if(face is null)
			throw new ResourceException("Freetype2 could not open font file '%s'.", resourceName);
		*/
	}
	
	//
	~this()
	{	
		//FT_Done_Face
	}
	
	/**
	 * Clear the cache of rendered letters.
	 * Characters of text are cached after they're rendered.
	 * This allows a tremendous speedup in for future calls, but uses a little extra memory.
	 * Calling this function should not usually be necessary. */
	void clearCache()
	{	cache = null;		
	}
	
	/**
	 * 
	 Get a Letter struct containing info and an image for a single letter.
	 * Params:
	 *     text = A string of text to render, must be unencoded unicode (dstring).
	 *     width = The horizontal pixel size of the font to render.
	 *     height = The vertical pixel size of the font to render, if 0 it will be the same as the width.
	 *     bold = Get a bold version of the letter.  This is performed by compositing the same glyph multiple times 
	 *         horizontally and then cached.
	 *     italic = Get an italicized version of the letter.  This is performed by an image skew and then cached. */
	Letter getLetter(dchar letter, int width, int height=0, bool bold=false, bool italic=false)
	{
                // TODO fix this to not need castings!
		Key key = Key(letter, width, height, bold, italic);
		if (key in cache)
			return cache[key];
		else
		{	Letter result;
			
			// Use regular or italic (shear) matrix?
			FT_Matrix matrix;
			matrix.xx = matrix.yy = 0x10000; // 65k (half the int bits are used as decimal)
			matrix.xy = italic ? cast(int)(-sin(-.33333) * 0x10000) : 0; 	
			FT_Set_Transform(face, &matrix, null);
			
			// Give our font size to freetype.
			auto error = FT_Set_Pixel_Sizes(face, width, height); // face, pixel width, pixel height
			if (error)
				throw new ResourceException("Font '%s' does not support pixel sizes of %sx%s.  Freetype2 error %s", resourceName, width, height, error);
		
			// Render the character into the glyph slot.
			error = FT_Load_Char(face, letter, FT_LOAD_RENDER);  
			if (error)
				throw new ResourceException("Font '%s' cannot render the character '%s', Freetype2 error %s", resourceName, letter, error);			
			
			auto bitmap = face.glyph.bitmap;
			ubyte[] data = (cast(ubyte*)bitmap.buffer)[0..(bitmap.width*bitmap.rows)];				
					
			// Set the values of the letter.
			if (bold)
			{	int boldness = width/8; // adjust this for boldness amount
				result.advanceX += boldness;
				
				result.image = new Image(1, bitmap.width+boldness, bitmap.rows);
				if (boldness > 0) // add artificial boldness by drawing the letter on top of itself at a horizontal offset.
				{	scope embolden = new Image(data, 1, bitmap.width, bitmap.rows);
					for (int i=0; i<=boldness; i++)
						result.image.add(embolden, i, 0);
				}
			}
			else
				result.image = new Image(data.dup, 1, bitmap.width, bitmap.rows);
			
			result.top = face.glyph.bitmap_top;
			result.left = face.glyph.bitmap_left;
			result.advanceX = cast(int)(face.glyph.advance.x>>6); // fast divide by 64
			result.advanceY = cast(int)(-face.glyph.advance.y>>6);
			result.letter = letter;
			
			return cache[key] = result;
		}
	}

	/// Return the font filename.
	override string toString()
	{	return resourceName;
	}
}