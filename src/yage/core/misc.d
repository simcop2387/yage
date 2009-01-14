/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:	Eric Poggel
 * License:	<a href="lgpl.txt">LGPL</a>
 *
 * Miscellaneous core functions and templates that have no other place.
 */


module yage.core.misc;

import std.file;
import std.math;
import std.path;
import std.random;
import std.string;
import std.stdio;
import std.stdarg;
import std.traits;
import yage.core.array;
import yage.core.parse;
import yage.core.timer;

/// Given relative path rel_path, returns an absolute path.
char[] absPath(char[] rel_path)
{
	// Remove filename
	char[] filename;
	int index = rfind(rel_path, sep);
	if (index != -1)
	{	filename = rel_path[rfind(rel_path, sep)..length];
		rel_path = replace(rel_path, filename, "");
	}

	char[] cur_path = getcwd();
	try {	// if can't chdir, rel_path is current path.
		chdir(rel_path);
	} catch {};
	char[] result = getcwd();
	chdir(cur_path);
	return result~filename;
}

/**
 * Resolve "../", "./", "//" and other redirections from any path.
 * This function also ensures correct use of path separators for the current platform.*/
char[] cleanPath(char[] path)
{	char[] sep = "/";

	path = replace(path, "\\", sep);
	path = replace(path, sep~"."~sep, sep);		// remove "./"

	char[][] paths = std.string.split(path, sep);
	char[][] result;

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
	path = std.string.join(result, sep);
	delete paths;
	delete result;
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
template Singleton(Class)
{
	/// Reference to the single instance
	private static Class singleton;
	
	static Class getInstance()
	{	if (!singleton)
			singleton = new Class();
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