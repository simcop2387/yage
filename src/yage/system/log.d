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
	
	/// Use these options to specify where the log should be written.
	enum Output
	{	CONSOLE = 1, ///
		FILE = 2 /// ditto
	}
	
	static Level level = Level.INFO; /// Only logs of this level or greater will be written.
	static uint output = Output.CONSOLE | Output.FILE; /// Specify where to log.
	static char[] file = "log.txt"; /// If output includes File, write to this file.
	private static bool firstRun = true;

	/**
	 * Write to the log.  Arguments are the same as std.stdio.writefln in Phobos.
	 * Returns true if the output settings allowed anything to be written. */
	static bool info(...)
	{	return write(Level.INFO, swritef(_arguments, _argptr));
	}
	
	/// ditto
	static bool warn(...)
	{	return write(Level.WARN, swritef(_arguments, _argptr));
	}
	
	/// ditto
	static bool error(...)
	{	return write(Level.ERROR, swritef(_arguments, _argptr));
	}
	
	/// ditto
	static bool trace(...)
	{	return write(Level.TRACE, swritef(_arguments, _argptr));
	}
	
	/// Recursively print a data structure.
	static void dump(T)(T t)
	{	trace(Json.encode(t));
	}
	

	private static bool write(Level level, ...)
	{
		if ((level >= this.level) && output)
		{	
			char[] msg = swritef(_arguments, _argptr);
			synchronized(Log.typeinfo)
			{	
				if (output & Output.CONSOLE)				
				{	try {
						Cout.append(msg ~ "\n").flush;
					} catch (Exception e) {}
				}
				if (output & Output.FILE)
				{	try {
						if (firstRun)
						{	File.set(file, msg ~ "\r\n");
							firstRun = false;
						}
						else
							File.append(file, msg ~ "\r\n");	
					} catch (Exception e) { // If can't write to file, notify on the console
						if (output & Output.CONSOLE)
							Cout.append(e.toString() ~ "\r\n").flush;
						output ^= Output.FILE;
					}
				}
				return cast(bool)output;
			}
		}
		return false;
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
			result ~= format("%.5fs %s\n", timer.tell(), name);
		clear();
		return result;
	}
	
	static void clear()
	{	timers = null;
	}
	
	
}