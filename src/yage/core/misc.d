/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:	   Eric Poggel
 * License:	   <a href="lgpl3.txt">LGPL v3</a>
 *
 * Miscellaneous core functions and templates that haven't found a place yet.
 */


module yage.core.misc;

import tango.core.Thread;
import tango.core.Traits;
import tango.core.sync.Mutex;
import tango.math.Math;
import tango.text.Util;
import yage.core.array;
import yage.core.parse;
import yage.core.timer;
import yage.system.log;

/**
 * Resolve "../", "./", "//" and other redirections from any path.
 * This function also ensures correct use of path separators for the current platform.*/
char[] cleanPath(char[] path)
{	char[] sep = "/";

	path = substitute(path, "\\", sep);
	path = substitute(path, sep~"."~sep, sep);		// remove "./"

	scope char[][] paths = split(path, sep);
	scope char[][] result;

	foreach (char[] token; paths)
	{	switch (token)
		{	case "":
				break;
			case "..":
				if (result.length)
				{	result.length = result.length-1;
					break;
				}
			default:
				result~= token;
		}
	}
	path = join(result, sep);
	return path;
}


/**
 * Curry arguments to a function (replacing the last parameters) and return a new function.
 * The curried arguments are heap-allocated.  This is useful for making closures, which is done automatically in D2.
 * Modified from http://rosettacode.org/wiki/Y_combinator#D
 * See:  http://en.wikipedia.org/wiki/Currying */
ReturnTypeOf!(F) delegate(ParameterTupleOf!(F)[0..$-Args.length]) curry(F, Args...)(F func, Args curriedArgs) {
	alias ParameterTupleOf!(F) AllArgs;
	alias ReturnTypeOf!(F) Ret;
 
	struct Context {
		AllArgs[$-Args.length..$] curriedArgs; // curried arguments of input function
		F func; // input function
		
		Ret call(AllArgs[0..$-Args.length] args) {
			return func(args, curriedArgs);
		}
	}
 
	auto context = new Context();
	context.curriedArgs = curriedArgs;
	context.func = func;
	return &context.call;
}
unittest
{	auto f1 = (char[] a, char[] b, char[] c) { return a~b~c; };
	auto f2 = curry(f1, "3");
	auto f3 = curry(f2, "2");
	
	assert(f2("1", "2")=="123");
	assert(f3("1")=="123");
	
	auto f4 = curry(f1, "2", "3");
	assert(f4("1")=="123");
	
	auto f5 = curry(f3, "1");
	assert(f5()=="123");
}

/**
 * Make a shallow copy of a class.
 * TODO: dup for structs, and this also doesn't copy base Members. 
 * TODO: Betware arrays, both will be slices of the same array afterward, even after resizing one. */
T dup(T : Object)(T object)
{	if (!object)
		return null;
	T result = new T();
	
	foreach (int index, _; object.tupleof)
		result.tupleof[index] = object.tupleof[index];
	return result;
}
class DupTest { int a, b; }
class DupTest2 : DupTest { int c; }
unittest {	
	auto a = new DupTest2();
	a.a = 3;
	a.c = 4;
	auto b = dup(a);
	assert(a !is b);
	assert(b.c==4);	
	//assert(b.a==3);
}

/**
 * Convert any function pointer to a delegate.
 * _ From: http://www.digitalmars.com/d/archives/digitalmars/D/easily_convert_any_method_function_to_a_delegate_55827.html */
R delegate(P) toDelegate(R, P...)(R function(P) fp)
{	struct S
	{	R Go(P p) // P is the function args.
		{	return (cast(R function(P))(cast(void*)this))(p);
		}
	}
	return &(cast(S*)(cast(void*)fp)).Go;
}

/**
 * Get the base type of any chain of typedefs.
 * This should be added to ParameterTypeTuple so it can work with typedefs. */
template baseTypedef(T)
{	static if (is(T Super == typedef))
		alias baseTypedef!(Super) baseTypedef;
	else
		alias T baseTypedef;
}

///
class FastLock
{
	protected Mutex mutex;
	protected int lockCount;
	protected Thread owner;
	
	///
	this()
	{	mutex = new Mutex();
	}
	
	/**
	 * This works the same as Tango's Mutex's lock()/unlock except provides extra performance in the special case where 
	 * a thread calls lock()/unlock() multiple times while it already has ownership from a previous call to lock().
	 * This is a common case in Yage.
	 * 
	 * For convenience, lock() and unlock() calls may be nested.  Subsequent lock() calls will still maintain the lock, 
	 * but unlocking will only occur after unlock() has been called an equal number of times.
	 * 
	 * On Windows, Tango's lock() is always faster than D's synchronized statement.  */
	void lock()
	{	auto self = Thread.getThis();
		if (self !is owner)
		{	mutex.lock();
			owner = self;
		}
		lockCount++;
	}	
	void unlock() /// ditto
	{	assert(Thread.getThis() is owner);
		lockCount--;
		if (!lockCount)
		{	owner = null; 
			mutex.unlock();
		}
	}	
}

/**
 * Turn any class into a Singleton via a template mixin.
 * Example:
 * --------
 * class Foo
 * {   private this()
 *     {   // do stuff
 *     }
 *     mixin SharedSingleton!(Foo);
 * }
 * 
 * auto a = new Foo();  // a and b reference 
 * auto b = new Foo();  // the same object.
 * --------
 */
template SharedSingleton(T)
{
	/// Reference to the single instance
	private static T singleton;
	
	/**
	 * Get an instance shared among all threads. */
	static T getSharedInstance()
	{	// TODO: Synchronized
		if (!singleton)
			singleton = new T();
		return singleton;
	}
}

/**
 * Unlike shared singleton, this mixin allows one unique instance per thread. */
template Singleton(T)
{
	private static uint tls_key=uint.max;
	
	/**
	 * Get an instance unique to the calling thread.
	 * Each thread can only have one instance. */
	static T getInstance()
	{	
		if (tls_key==uint.max)
			synchronized(T.classinfo)
				tls_key = Thread.createLocal();
		
		T result = cast(T)Thread.getLocal(tls_key);		
		if (!result)
		{	result = new T();
			Thread.setLocal(tls_key, cast(void*)result);
		}
		return result;
	}
}
/*
unittest
{	int x=0;
	class Foo
	{	int bar;
		
		private this()
		{	bar = 3;
			x++;
	    }
	    mixin Singleton!(Foo);
	}
	auto a = Foo.getInstance();
	auto b = Foo.getInstance();
	assert(a==b);
	assert(a.bar==3);
	assert(b.bar==3);
	assert(x==1); // ensure constructor is called only once.
}
*/