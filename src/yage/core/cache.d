/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a> 
 */
module yage.core.cache;

import tango.stdc.time : time;
import tango.text.Regex;
import tango.core.Traits;
import tango.core.Tuple;
import yage.system.log;

/**
 * This class caches expensive structures (calculating them when they're first needed) 
 * so they don't have to be regenerated. */
class RegexCache
{
	static Regex[string] regexes;
	
	///
	static Regex getRegex(char[] exp)
	{	synchronized(RegexCache.classinfo)
		{	if (exp in regexes)
				return regexes[exp];
			else return regexes[exp] = Regex(exp);
		}
	}	
}

/**
 * Wrap a function so that when it's called more than once with the same arguments,
 * subsequent results are returned from a cache.
 * 
 * Limitations:
 * The function must be pure (obviously).
 * The function used must either be a top-level function or a static nested function 
 * that doesn't reference any local variables.
 * 
 * Example:
 * --------
 * 
 * static bool foo(int a, float b) { return a>b; }
 * 
 * Cache!(foo) fooCached;
 * 
 * fooCached(1, 3.5f); // body of foo is executed
 * fooCached(1, 3.5f); // body of foo is not executed, previous result returned.
 */
struct Cache(alias func)
{	alias typeof(&func) T;
	alias ParameterTupleOf!(T) Key;
	alias ReturnTypeOf!(T) Value;
	
	// Can't use a Tuple as an AA key, so we make a struct
	struct X(T...) { T members; }
	alias X!(Key) KeyStruct;
	
	private struct ResultInfo
	{	Value value;
		int age;
	}	
	private ResultInfo[KeyStruct] cache;
	

	Value opCall(Key key)
	{	
		KeyStruct keyStruct; // convert tuple to struct to use as an AA key
		keyStruct.members = key;
		
		// Result is cached, return it
		auto ptr = keyStruct in cache;
		if (ptr)
			return (*ptr).value;
		
		// Recalculate result
		ResultInfo result;
		result.value = func(key);
		result.age = tango.stdc.time.time(null);
		cache[keyStruct] = result;
		return result.value;
	}
	
	void clear(int age)
	{	int now = tango.stdc.time.time(null);
		foreach (key, value; cache)
			if (value.age < now - age)
				cache.remove(key);
	}
}

unittest
{	int count = 0;
	static int getLength(char[] input, char[] input2=null)
	{	return input.length + input2.length; 
	}
	
	Cache!(getLength) cache;
	
	assert(cache("hello", "goodbye") == 12);
	assert(cache("hello", "goodbye") == 12);
}
