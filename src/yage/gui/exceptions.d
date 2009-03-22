/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.gui.exceptions;

import yage.core.object2;;
import tango.text.convert.Format;

///
class CSSException : YageException
{	this(char[] message, ...)
	{	super(Format.convert(_arguments, _argptr, message));
	}	
}
