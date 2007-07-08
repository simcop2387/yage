/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * Import every module in the core package.
 *
 * The core package is somewhat of a standard library for Yage.  It includes
 * 3D math classes, array handling functions, xml parsing, and other miscellanous
 * functionality.  It has no external dependencies.
 */

module yage.core.all;

public
{	import yage.core.array;
	import yage.core.freelist;
	import yage.core.matrix;
	import yage.core.misc;
	import yage.core.parse;
	import yage.core.plane;
	import yage.core.quatrn;
	import yage.core.repeater;
	import yage.core.timer;
	import yage.core.vector;
	import yage.core.xml;
}

