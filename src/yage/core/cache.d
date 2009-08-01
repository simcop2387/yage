/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a> 
 */
module yage.core.cache;

import tango.text.Regex;

/**
 * This class caches expensive structures (calculating them when they're first needed) 
 * so they don't have to be regenerated. */
class Cache
{
	static Regex[string] regexes;
	
	
	///
	static Regex getRegex(char[] exp)
	{	synchronized(Cache.classinfo)
		{	if (exp in regexes)
				return regexes[exp];
			else return regexes[exp] = Regex(exp);
		}
	}
	
	
	
	
	
	
	
}