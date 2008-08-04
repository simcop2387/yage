/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.core.timer;

import std.c.math;
import std.perf;
import std.string;
//import derelict.sdl.sdl;


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
class Timer /* implements ITemporal */ // This would require core to depend on system.
{
	protected bool 		_paused	= false;
	protected double	pause_after = double.infinity;
	protected double	min		= 0;
	protected double 	max		= double.infinity;
	//protected double	speed	= 1.0;
	protected ulong		us		= 0;		// microsecond counter
	protected PerformanceCounter hpc;

	/// Initialize and start the Timer.
	this(bool start=true)
	{	hpc = new PerformanceCounter();
		_paused = !start;
		if (start)
			hpc.start();
	}

	/** 
	 * Copy Constructor
	 * Params: rhs = This Timer will be a copy of rhs.*/
	this(Timer rhs)
	{	seek(rhs.get());
		min = rhs.min;
		max = rhs.max;
		if (rhs.paused())
			pause();
		else
			play();
	}
	
	/**
	 * Stop the timer.  When play() is called again, it will start from the time when it was paused. */
	void pause()
	{	synchronized(this)
		{	_paused = true;
			hpc.stop();
			us += hpc.microseconds();
		}
	}
	
	/// Is the Timer paused?
	bool paused()
	{	return _paused;
	}
	
	/**
	 * Start the timer. */
	void play()
	{	synchronized(this)
		{	_paused = false;
			hpc.start();
		}	
	}
	
	/**
	 * Stop the timer and reset its position.*/
	void stop()
	{	synchronized(this)
		{	_paused = true;
			hpc.stop();
			us = cast(ulong)(min*1000000);
		}
	}
	
	/**
	 * Pause the timer when it reaches this amount. 
	 * Must be between (inclusive) the arguments of setRange(min, max) or else it will be ignored. 
	 * Use pauseAfter(double.infinity) to clear pauseAfter. */
	void pauseAfter(double seconds)
	{	pause_after = seconds;		
	}
	
	/** 
	 * Set the Timer. */
	void seek(double seconds)
	in { assert(seconds>=0); }
	body
	{	us = cast(ulong)(seconds*1000000);
	}
	
	/**
	 * Get the Timer's time in seconds.	 */
	double tell()
	{	
		synchronized(this)
		{	if (!_paused)
			{	hpc.stop();
				us +=  hpc.microseconds(); // Update our microsecond counter
				hpc.start();
			}
		
			double relative = us*0.000001;
			
			// Only use pause_after if it's between min and max.
			if (min <= pause_after && pause_after <= max)
				if (relative > pause_after)
					return pause_after;
			
			// employ floating point modulus division to keep between min and max.
			real range = max-min;
			if (relative > max)
				relative = min + fmod(relative-min, range);
			if (relative < min)
				relative = max + fmod(relative-max, range);
	
			return relative;
		}
	}
	
	/**
	 * Set the timers roll-under and roll-over values.
	 * Provide no arguments to reset them to the defaults of 0 and infinity.
	 * Params:
	 *     min = The timer will never be less than this value.
	 *     max = The timer will never be greater than this value and will rollover back to min after crossing it.*/
	void setRange(double min=0, double max=double.infinity)
	{	this.min = min;
		this.max = max;		
	}
	
	///
	char[] toString()
	{	return .toString(get());
	}
	
	
	
	
	
	
	
	
	
	
	/// @deprecated
	void set(real time)
	{	seek(time);
	}

	/// @deprecated alias of tell().
	real get()
	{	return tell();		
	}

	/// @deprecated Is the Timer paused?
	bool getPaused()
	{	return paused();
	}

	/// @deprecated Set whether the Timer is paused.
	void setPaused(bool paused)
	{	pause();		
	}	

	/// @deprecated
	void resume()
	{	setPaused(false);
	}

	/// @deprecated
	void reset()
	{	synchronized(this)
		{	hpc.stop();
			if(!paused)
				hpc.start();
			us = 0;
		}
	}
}
