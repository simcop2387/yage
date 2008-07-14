/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.font;

import std.string;
import std.stdio;
import derelict.freetype.ft;
import yage.resource.exception;
import yage.resource.resource;
import yage.resource.image;

class Font
{
	static FT_Library library;
	static bool freetype_initialized = false;
	
	char[] source;
	FT_Face face;
	
	this(char[] filename)
	{
		// Initialize Freetype library if not initialized
		if (!freetype_initialized)
		{	auto error = FT_Init_FreeType(&library);
			if (error)
				throw new Exception("Freetype Failed");
		}
		
		// Load
		source = Resource.resolvePath(filename);
		auto error = FT_New_Face(library, toStringz(source), 0, &face );
		if (error == FT_Err_Unknown_File_Format)
			throw new ResourceLoadException("Could not open font file '" ~ source ~ "'. The format is not recognized by Freetype2.");
		else if (error)
			throw new ResourceLoadException("Could not open font file '" ~ source ~ "'.");		
	}
	
	
	
	Image getGlyph(dchar[] text, int width=0, int height=0)
	{	
		
		auto error = FT_Set_Pixel_Sizes(face, width, height);   // face, pixel width, pixel height
		if (error)
			throw new Exception("Font Error.");
		
		//foreach (c; text)
		//{
			error = FT_Load_Char(face, text[0], FT_LOAD_RENDER); // Load into slot 
			if (error)
				throw new Exception("Font Error.");
			
			auto bitmap = face.glyph.bitmap;
			writefln("glyph size=", bitmap.width, " ", bitmap.rows);
			ubyte[] data = (cast(ubyte*)bitmap.buffer)[0..(bitmap.width*bitmap.rows)];
			Image img = new Image(data, 1, bitmap.width, bitmap.rows);
			
			return img;
			
		//}
		
		
	}
	
	~this()
	{
		
	}
	
	
	protected void load()
	{
		
	}
}