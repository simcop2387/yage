/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.resource.exceptions;

import yage.core.exceptions;
import yage.core.parse;

///
class ResourceException : YageException
{	this(...)
	{	super(swritefRelay(_arguments, _argptr));
	}	
}
