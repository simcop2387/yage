/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */
module yage.core.async;

import tango.core.Traits;
import tango.core.Vararg;
import tango.core.Thread;
import tango.text.convert.Format;

/**
 * Call a function via a thread after a non-blocking delay.
 * TODO: This should use closure instead of duplicating its functionality.
 * Params:
 *     delay = Wait this many seconds before calling func.
 *     func = Function to call
 *     _args = Argument list to pass to func.
 * Returns: a Timeout class that can be passed to clearTimeout.
 * 
 * Example:
 * --------
 * void func(char[] s)
 * {	Stdout(s, t);
 * }
 *
 * setTimeout(1, &func, "foo"); // call func with argument of "foo" after 1 second.
 * auto t = setTimeout(2, (char[] s, int t) { Stdout(s, t); }, "foo", 4);
 * clearTimeout(t); // cancel second timeout function.
 * --------
 */
Timeout!(T) setTimeout(T)(float delay, T func, ...)
{	
	// Bind arguments to function
	ParameterTupleOf!(func) func_args;
	assert(_arguments.length == func_args.length, 
		Format.convert("Wrong number of arguments passed to setTimeout, expected {} but received {}", 
			func_args.length, _arguments.length));
	foreach(int i, arg; func_args)
	{	alias typeof(func_args[i]) A;
		func_args[i] = va_arg!(A)(_argptr);
	}

	// Spawn a thread to call the function after a delay.
	auto t = new Timeout!(T)(delay, func, func_args);
	t.start();
	return t;
}
unittest
{	// Causes a weird runtime crash in kernel32.dll when compiled in debug mode.
	//auto t = setTimeout(0.0001f, (char[] s, int t) { assert(s=="foo" && t==4); }, "foo", 4);
}

/**
 * This function is the same as setTimeout, except that func is called 
 * repeatedly after delay until clearInterval is called. 
 * TODO: Merge with repeater?*/
Timeout!(T) setInterval(T)(float delay, T func, ...)
{	
	// Bind arguments to function
	ParameterTupleOf!(func) func_args;
	assert(_arguments.length == func_args.length, 
		Format.convert("Wrong number of arguments passed to setInterval, expected {} but received {}", 
			func_args.length, _arguments.length));
	foreach(int i, arg; func_args)
	{	alias typeof(func_args[i]) T;
		func_args[i] = *cast(T *)_argptr;
		_argptr += T.sizeof;
	}

	// Spawn a thread to call the function after a delay.
	auto t = new Timeout!(T)(delay, func, func_args);
	t.repeating = true;
	t.start();
	return t;
}

/**
 * Clear a timeout or interval that has previously been set.
 * Params:
 *     t = the return value of setTimeout or setInterval. */
void clearTimeout(T)(Timeout!(T) t)
{	t.running = false;
}
/// ditto
alias clearTimeout clearInterval;


/*
 * Helper class for setTimeout. */
private class Timeout(T) : Thread
{	float delay;
	T func;
	ParameterTupleOf!(T) func_args;
	bool running = true;
	bool repeating = false;

	this(float delay, T func, ParameterTupleOf!(T) func_args)
	{	this.delay = delay;
		this.func = func;
		static if (func_args.length)
			foreach(int i, arg; func_args) // straight assignment fails in dmd.
				this.func_args[i] = func_args[i];
		super(&run);
	}
	
	void run()
	{	do {
			Thread.sleep(delay);
			if (running)
				func(func_args);
		} while (repeating);
		return 1;
	}
}