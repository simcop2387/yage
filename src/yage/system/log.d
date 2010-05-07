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
import yage.core.json;
import yage.core.timer;

/**
 * Log to a file or the console. */
struct Log
{
	/// Use these options to specify logging levels.
	enum Level
	{	INFO, /// 
		WARN, /// ditto
		ERROR, /// ditto
		TRACE /// ditto
	}
	static Level level = Level.INFO; /// Only logs of this level or greater will be written.
	
	/// Use these options to specify logging types.
	enum Type
	{	GUI = 1, ///
		RESOURCE = 2, /// ditto
		SCENE = 4, /// ditto
		SYSTEM = 8, /// ditto
	}
	static uint type = Type.SYSTEM | Type.SCENE | Type.RESOURCE | Type.GUI; /// Only logs of these types will be written, defaults to all types.
	
	/// Use these options to specify where the log should be written.
	enum Output
	{	CONSOLE = 1, ///
		FILE = 2 /// ditto
	}
	static uint output = Output.CONSOLE; /// Specify where to log.
		

	static char[] file = "log.txt"; /// If output includes File, write to this file.

	/// Write to the log.  Arguments are the same as std.stdio.writefln in Phobos.
	static bool info(...)
	{	return write(Level.INFO, Type.SYSTEM, swritef(_arguments, _argptr));
	}
	
	/// ditto
	static bool warn(...)
	{	return write(Level.WARN, Type.SYSTEM, swritef(_arguments, _argptr));
	}
	
	/// ditto
	static bool error(...)
	{	return write(Level.ERROR, Type.SYSTEM, swritef(_arguments, _argptr));
	}
	
	/// ditto
	static bool trace(...)
	{	return write(Level.TRACE, Type.SYSTEM, swritef(_arguments, _argptr));
	}
	
	/// ditto
	static bool write(Level level, Type type, ...)
	{
		if ((level >= this.level) && (type & this.type) && output)
		{	
			char[] msg = swritef(_arguments, _argptr);
			if (output & Output.CONSOLE)
				synchronized(Log.typeinfo)
					Cout.append(msg~"\n").flush;
			if (output & Output.FILE)
				File.append(file, msg~"\r\n");
			return true;
		}		
		return false;
	}
	
	/// Recursively print a data structure.
	static void dump(T)(T t)
	{	trace(Json.encode(t));
	}
}

import tango.util.container.HashMap;

struct Profile
{
	static Timer[char[]] timers;
	static bool enabled = true;
	
	// TODO: Each call to these adds a few microseconds of time and makes the timings off.
	static void start(char[] timerName)
	{	if (!enabled)
			return;
		
		auto timer = timerName in timers;
		if (timer)
		{	assert(timer.paused());
			timer.play();
		}
		else
		{	Timer t = new Timer(true);			
			timers[timerName] = t;
			timers.rehash;
			t.play();
		}
	}
	
	static void stop(char[] timerName)
	{	if (!enabled)
			return;
		
		auto timer = timerName in timers;
		assert(timer);
		timer.pause();
	}
	
	static char[] getTimesAndClear()
	{	char[] result;
		foreach (name, timer; timers)
			result ~= format("%ss %s\n", timer.tell(), name);
		clear();
		return result;
	}
	
	static void clear()
	{	timers = null;
	}
	
	
}