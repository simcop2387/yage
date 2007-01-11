/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.system.log;

import std.stdio;

/**
 * Log is a class with static members for writing log data to the standard
 * output or a file. */
abstract class Log
{
	/// Write startup string
//	static this()
//	{	printf("Starting the Yage Logger.\n");
//	}

	static void credits()
	{
		writefln(
			"The Yage Game Engine uses the following software:\n" ~
			" * Simple DirectMedia Layer, which is available under the terms of the LGPL.\n"

		);

	}

	/// Write to the log.
	static void write(...)
	{	char[] res;
		void putchar(dchar c)
		{	res~= c;
		}
		std.format.doFormat(&putchar, _arguments, _argptr);
		writefln(res);
	}
}

