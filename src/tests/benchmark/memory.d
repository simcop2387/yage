/**
 * Copyright:  (c) 2005-2010 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Boost 1.0
 */

module tests.benchmark.memory;

import yage.core.memory;
import yage.core.timer;
import yage.system.log;

/**
 * This shows that Memory.allocate/free is faster than D's default allocator for larger data. */
void main()
{
	{
		Timer a = new Timer(true);
		for (int i=0; i<10000; i++)
		{	
			int[] b = new int[1024];
		}
		Log.trace("%ss, new int[1024] 10k times", a.tell());
	}
	{
		Timer a = new Timer(true);
		for (int i=0; i<10000; i++)
		{	
			int[] b = new int[1024];
			delete b;
		}
		Log.trace("%ss, new int[1024] 10k, followed by delete", a.tell());
	}
	{
		Timer a = new Timer(true);
		for (int i=0; i<10000; i++)
		{	
			int[] b = Memory.allocate!(int)(1024);
			Memory.free(b);
		}
		Log.trace("%ss, Memory.allocate() int[1024] 10k times followed by Memory.free().", a.tell());
	}
}