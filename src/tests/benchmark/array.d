module unittests.benchmark.array;

import tango.io.Stdout;
import tango.text.convert.Format;

import yage.core.array;
import yage.core.timer;

/**
 * On a P4 2.8ghz Windows XP Laptop, this shows that ArrayBuilder!(int) is 3-6x faster with ~= as int[]. */
void main()
{
	{
		Timer a = new Timer(true);
		for (int i=0; i<1000; i++)
		{	
			int[] array;
			for (int j=0; j<1000; j++)
				array ~= j;
		}
		Stdout(Format.convert("{:f6}s, DMD array concat, 1000 elements 1000 times.", a.tell())).newline;
	}
	{
		Timer a = new Timer(true);
		for (int i=0; i<1000; i++)
		{	
			ArrayBuilder!(int) array;
			for (int j=0; j<1000; j++)
				array ~= j;
		}
		Stdout(Format.convert("{:f6}s, yage.core.array concat, 1000 elements 1000 times.", a.tell())).newline;
	}
}