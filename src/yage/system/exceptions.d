/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.system.exceptions;

import std.bind;
import yage.core.parse;


class YageException : Exception
{	this(...)
	{	super(formatString(_arguments, _argptr));
	}	
}

///
class ResourceException : YageException
{	this(...)
	{	super(formatString(_arguments, _argptr));
	}	
}

///
class ResourceLoadException : ResourceException
{	this(...)
	{	super(formatString(_arguments, _argptr));
	}	
}