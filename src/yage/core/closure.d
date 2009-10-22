/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */
module yage.core.closure;

import tango.core.Traits;
import tango.io.Stdout;
import yage.core.parse;

/**
 * Create a closure -- a function with arguments that can be called later, even when the arguments go out of scope.
 * Params:
 *     func = The function to call.  This can also be a class methods so long as they aren't static.
 *            For now, static method calls must be wrapped inside a non-static function.
 *     var_args = A variable number of arguments to bind to the function.  Does not support out or inout arguments.
 * Returns: An object that can be called via opCall(), which calls the original function
 * Example:
 * --------
 * Closure c = closure((int a, char[] b)
 * {	writefln(a, b);
 * }, 3, "Hello");
 * 
 * // Later, after a and b go out of scope
 * c(); // writes "3Hello"
 * 
 * // Alternatively, we can use functions (even class methods) instead of delegates.
 * class Foo
 * {	int bar(int a,)
 * 		{	return a;
 * 		}
 * }
 * Foo f = new Foo();
 * Closure c = closure(&f.bar, 3);
 * 
 * // Later, after f goes out of scope.
 * writefln(c());
 * -------- 
 */
ClosureHelper!(T) closure(T, A...)(T func, A a)
{	return new ClosureHelper!(T)(func, a);
}
unittest
{	assert(closure(() { return 4; })() == 4);	// no arguments test
	assert(closure((int a) { return a+1; }, 3)() == 4); // 1 argument
	assert(closure((char[] a, char[] b) { return a~b; }, "h", "i")() == "hi"); // 2 arguments
}

/**
 * Allows working with the various templated return types of closure() as a single type.
 * This is useful for creating an arry of closures, for example. 
 * However, this doesn't allow getting any return values, since D doesn't allow overloading by return type. */
interface Closure
{	/// Call the function
	void call();
}

/*
 * Stores the function and arguments on the heap for later. */
class ClosureHelper(T) : Closure
{	protected T func;
	protected ParameterTupleOf!(T) func_args;
	
	this (T func, ParameterTupleOf!(T) func_args)
	{	this.func = func;
		static if (func_args.length)
			foreach(int i, arg; func_args) // straight assignment fails in dmd.
				this.func_args[i] = func_args[i];
	}
	
	ReturnTypeOf!(T) opCall()
	{	return func(func_args);		
	}
	
	void call()
	{	func(func_args);		
	}
}