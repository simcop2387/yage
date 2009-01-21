/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.gui.exceptions;

import yage.core.exceptions;
import yage.core.parse;

///
class CSSException : YageException
{	this(...)
	{	super(swritefRelay(_arguments, _argptr));
	}	
}
