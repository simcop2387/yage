/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.log;

import tango.text.convert.Format;
import tango.io.device.File;
import tango.io.Console;

import yage.core.format;

/**
 */
struct Log
{
	enum Level
	{	INFO,
		WARN,
		ERROR,
		TRACE
	}
	static Level level = Level.INFO;
	
	enum Type
	{	CORE = 1,
		GUI = 2,
		RESOURCE = 4,
		SCENE = 8,
		SYSTEM = 16,
	}
	static uint type = 31; // all
	
	enum Output
	{	CONSOLE = 1,
		FILE = 2,
		SOCKET = 4
	}
	static uint output = Output.CONSOLE;
		
	// Outputs
	static char[] file = "log.txt";
	static char[] socket = "127.0.0.1"; // todo

	///
	static bool info(...)
	{	return internalWrite(Level.INFO, Type.SYSTEM, swritefArgs(_arguments, _argptr));
	}
	
	///
	static bool warn(...)
	{	return internalWrite(Level.WARN, Type.SYSTEM, swritefArgs(_arguments, _argptr));
	}
	
	///
	static bool error(...)
	{	return internalWrite(Level.ERROR, Type.SYSTEM, swritefArgs(_arguments, _argptr));
	}
	
	///
	static bool trace(...)
	{	return internalWrite(Level.TRACE, Type.SYSTEM, swritefArgs(_arguments, _argptr));
	}
	
	private static bool internalWrite(Level level, Type type, ...)
	{
		if ((level >= this.level) && (type & this.type) && output)
		{	
			char[] msg = swritefArgs(_arguments, _argptr);
			
			if (output & Output.CONSOLE)
				Cout.append(msg~"\n").flush;
			if (output & Output.FILE)
				File.append(file, msg~"\r\n");
			return true;
		}		
		return false;
	}
}

