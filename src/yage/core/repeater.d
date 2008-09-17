/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 * 
 * See Java's Timer class for better ideas.
 */

module yage.core.repeater;

import std.stdio;
import std.thread;
import std.c.time;
import yage.core.timer;


/**
 * A class to repeatedly call a function at a set inverval, in its own thread.
 * TODO: update/combine this with setInterval, or inherit from Timer? */
class Repeater : Thread
{
	protected bool active = true;
	protected float frequency = 1;
	protected int callcount = 0;
	protected Timer timer;

	void delegate(float f) func;

	/**
	 * Call func repeatedly.
	 * A call to start() is required to start the process.*/
	this()
	{	timer = new Timer();
		//this.func = func;
		super.start();
	}

	~this()
	{	active = false;
		try {	// Doesn't seem to work as documented?
			wait();
			pause();
		} catch {}
	}

	///
	int getCallCount()
	{	return callcount;
	}

	///
	float getFrequency()
	{	return frequency;
	}

	/// Start calling the function defined in the constructor.
	void play(float frequency=60)
	{	this.frequency = frequency;
		timer.play();		
	}

	/// Stop calling the function defined in the constructor.
	/// Renamed pause2 since pause() gets called when the gc pauses all threads.
	void pause2()
	{	timer.pause();
		
	}
	
	bool paused()
	{	return timer.paused();		
	}
	
	double tell()
	{	return timer.tell();		
	}

	///
	void setCallCount(int count)
	{	callcount = count;
	}

	
	void remove()
	{	active = false;
		wait(); // wait for thread to terminate.
	}
	
	// Continuously run the function
	// Catches up if it gets behind.
	protected int run()
	{	Timer a = new Timer();
		while (active)
		{	a.reset();
			//writefln("active");
			if (!timer.paused())
			{	
				
				// Call as many times as needed to catch up.
				double seconds = timer.tell();
				//writefln(seconds*frequency, " ", callcount);
				while (seconds*frequency > callcount && active)
				{	//writefln("func");
					func(1/frequency);
					callcount++;
				}
			}
			// Sleep for 1/frequency - (the time it took to make the calls).
			if (active)
			{	version(DigitalMars)
					usleep(cast(uint)(1_000_000/frequency - a.get()));
				version(GDC)
					msleep(cast(uint)(1000/frequency - a.get()));
			}
		}
		return 0;
	}
}

/+
/// TODO: Replace with this superior version
class Repeater : Timer
{
	protected double frequency = 60f;
	protected double call_time = 0f;
	
	protected bool active = true;
	protected void delegate(float f) func;
	
	// Allow repeater to run in its on thread
	class Helper : Thread
	{
		Repeater outer;
		
		void start()
		{	super.start();	
		}
		
		override int run()
		{	Timer a = new Timer();
			while (active)
			{	a.reset();
				if (!paused())
				{	
					// Call as many times as needed to catch up.
					while (outer.tell() > call_time)
					{	double s = outer.tell();
						writefln(outer.tell());
						if (func)
							func(1/frequency);
						call_time += 1f/frequency;
					}	
					
				}
				
				// Sleep for 1/frequency - (the time it took to make the calls).				
				version(DigitalMars)					
					std.c.time.usleep(cast(uint)(1_000_000/frequency - a.get()));				
				version(GDC)					
					std.c.time.msleep(cast(uint)(1000/frequency - a.get()));				
			}
			return 0;
		}
	}	
	Helper thread;
	
	/**
	 * Initialize the Timer
	 * Params:
	 *     start = start the Timer immediately. */
	this(bool start=false)
	{	super(start);		
		thread = new Helper();
		thread.outer = this;
		thread.start();
	}
	
	~this()
	{	active = false;
		try {	// Doesn't seem to work as documented?
			thread.wait();
			thread.pause();
		} catch {}
	}
	
	/**
	 * Get / set the call time.
	 * This will always be within tell() and tell()-frequency unless the repeater is behind in calling its function.
	 * Unless the frequency changes, call time can be divided by frequency to get the call count.
	 * Returns: time in seconds. */
	double getCallTime()
	{	return call_time;		
	}
	void setCallTime(double call_time) /// ditto
	{	this.call_time = call_time;		
	}
	
	/**
	 * Get / set the frequency.
	 * The frequency defaults to 60hz until set.
	 * If the call function is set, it will be called this many times per second.
	 * Returns: time in hertz. */
	double getFrequency()
	{	return frequency;		
	}
	void setFrequency(double frequency) /// ditto
	{	this.frequency = frequency;		
	}
	
	
	/**
	 * Get / set the function to call. */
	double getFunction()
	{	return frequency;		
	}
	void setFunction( void delegate(float f) func) /// ditto
	{	this.func = func;		
	}
	

}
+/
