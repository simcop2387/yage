/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */
module yage.gui.exceptions;

import yage.core.object2;
import core.vararg;

///
class CSSException : YageException
{	this(...)
	{	super("CSS Exception"); // TODO make this actually use the vararg stuff
	}	
}

///
class XHTMLException : YageException
{	this(...)
	{	super("XHTML Exception"); // TODO make this actually use the vararg stuff
	}	
}
