/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.core.repeater;

import tango.core.Thread;
import yage.core.object2;
import yage.core.misc;
import yage.core.timer;
import yage.system.log;

/**
 * A class to repeatedly call a function at a set inverval, in its own thread. */
class Repeater : Thread, IDisposable
{
	double frequency = 60f; /// If the call function is set, it will be called this many times per second.
	Exception error; /// If func throws an exception, the thread will terminate and it will be stored here.
	
	/**
	 * This is the call count * 1/frequency
	 * This will always be within tell() and tell()-frequency unless the repeater is behind in calling its function.
	 * Unless the frequency changes, call time can be divided by frequency to get the call count.*/
	double internalTime = 0f;
	
	protected bool active = true; // Changes from true to false only once.
	protected bool calling = false; // currently in the middle of calling the user function.
	protected bool skipPause = false;
	protected void delegate() func;
	
	protected Timer timer;
	
	/**
	 * 
	 * Params:
	 *     start = start the Timer immediately. */
	this(void delegate() func, bool start=false, double frequency=60f)
	{	this.func = func;
		this.frequency = frequency;
		timer = new Timer(start);
		isDaemon(true); // if the application stops, this thread will stop also.
		super(&run);		
		super.start();
	}
	this(void function() func, bool start=false, double frequency=60f)
	{	this(toDelegate(func), start, frequency);
	}
	
	/**
	 * Ensures that the helper thread is stopped on destruction. */
	~this()
	{	dispose();
	}
	
	///
	void dispose()
	{	if (active)
		{	active = false; // why does this crash on exit when compiling in debug mode?
			pause();
			timer = null;
		}
	}
	
	///
	void play()
	{	timer.play();
	}
	
	///
	double tell()
	{	return timer.tell();
	}
	
	/**
	 * Pause the repeater.
	 * This is guaranteed to never pause in the middle of a call to the repeater's function, but will
	 * block until the call finishes.*/
	void pause()
	{	skipPause = true;
		timer.pause(); // pause the timer

		// Block until the repeater has paused().
		// This is a primitive way to implement a sleep wait, but i'm not sure of a better way
		while (calling)
			Thread.sleep(.001/frequency); // sleep for 1 1000th of the frequency.
	}
	
	///
	bool paused()
	{	return timer.paused();
	}
	
	///
	void seek(double seconds)
	{	timer.seek(seconds);
	}
	
	private void onError(Exception e)
	{	char[] msg;
		e.writeOut(delegate void(char[] a) {
			msg ~= a;
		});
	};
	
	private void run()
	{	Timer a = new Timer(true); // time it takes to call func
		assert(active);
		while (active)
		{	a.seek(0);
			if (!timer.paused())
			{			
				// Call as many times as needed to catch up.
				while (active && timer.tell() > internalTime)
				{	
					double s = timer.tell();						
					if (func)
					{	
						calling = true;
						try {
							func(); // call the function.
						} catch(Exception e)
						{	active = false;
							error = e;
							Log.error(YageException.getStackTrace(e));
						} finally
						{	calling = false;
						}
					}
					internalTime += 1f/frequency;						
					if (timer.paused())
						break;
				}	
			}
			
			// Sleep for 1/frequency - (the time it took to make the calls).
			if (active && !skipPause)
			{	float sleep_time = 1/frequency - a.tell();
				if (sleep_time > 0)
					Thread.sleep(1/frequency - a.tell());
			}
			skipPause = false;
		}
	}
}