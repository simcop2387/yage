module unittests.benchmark.fastmap;


import tango.io.Stdout;
import tango.text.convert.Format;
import tango.util.container.HashMap;

import yage.core.fastmap;
import yage.core.timer;

/**
 * On a P4 2.8ghz Windows XP Laptop, this shows that Array!(int) is 3-6x faster with ~= as int[]. */
void main()
{
	
	{
		int[] map;
		for (int i=0; i<1000; i++)
			map ~= i;
		
		Timer a = new Timer(true);
		for (int i=0; i<1000; i++)
		{	foreach(j, v; map)
			{ }
		}
		Stdout(Format.convert("{:f6}s, DMD array iteration, 1000 elements 1000 times.", a.tell())).newline;
	}
	{
		int[int] map;
		for (int i=0; i<1000; i++)
			map[2000-i] = i;
		
		Timer a = new Timer(true);
		for (int i=0; i<1000; i++)
		{	foreach(k, v; map)
			{ }
		}
		Stdout(Format.convert("{:f6}s, DMD associative array iteration, 1000 elements 1000 times.", a.tell())).newline;
	}
	{
		HashMap!(int, int) map = new HashMap!(int, int);
		for (int i=0; i<1000; i++)
			map[2000-i] = i;
		
		Timer a = new Timer(true);
		for (int i=0; i<1000; i++)
		{	foreach(v; map.toArray())
			{ }
		}
		Stdout(Format.convert("{:f6}s, tango.util.HashMap iteration, 1000 elements 1000 times.", a.tell())).newline;
	}
	{
		FastMap!(int, int) map;
		for (int i=0; i<1000; i++)
			map[2000-i] = i;
		
		Timer a = new Timer(true);
		for (int i=0; i<1000; i++)
		{	foreach(v; map.values)
			{ }
		}
		Stdout(Format.convert("{:f6}s, yage.core.fastmap iteration, 1000 elements 1000 times.", a.tell())).newline;
	}
	
	
}