module yage.core.memory;

import tango.core.Thread;
import yage.core.array;
import yage.core.misc;

/**
 * This class allows allocating and freeing memory from a stack in a last-in/first-out manner,
 * A separate stack is used for each thread, allowing complete thread safety.
 * D's built-in new/delete is faster for allocations less than 50 bytes, but for large
 * allocations, this is much faster.
 * 
 * Example:
 * --------
 * long[] foo = Memory.allocate!(long)(50);
 * Bar[] bar = Memory.allocate!(Bar)(10);
 * ...
 * Memory.free(bar);
 * Memory.free(foo); // must be freed in reverse order.
 * --------
 */
class Memory
{
	private ArrayBuilder!(ubyte) _memory;
	
	private mixin Singleton!(Memory);
	
	
	/**
	 * Get a new array of type T. */
	static T[] allocate(T)(int length)
	{	length *= T.sizeof;
	ArrayBuilder!(ubyte)* memory = &getInstance()._memory; // get TLS version of _memory.
		int l = memory.length;
		memory.length = l += length;
		if (memory.reserve < l)
			memory.reserve = l;
		
		return cast(T[]) memory.data[$-length..$];
	}
	
	/**
	 * Free a previously allocated array. */
	static void free(T)(T[] data)
	{	ArrayBuilder!(ubyte)* memory = &getInstance()._memory;
		memory.length = memory.length - data.length*T.sizeof;
	}
	
	/**
	 * Free all memory for the current thread. */
	static void freeAll()
	{	ArrayBuilder!(ubyte)* memory = &getInstance()._memory;
		memory.length = 0;
	}
	
	unittest {
		long[] test1 = Memory.allocate!(long)(50);
		for (int i=0; i<test1.length; i++)
			test1[i] = i;
		assert(Memory.getInstance()._memory.length > 0);
		Memory.free!(long)(test1);
		assert(Memory.getInstance()._memory.length == 0);
	}
}