/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.log;

import tango.io.device.File;
import tango.io.Console;

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
	static string file = "log.txt"; /// If output includes File, write to this file.
	private static bool firstRun = true;

	/**
	 * Write to the log.  Arguments are the same as std.stdio.writefln in Phobos.
	 * Returns true if the output settings allowed anything to be written. */
	static bool info(...)
	{	return internalWrite(Level.INFO, swritef(_arguments, _argptr));
	}
	
	/// ditto
	static bool warn(...)
	{	return internalWrite(Level.WARN, swritef(_arguments, _argptr));
	}
	
	/// ditto
	static bool error(...)
	{	return internalWrite(Level.ERROR, swritef(_arguments, _argptr));
	}
	
	/// ditto
	static bool write(...)
	{	return internalWrite(Level.TRACE, swritef(_arguments, _argptr));
	}
	
	/// Recursively print a data structure.
	static void dump(T)(T t)
	{	write(Json.encode(t));
	}
	

	private static bool internalWrite(Level level, ...)
	{
		if ((level >= this.level) && output)
		{	
			string msg = swritef(_arguments, _argptr);
			synchronized(typeid(Log))
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
	static Timer[string] timers;
	static bool enabled = true;
	
	// TODO: Each call to these adds a few microseconds of time and makes the timings off.
	static void start(string timerName)
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
	
	static void stop(string timerName)
	{	if (!enabled)
			return;
		
		auto timer = timerName in timers;
		assert(timer);
		timer.pause();
	}
	
	static string getTimesAndClear()
	{	string result;
		foreach (name, timer; timers)
			result ~= format("%.5fs %s\n", timer.tell(), name);
		clear();
		return result;
	}
	
	static void clear()
	{	timers = null;
	}
	
	
}