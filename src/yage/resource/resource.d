/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.resource;

import yage.core.object2;

abstract class Resource : YageObject, IFinalizable
{
	override void finalize()
	{		
	}
}