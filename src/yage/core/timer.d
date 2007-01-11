/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Either <a href="lgpl.txt">LGPL</a> or <a href="zlib-libpng.txt">zlib/libpng</a>
 */

module yage.core.timer;

import std.perf;
import std.string;

import derelict.sdl.sdl;


// The accuracy of timer is questionable, so this is an alternate to test.
class Timer2
{
	int last_count;

	this()
	{	last_count = SDL_GetTicks();
	}

	float get()
	{	return (SDL_GetTicks()-last_count)/1000.0f;
	}

	void set(double seconds)
	{	last_count = SDL_GetTicks()-cast(int)(seconds*1000);
	}

	void reset()
	{	last_count = SDL_GetTicks();
	}

	char[] toString()
	{	return .toString(get());
	}
}



// Because they have different names on Windows and Linux
version (Windows)
{	alias HighPerformanceCounter PerformanceCounter;
}


/**
 * A cross-platform, high-performance (microsecond) timing class.
 * Example:
 * --------------------------------
 * Timer a = new Timer();
 * float b = a.get();		// b stores the current time.
 * --------------------------------
 */
class Timer
{
	protected:
	bool 	paused	= false;
	//real	min		= 0;
	//real 	max		= real.infinity;
	//real	speed	= 1.0;
	ulong	us		= 0;		// microsecond counter
	PerformanceCounter hpc;

	public:
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

	// Allow for getting the time with the () syntax (good idea?)
	double opCall()
	{	return cast(double)get();
	}

	/// Return the Timer's time in seconds
	synchronized double get()
	{	// Update our microsecond counter
		if (!paused)
		{	hpc.stop();
			us +=  hpc.microseconds();
			double result = us*0.000001;
			hpc.start();
		}
		return us*0.000001;
	}

	/// Is the Timer paused?
	bool getPaused()
	{	return paused;
	}

	/// Set whether the Timer is paused.
	synchronized void setPaused(bool paused)
	{	this.paused = paused;
		if (paused)
		{	hpc.stop();
			us += hpc.microseconds();
		}else
			hpc.start();
	}

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
	{	hpc.stop();
		hpc.start();
		us = 0;
	}

	/** Set the Timer
	 *  Params: time = Measured in seconds. */
	synchronized void set(double time)
	in { assert(time>=0); }
	body
	{	us = cast(ulong)(time*1000000);
	}

	char[] toString()
	{	return .toString(get());
	}
}
