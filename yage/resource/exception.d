/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.exception;


///
class ResourceLoadException : Exception
{
	this(char[] message)
	{
		super(message);
	}
	
}
