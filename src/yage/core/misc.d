/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:	   Eric Poggel
 * License:	   <a href="lgpl3.txt">LGPL v3</a>
 *
 * Miscellaneous core functions and templates that haven't found a place yet.
 */


module yage.core.misc;

import tango.core.Thread;
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