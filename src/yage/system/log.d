/**
 * Copyright:  (c) 2005-2009 Eric Poggel
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

