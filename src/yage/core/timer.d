/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.core.timer;

import std.perf;
import std.string;
import derelict.sdl.sdl;


// Because they have different names on Windows and Linux
version (Windows)
{	alias HighPerformanceCounter PerformanceCounter;
}


/**
 * A cross-platform, high-performance (microsecond) timing class.
 * Example:
 * --------------------------------
 * Timer a = new Timer();
 * real b = a.get();		// b stores the current time.
 * --------------------------------
 */
class Timer
{
	protected bool 		paused	= false;
	//protected real	min		= 0;
	//protected real 	max		= real.infinity;
	//protected real	speed	= 1.0;
	protected ulong		us		= 0;		// microsecond counter
	protected PerformanceCounter hpc;

	/// Initialize and start the Timer.
	this()
	{	hpc = new PerformanceCounter();
		hpc.start();
	}

	/** Copy Constructor
	 * Params: rhs = This Timer will be a copy of rhs.*/
	this(Timer rhs)
	{	paused = rhs.paused;
		set(rhs.get());
	}

	/// Return the Timer's time in seconds
	real get()
	{	// Update our microsecond counter
		synchronized(this)
		{	if (!paused)
			{	hpc.stop();
				us +=  hpc.microseconds();
				real result = us*0.000001;
				hpc.start();
			}
			return us*0.000001;
	}	}

	/// Is the Timer paused?
	bool getPaused()
	{	return paused;
	}

	/// Set whether the Timer is paused.
	void setPaused(bool paused)
	{	synchronized(this)
		{	this.paused = paused;
			if (paused)
			{	hpc.stop();
				us += hpc.microseconds();
			}else
				hpc.start();
	}	}

	/// Alias of setPaused(true)
	void pause()
	{	setPaused(true);
	}

	/// Alias of setPaused(false)
	void resume()
	{	setPaused(false);
	}

	/// Reset the Timer to zero.
	void reset()
	{	synchronized(this)
		{	hpc.stop();
			if(!paused)
				hpc.start();
			us = 0;
		}
	}

	/** Set the Timer
	 *  Params: time = Measured in seconds. */
	void set(double time)
	in { assert(time>=0); }
	body
	{	us = cast(ulong)(time*1000000);
	}

	char[] toString()
	{	return .toString(get());
	}
}
