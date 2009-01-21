/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.core.exceptions;

import yage.core.exceptions;
import yage.core.parse;

/**
 * This is the default exception type for Yage. */
class YageException : Exception
{	
	/**
	 * Create an Exception with a message, using formatting like writefln(). 
	 * Example:
	 * --------
	 * throw new YageException("Your egg carton has %d eggs.  No more than %d eggs are supported", 13, 12);
	 * -------- 
	 */
	this(...)
	{	super(swritefRelay(_arguments, _argptr));
	}	
}

///
class OpenALException : YageException
{
	///
	this(...)
	{	super(swritefRelay(_arguments, _argptr));
	}
}

///
class ResourceManagerException : YageException
{	
	///
	this(...)
	{	super(swritefRelay(_arguments, _argptr));
	}	
}
