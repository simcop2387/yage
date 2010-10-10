/**
 * Copyright:  (c) 2005-2010 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.libraries;

import derelict.freetype.ft;

import derelict.ogg.vorbis;
import yage.system.log;
import yage.core.object2;

/**
 * Load external DLL's or SO's. */
abstract class Libraries
{
	static bool freeTypeLoaded, vorbisLoaded;
	
	
	/**
	 * Load or unload FreeType, or do nothing if it is already in the requested state.
	 * Params:
	 *     load = If false, FreeType will be unloaded. */
	static void loadFreeType(bool load=true)
	{	
		if (load && !freeTypeLoaded)
		{	Log.info("Loading FreeType.");
			DerelictFT.load();
			if (!FT_Init_FreeType)
				throw new ResourceException("FreeType failed to load.");
			freeTypeLoaded = true;
			
		} else if (!load && freeTypeLoaded)
		{	Log.info("Unloading FreeType.");
			DerelictFT.unload();
			freeTypeLoaded = false;
		}
	}
	
	/**
	 * Load or unload Vorbis and VorbisFile, or do nothing if it is already in the requested state.
	 * Params:
	 *     load = If false, Vorbis and VorbisFile will be unloaded. */
	static void loadVorbis(bool load=true)
	{	if (load && !vorbisLoaded)
		{	Log.info("Loading Vorbis and VorbisFile.");
			DerelictVorbis.load();
			DerelictVorbisFile.load();
			vorbisLoaded = true;
		} else if (!load && vorbisLoaded)
		{	Log.info("Unloading Vorbis and VorbisFile.");
			DerelictVorbis.unload();
			DerelictVorbisFile.unload();
			vorbisLoaded = false;
		}
	}
}