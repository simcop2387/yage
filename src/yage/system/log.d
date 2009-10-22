/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.log;

import tango.io.Stdout;
import tango.text.convert.Format;
import tango.io.device.File;
import std.format;
import std.stdio;

import tango.util.log.Trace;

/**
 * Deprecated
 * Log is a class with static members for writing log data to the standard
 * output or a file. */
abstract class Log
{
	/**
	 * Write a message to the log.  This ignores message types.*/
	static void write(...)
	{	char[] res;
		void putchar(dchar c)
		{	res~= c;
		}
		std.format.doFormat(&putchar, _arguments, cast(char*)_argptr);
		writefln(res);
	}	
}

/**
 * See_Also: http://dsource.org/projects/tango/wiki/ChapterLogging
 * Authors: Eric
 */
struct Log2
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

	static bool info(char[] message, ...)
	{	return write(Level.INFO, Type.SYSTEM, Format.convert(_arguments, _argptr, message));
	}
	
	static bool warn(char[] message, ...)
	{	return write(Level.WARN, Type.SYSTEM, Format.convert(_arguments, _argptr, message));
	}
	
	static bool error(char[] message, ...)
	{	return write(Level.ERROR, Type.SYSTEM, Format.convert(_arguments, _argptr, message));
	}
	
	static bool trace(char[] message, ...)
	{	return write(Level.TRACE, Type.SYSTEM, Format.convert(_arguments, _argptr, message));
	}
	
	private static bool write(Level level, Type type, char[] message, ...)
	{
		if ((level >= this.level) && (type & this.type) && output)
		{	
			char[] msg = Format.convert(_arguments, _argptr, message);
			
			if (output & Output.CONSOLE)
				Trace.format(msg~"\n").flush;
			if (output & Output.FILE)
				File.append(file, message~"\r\n");
			return true;
		}		
		return false;
	}
}

