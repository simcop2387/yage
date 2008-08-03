/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.exception;

/// TODO: Move this outside of Resource.
class YageException : Exception
{	this(char[] message)
	{	super(message);
	}	
}

///
class ResourceException : YageException
{	this(char[] message)
	{	super(message);
	}	
}

///
class ResourceLoadException : ResourceException
{	this(char[] message)
	{	super(message);
	}	
}
