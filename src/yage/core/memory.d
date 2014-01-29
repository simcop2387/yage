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
	debug {
		private TypeInfo[] allocationTypes;
		private int[] allocationSizes;
	}

	// DMD 1.064 or linux cannot handle the Singleton mixin here for some reason
	version (linux) {
		private static uint tls_key=uint.max;
	
		/**
		 * Get an instance unique to the calling thread.
		 * Each thread can only have one instance. */
		static Memory getInstance()
		{	
			if (tls_key==uint.max)
				synchronized(Memory.classinfo)
					tls_key = Thread.createLocal();
			
			Memory result = cast(Memory)Thread.getLocal(tls_key);		
			if (!result)
			{	result = new Memory();
				Thread.setLocal(tls_key, cast(void*)result);
			}
			return result;
		}
	}
	version (Windows) {
		private mixin Singleton!(Memory);
	}

	
	
	/**
	 * Get a new array of type T. 
	 * Params:
	 *     length The number of array elements. */
	static T[] allocate(T)(int length)
	{	int bytes = length * T.sizeof; // in bytes
		auto instance = getInstance();
		ArrayBuilder!(ubyte)* memory = &instance._memory; // get TLS version of _memory.
		int l = memory.length;
		memory.length = l += bytes;
		if (memory.reserve < l)
			memory.reserve = l;
		
		debug {			
			instance.allocationTypes ~= typeid(T);
			instance.allocationSizes ~= bytes;
		}
		
		return cast(T[]) memory.data[$-bytes..$];
	}
	
	/**
	 * Free a previously allocated array. */
	static void free(T)(T[] data)
	{	int bytes = data.length*T.sizeof; // in bytes
		auto instance = getInstance();
		debug {
			string error = "Memory must be freed in the reverse order it was allocated.";
			assert(bytes == instance.allocationSizes[$-1], error);
			assert(typeid(T) == instance.allocationTypes[$-1], error);
			instance.allocationSizes.length = instance.allocationSizes.length-1;
			instance.allocationTypes.length = instance.allocationTypes.length-1;
		}
		ArrayBuilder!(ubyte)* memory = &instance._memory;
		memory.length = memory.length - bytes;
	}
	
	/**
	 * Free all memory for the current thread. */
	static void freeAll()
	{	ArrayBuilder!(ubyte)* memory = &getInstance()._memory;
		memory.length = 0;
	}
	
	unittest {
		
		// Test allocation
		long[] test1 = Memory.allocate!(long)(50);
		assert(test1.length == 50);
		for (int i=0; i<test1.length; i++)
			test1[i] = i;
		assert(Memory.getInstance()._memory.length > 0);
		Memory.free!(long)(test1);
		assert(Memory.getInstance()._memory.length == 0);

		// Test order
		auto test2 = Memory.allocate!(int)(20);
		auto test3 = Memory.allocate!(int)(30);
		Memory.free(test3);
		Memory.free(test2);
	}
}