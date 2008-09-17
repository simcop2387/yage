/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.system.log;

import std.stdio;
import std.stdarg;


/**
 * Log is a class with static members for writing log data to the standard
 * output or a file. */
abstract class Log
{
	enum
	{	GENERIC = 65536,	///
		INIT = 131072,		///
		RESOURCE = 131072*2	///
	}
	
	protected static int types = GENERIC | RESOURCE;
	protected const int all_types = GENERIC | RESOURCE;
	
	/*
	Stream target;

	void setTarget(Stream target)
	{	this.target = target;
	}

	Stream getTarget()
	{	return target;
	}
	*/

	static void credits()
	{	writefln(
			"The Yage Game Engine uses the following software:\n" ~
			" * Simple DirectMedia Layer, which is available under the terms of the LGPL.\n"

		);
	}
	
	/**
	 * Set the types of messages that will be logged.
	 * Params: 
	 *    types Binary OR of types that will be logged, defaults to all types.
	static void setTypes(int types = GENERIC | RESOURCE)
	{	this.types = types;
	}

	/**
	 * Write a message to the log.  This ignores message types.*/
	static void write(char[] first, ...)
	{	char[] res;
	
		void putchar(dchar c)
		{	res~= c;
		}
		
		std.format.doFormat(&putchar, _arguments, _argptr);
		writef(first);
		writef(res);
		writefln("");
	}
	
	/**
	 * Write a typed message to the Log.
	 * Params: 
	 *    type The type of this message. */
	static void write(int type, ...)
	{	char[] res;
		void putchar(dchar c)
		{	res~= c;
		}
	
		// If message is in types or type isn't a valid type, log.
		if (type & types || !(type & all_types))
		{	std.format.doFormat(&putchar, _arguments, _argptr);
			writefln(res);
		}
	}
}

