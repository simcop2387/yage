/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.gui.exceptions;

import yage.core.exceptions;
import yage.core.parse;

///
class CSSException : YageException
{	this(...)
	{	super(formatString(_arguments, _argptr));
	}	
}
