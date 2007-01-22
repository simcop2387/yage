/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.util.repeater;

import std.thread;
import std.c.time;
import yage.core.timer;

/// A class to repeatedly call a function at a set inverval, in its own thread.
class Repeater : Thread
{
	bool active = true;
	bool running = false;
	float frequency = 1;

	int callcount = 0;
	Timer since_last_start;

	protected void delegate(float f) func;

	/**
	 * Call func repeatedly.
	 * A call to start() is required to start the process.
	 * Params: frequency how many times per second to call func. */
	this(void delegate(float f) func, float frequency)
	{	since_last_start = new Timer();
		this.func = func;
		this.frequency = frequency;
		super.start();
	}

	~this()
	{	active = false;
		try {	// Doesn't seem to work as documented?
			wait();
			pause();
		} catch {}
	}

	// Need to make it so that func is guaranteed to be called frequency times per second, and catch up if not.
	protected int run()
	{	Timer a = new Timer();
		while (active)
		{	//a.reset();
			if (running)
			{	func(1/frequency);
				callcount++;
			}
			std.c.time.usleep(cast(uint)(1000*1000 / (frequency/*-a.get()*/) ));
		}
		return 0;
	}

	/// Start calling the function defined in the constructor.
	void start()
	{	since_last_start.reset();
		running = true;
	}

	/// Stop calling the function defined in the constructor.
	void stop()
	{	running = false;
	}

	int getCallCount()
	{	return callcount;
	}

	void setCallCount(int count)
	{	callcount = count;
	}
}
