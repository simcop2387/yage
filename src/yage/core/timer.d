/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.core.timer;

import tango.stdc.math;
import tango.util.Convert;
import tango.text.convert.Format;
import tango.time.StopWatch;


/**
 * A cross-platform, high-performance (microsecond) timing class.
 * Example:
 * --------------------------------
 * Timer a = new Timer(true);
 * double b = a.get();		// b stores the current time.
 * --------------------------------
 */
class Timer
{
	protected bool 		_paused	= false;
	protected double	pause_after = double.infinity;  // This is extreneous.  It serves the same function as max and loop=false
	protected double	min		= 0;
	protected double 	max		= double.infinity;
	//protected double	speed	= 1.0;
	protected ulong		us		= 0;		// microsecond counter
	protected StopWatch hpc;
	
	protected Timer source; // TODO:	 allow using one timer as the souce of another, so pausing a scene could pause all timers in that scene.

	/// Initialize and start the Timer.
	this(bool start=false)
	{	_paused = !start;
		us = 0;
		if (start)
			hpc.start();
	}
	
	///
	Timer clone()
	{	auto result = new Timer(!this.paused());
		result.pause_after = pause_after;
		result.min = min;
		result.max = max;
		result.seek(tell());
		return result;
	}
	
	// Get the timer's time, ignoring loop settings.
	protected double rawTime()
	{	if (source)
			return source.tell();
		if (!_paused)
		{	hpc.stop();
			us +=  hpc.microsec(); // Update our microsecond counter
			hpc.start();
		}
		return us*0.000001;
	}
	
	/**
	 * Stop the timer.  When play() is called again, it will start from the time when it was paused. */
	void pause()
	{	synchronized(this)
		{	if (!_paused)
			{	_paused = true;
				hpc.stop();
				us += hpc.microsec();
		}	}
	}
	unittest {
		Timer a = new Timer();
		a.pause(); // a bug once made this sequence of calls
		a.play();  // set the time to a very large number.
		assert(a.tell() < 0.1);
	}
	
	/// Is the Timer paused?
	bool paused()
	{	return _paused;
	}
	
	/**
	 * Start the timer. */
	void play()
	{	if (_paused)
			synchronized(this)
			{	_paused = false;
				hpc.start();
			}	
	}
	
	/**
	 * Stop the timer and reset it to zero.*/
	void stop()
	{	synchronized(this)
		{	_paused = true;
			hpc.stop();
			us = cast(ulong)(min*1_000_000);
		}
	}
	
	/**
	 * Pause the timer when it reaches this amount. 
	 * Must be between (inclusive) the arguments of setRange(min, max) or else it will be ignored. 
	 * Use pauseAfter() with no arguments to clear pauseAfter. */
	void setPauseAfter(double seconds=double.infinity)
	{	pause_after = seconds;		
	}
	double getPauseAfter() /// ditto
	{	return pause_after;		
	}
	
	/** 
	 * Set the Timer. */
	void seek(double seconds)
	in { assert(seconds>=0); }
	body
	{	us = cast(ulong)(seconds*1_000_000);
	}
	
	/**
	 * Get the Timer's time in seconds.	 */
	double tell()
	{	
		//synchronized(this)
		{	double relative = rawTime();
			
			// Only use pause_after if it's between min and max.
			if (min <= pause_after && pause_after <= max)
				if (relative > pause_after)
					return pause_after;
			
			// employ floating point modulus division to keep between min and max.
			double range = max-min;
			if (relative > max)
				relative = min + fmod(relative-min, range);
			if (relative < min)
				relative = max + fmod(relative-max, range);
	
			return relative;
		}
	}
	
	/**
	 * Set the timer's roll-under and roll-over values.
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
	{	return Format.convert("{:d8}", tell());
	}
}