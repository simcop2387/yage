/**
 * Copyright:  (c) 2005-2010 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Boost 1.0
 */

module tests.benchmark.parallel;

import tango.math.Math;

import yage.core.array;
import yage.core.parallel;
import yage.core.timer;
import yage.system.log;

/**
 * On a P4 2.8ghz Windows XP Laptop, this shows that ArrayBuilder!(int) is 3-6x faster with ~= as int[]. */
void main()
{
	
	int[] array;
	for (int i=0; i<1000; i++)
		array ~= i;

	Timer t1 = new Timer(true);
	for (int i=0; i<10; i++)
	{
		
		int count;
		foreach(inout a; array)	
		{	float f = a;
			for (int j=0; j<100; j++)
				f = sqrt(f);
			a = cast(int)f;
			count++;
		}		
	}
	Log.trace("%ss, regular (non-parallel) foreach, 1000 elements with 100 sqrt's per iteration, 10 times.", t1.tell());

	
	Timer t2 = new Timer(true);
	for (int i=0; i<10; i++)
	{
		
		int count;
		foreach(inout a; parallel(array))	
		{	float f = a;
			for (int j=0; j<100; j++)
				f = sqrt(f);
			a = cast(int)f;
			count++;
		}
	}
	Log.trace("%ss, parallel foreach, 100 elements with 1000 sqrt's per iteration, 10 times.", t2.tell());
}