/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.core.repeater;

import std.thread;
import std.c.time;
import yage.core.timer;


/**
 * A class to repeatedly call a function at a set inverval, in its own thread.*/
class Repeater : Thread
{
	protected bool active = true;
	protected bool running = false;
	protected float frequency = 1;
	protected int callcount = 0;
	protected Timer since_last_start;

	protected void delegate(float f) func;

	/**
	 * Call func repeatedly.
	 * A call to start() is required to start the process.*/
	this(void delegate(float f) func)
	{	since_last_start = new Timer();
		this.func = func;
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

	/// Get the amount of time since this repeater was last started.
	real getStartTime()
	{	return since_last_start.get();
	}

	/// Start calling the function defined in the constructor.
	void start(float frequency)
	{	this.frequency = frequency;
		since_last_start.reset();
		callcount = 0;
		running = true;
	}

	/// Stop calling the function defined in the constructor.
	void stop()
	{	running = false;
	}

	///
	void setCallCount(int count)
	{	callcount = count;
	}

	/**
	 * Set the frequency
	 * This also resets the call count and */
	void setFrequency(float frequency)
	{	this.frequency = frequency;
		since_last_start.reset();
		callcount = 0;
	}

	// Continuously run the function
	// Need to make it so that func is guaranteed to be called frequency times per second, and catch up if not.
	protected int run()
	{	Timer a = new Timer();
		while (active)
		{	a.reset();
			if (running)
			{
				// Call as many times as needed to catch up.
				double seconds = since_last_start.get();
				while (seconds*frequency > callcount)
				{	func(1/frequency);
					callcount++;
				}
			}
			// Because they use different sleep functions.
			//version(dmd)
				std.c.time.usleep(cast(uint)(1000*1000 / (frequency-a.get()) ));
			version(GDC)
				std.c.time.msleep(cast(uint)(1000 / (frequency-a.get()) ));
		}
		return 0;
	}
}
