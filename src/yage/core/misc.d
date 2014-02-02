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
import yage.core.timer;

/**
 * Resolve "../", "./", "//" and other redirections from any path.
 * This function also ensures correct use of path separators for the current platform.*/
string cleanPath(char[] path)
{	string sep = "/";

	path = substitute(path, "\\", sep);
	path = substitute(path, sep~"."~sep, sep);		// remove "./"

	scope string[] paths = split(path, sep);
	scope string[] result;

	foreach (string token; paths)
	{	switch (token)
		{	case "":
				break;
			case "..":
				if (result.length)
				{	result.length = result.length-1;
					break;
				}
				goto default;
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
{	auto f1 = (string a, char[] b, char[] c) { return a~b~c; };
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
T clone(T : Object)(T object, T destination=null)
{	if (!object)
		return null;
	if (!destination)
		destination = new T();
	
	foreach (int index, _; object.tupleof)
		destination.tupleof[index] = object.tupleof[index];
	return destination;
}
class CloneTest { int a, b; }
class CloneTest2 : CloneTest { int c; }
unittest {	
	auto a = new CloneTest2();
	a.a = 3;
	a.c = 4;
	auto b = clone(a);
	assert(a !is b);
	assert(b.c==4);	
	//assert(b.a==3); // inherited members are not cloned.
}

/**
 * Implements the event pattern.
 * Params:
 *     T = Every listener of this event should accept these arguments
 * Example:
 * Event!(int) event;
 * event.addListener(delegate void(int a) { ... });
 * event(); // calls all listeners. */
struct Event(T...)
{
	void delegate() listenersChanged; /// Called after the listeners are added or removed.
	protected bool[void delegate(T)] listeners; // A set.  Associative arrays are copied by ref, so when one event is assigned to another, they will both point ot the same listeners.

	void addListener(void delegate(T) listener)
	{	listeners[listener] = true;
		if (listenersChanged)
			listenersChanged();
	}

	/// Call all the functions in the listeners list.
	void opCall(T args)
	{	foreach (func, unused; listeners)
		func(args);
	}

	int length()
	{	return listeners.length;
	}

	void removeListener(void delegate(T) listener)
	{	listeners.remove(listener);
		if (listenersChanged)
			listenersChanged();
	}

	void removeAll()
	{	foreach (key; listeners.keys)
		listeners.remove(key);
		if (listenersChanged)
			listenersChanged();
	}
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
// In D 2.030 this became per thread? will need testing.
template Singleton(T)
{
        static T instance;
	
	static T getInstance()
	{	
                
		if (!instance)
                  instance = new T();

		return instance;
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