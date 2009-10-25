/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */
module yage.gui.exceptions;

import yage.core.object2;
import yage.core.format;

///
class CSSException : YageException
{	this(...)
	{	super(swritefArgs(_arguments, _argptr));
	}	
}

///
class XHTMLException : YageException
{	this(...)
	{	super(swritefArgs(_arguments, _argptr));
	}	
}
