/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 * 
 * See Java's Timer class for better ideas.
 */

module yage.core.repeater;

import std.stdio;
import tango.core.Thread;
import std.c.time;
import yage.core.closure;
import yage.core.interfaces;
import yage.core.misc;
import yage.core.timer;

/**
 * A class to repeatedly call a function at a set inverval, in its own thread.
 * TODO: update/combine this with setInterval, or inherit from Timer? */
class Repeater : Timer, IFinalizable
{
	protected double frequency = 60f;
	protected double call_time = 0f;
	
	protected bool active = true;	
	protected bool calling = false;
	protected void delegate(float f) func;
	protected void delegate(Exception e) on_error;
	
	// Allow repeater to run in its own thread
	class HelperThread : Thread
	{
		Repeater outer;	// reference to outer class
		
		this()
		{	super(&run);
		}
		
		void run()
		{	Timer a = new Timer(); // time it takes to call func
			while (active)
			{	a.reset();
				if (!paused())
				{						
					// Call as many times as needed to catch up.
					while (outer.tell() > call_time)
					{	double s = outer.tell();						
						if (func)
						{	calling = true;
							try {
								func(1/frequency); // call the function.
							} catch(Exception e)
							{	if (on_error != null)
									on_error(e);
								else
									throw e;								
							} finally
							{	calling = false;							
							}
						}
						call_time += 1f/frequency;						
						if (paused())
							break;
					}	
				}
				
				// Sleep for 1/frequency - (the time it took to make the calls).				
				usleep(cast(uint)(1_000_000/frequency - a.get()));
			}
		}
	}	
	protected HelperThread thread;
	
	/**
	 * Initialize the Timer
	 * Params:
	 *     start = start the Timer immediately. */
	this(bool start=false)
	{	super(start);		
		thread = new HelperThread();
		thread.outer = this;
		thread.start();
	}
	
	/**
	 * Ensures that the helper thread is stopped on destruction. */
	~this()
	{	finalize();
	}
	
	///
	override void finalize()
	{	active = false;
		if (thread)
		{	thread.join();
			thread = null;
		}
	}
	
	/**
	 * Pause the repeater.
	 * This is guaranteed to never pause in the middle of a call to the repeater's function, but will
	 * block until the call finishes.*/
	override void pause()
	{	super.pause(); // pause the timer

		// This is a primitive way to implement this, but i'm not sure of a better way
		while (calling)
			usleep(cast(int)(1_000/frequency)); // sleep for 1 1000th of the frequency.
	}

	/**
	 * Get / set the call time.
	 * This will always be within tell() and tell()-frequency unless the repeater is behind in calling its function.
	 * Unless the frequency changes, call time can be divided by frequency to get the call count.
	 * Returns: time in seconds. */
	synchronized double getCallTime()
	{	return call_time;		
	}
	synchronized void setCallTime(double call_time) /// ditto
	{	this.call_time = call_time;		
	}
	
	/**
	 * Get / set the frequency.
	 * The frequency defaults to 60hz until set.
	 * If the call function is set, it will be called this many times per second.
	 * Returns: time in hertz. */
	synchronized double getFrequency()
	{	return frequency;		
	}
	synchronized void setFrequency(double frequency) /// ditto
	{	this.frequency = frequency;		
	}
	
	/**
	 * Get / set the function to call. */
	synchronized void delegate(float f) getFunction()
	{	return func;		
	}
	synchronized void setFunction(void delegate(float f) func) /// ditto
	{	this.func = func;
	}
	synchronized void setFunction(void function(float f) func) /// ditto
	{	this.func = toDelegate(func);
	}
	
	/**
	 * Get / a function to call if the update function throws an exception.
	 * If this is set to null (the default), then the exception will just be thrown as normal. */
	synchronized void delegate(Exception e) getErrorFunction()
	{	return on_error;		
	}
	synchronized void setErrorFunction(void delegate(Exception e) on_error) /// ditto
	{	this.on_error = on_error;
	}
	synchronized void setErrorFunction(void function(Exception e) on_error) /// ditto
	{	this.on_error = toDelegate(on_error);
	}
}
