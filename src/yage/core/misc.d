/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:	   Eric Poggel
 * License:	   <a href="lgpl3.txt">LGPL v3</a>
 *
 * Miscellaneous core functions and templates that have no other place.
 */


module yage.core.misc;

import tango.math.Math;
import tango.text.Util;
import yage.core.array;
import yage.core.parse;
import yage.core.timer;


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
 * Turn any class into a Singleton via a template mixin
 * Example:
 * --------
 * class Foo
 * {   private this()
 *     {   // do stuff
 *     }
 *     mixin Singleton!(Foo);
 * }
 * 
 * auto a = new Foo();  // a and b reference 
 * auto b = new Foo();  // the same object.
 * --------
 */
template Singleton(T)
{
	/// Reference to the single instance
	private static T singleton;
	
	static T getInstance()
	{	// TODO: Synchronized
		if (!singleton)
			singleton = new T();
		return singleton;
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