/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.core.closure;

import std.stdarg;
import std.traits;
import yage.core.parse;

/**
 * Create a closure -- a function with arguments that can be called later, even when the arguments go out of scope.
 * Params:
 *     func = The function to call.  This can also be a class methods so long as they aren't static.
 *            For now, static method calls must be wrapped inside a non-static function.
 *     ...  = A variable number of arguments to bind to the function.  Does not support out or inout arguments.
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
	protected ParameterTypeTuple!(T) func_args;
	
	this (T func, ParameterTypeTuple!(T) func_args)
	{	this.func = func;
		static if (func_args.length)
			foreach(int i, arg; func_args) // straight assignment fails in dmd.
				this.func_args[i] = func_args[i];
	}
	
	ReturnType!(T) opCall()
	{	return func(func_args);		
	}
	
	void call()
	{	func(func_args);		
	}
}




/+
/**
* Copyright:  (c) 2005-2008 Eric Poggel
* Authors:    Eric Poggel
* License:    <a href="lgpl.txt">LGPL</a>
*/
module yage.core.closure;

import std.stdarg;
import std.traits;
import yage.core.parse;
import yage.core.misc;

/**
* Create a closure -- a function with arguments that can be called later, even when the arguments go out of scope.
* Params:
*     func = The function to call.  This can also be a class methods so long as they aren't static.
*            For now, static method calls must be wrapped inside a non-static function.
*     ...  = A variable number of arguments to bind to the function.  Does not support out or inout arguments.
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
ClosureClass!(T) closure(T)(T func, ...)
{	return closure(func, _arguments, _argptr);
}
ClosureClass!(T) closure(T)(T func, TypeInfo[] _arguments, void* _argptr) /// ditto
{	ParameterTypeTuple!(T) func_args;
	assert(_arguments.length == func_args.length, 
		swritef("Wrong number of arguments passed to function %s, expected %d but received %d", 
			func.stringof, func_args.length, _arguments.length));
	
	foreach(int i, arg; func_args)
	{	alias typeof(func_args[i]) A;
		assert ((_arguments[i] == typeid(A)), 
			swritef("Wrong type of argument passed to argument %d of function %s, expected %d but received %d", 
				i, func.stringof, typeid(A), _arguments[i]));
		func_args[i] = va_arg!(A)(_argptr);
	}
	return ClosureStruct!(T).instance(func, func_args).toClass();
}

/**
* Same as above, but with the return value as a struct instead of a class, so there's no heap allocation.
* Unlike the above, the various return value types don't implement a common interface, so they can't be used in arrays
* or other generic ways. */
ClosureStruct!(T) closureStack(T)(T func, ...)
{	return ClosureStruct!(T).instance(func, _arguments, _argptr);
}
ClosureStruct!(T) closureStack(T)(T func, TypeInfo[] _arguments, void* _argptr) /// ditto
{	return ClosureStruct!(T).instance(func, _arguments, _argptr);
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
* Stores the function and arguments into a single class, so they can be called later.
* Params:
*     T The function type. */
class ClosureClass(T) : Closure
{	
	protected ClosureStruct!(T) closure;

	this(ClosureStruct!(T) closure)
	{	this.closure = closure;	
	}
	
	ReturnType!(T) opCall()
	{	return closure();		
	}
	
	void call()
	{	closure();		
	}
}

/*
* Stores the function and arguments into a single struct, so they can be called later.
* Params:
*     T The function type. */
struct ClosureStruct(T)
{	protected T func;
	protected ParameterTypeTuple!(T) func_args;

	static ClosureStruct!(T) instance(T func, ParameterTypeTuple!(T) func_args)
	{	ClosureStruct!(T) result;
		result.func = func;
		static if (func_args.length)
			foreach(int i, arg; func_args) // straight assignment fails in dmd.
				result.func_args[i] = func_args[i];
		return result;
	}
	
	ClosureClass!(T) toClass()
	{	return new ClosureClass!(T)(*this);		
	}
	
	ReturnType!(T) opCall()
	{	return func(func_args);		
	}
	
	void call()
	{	func(func_args);		
	}
}
+/