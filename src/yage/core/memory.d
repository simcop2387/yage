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




/*==========================================================================
 * weakref.d
 *	Written in the D Programming Language (http://www.digitalmars.com/d)
 */
/***************************************************************************
 * Creates a weak reference to a class instance.
 *
 * A weak reference lets you hold onto a pointer to an object without 
 * preventing the garbage collector from collecting it.
 * If the garbage collector collects the object then the weak pointer will 
 * become 'null'.  Thus one should always check a weak pointer for null
 * before doing anything that depends upon it having a value.
 *
 * Tested with:
 *	DMD 1.025 / Phobos 1.025
 *	DMD 1.025 / Tango 0.99.4
 * 
 * Usage example:
---
 class Something {}

 auto a = new Something();
 auto wa = new WeakRef!(Something)(a);
 std.gc.fullCollect();
	
 // Reference 'a' prevents collection so wa.ptr is non-null
 assert(wa.ptr is a);

 delete a;
 
 // 'a' is gone now, so wa.ptr magically becomes null
 assert(wa.ptr is null);
---
 *	
 *
 * Author:  William V. Baxter III
 * Contributors: 
 * Date: 21 Jan 2008
 * Copyright: (C) 2008  William Baxter
 * License: Public Domain where allowed by law, ZLIB/PNG otherwise.
 */
//===========================================================================

private {
	alias void delegate(Object) DisposeEvt;
	extern (C) void rt_attachDisposeEvent(Object obj, DisposeEvt evt);
	extern (C) void rt_detachDisposeEvent(Object obj, DisposeEvt evt);
}


class WeakRef(T : Object) {

	private size_t cast_ptr_;
	private void unhook(Object o) {
		if (cast(size_t)cast(void*)o == cast_ptr_)
		{	version(Tango)
				rt_detachDisposeEvent(o, &unhook);
			else 
				o.notifyUnRegister(&unhook);
			
			cast_ptr_ = 0;
		}
	}

	this(T tptr) {
		cast_ptr_ = cast(size_t)cast(void*)tptr;
		version(Tango) {
			rt_attachDisposeEvent(tptr, &unhook);
		} else {
			tptr.notifyRegister(&unhook);
		}
	}
	~this() {
		T p = ptr();
		if (p) {
			version(Tango)
				rt_detachDisposeEvent(p, &unhook);
			else
				p.notifyUnRegister(&unhook);
		}
	}
	T ptr() {
		return cast(T)cast(void*)cast_ptr_;
	}
	WeakRef dup() {
		return new WeakRef(ptr());
	}
}


import tango.core.Memory : GC;
unittest {
	class Something {
		int value;
		this(int v) { value = v; }
		~this() { value = -1; }
	}

	WeakRef!(Object) wa;

	auto a = new Something(1);
	wa = new WeakRef!(Object)(a);
	assert(a is wa.ptr);

	GC.collect();
	assert(a is wa.ptr);

	delete a;

	// a now gone so should be collected
	GC.collect();
	
	assert(wa.ptr is null);
}