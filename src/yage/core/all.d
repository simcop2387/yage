/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 *
 * Import every module in the yage.core package.
 *
 * The core package is somewhat of a standard library for Yage.  It includes
 * 3D math classes, array handling functions, xml parsing, and other miscellanous
 * functionality.  It has no external dependencies.
 */

module yage.core.all;

public
{	import yage.core.math.all;
	import yage.core.array;
	import yage.core.cache;
	import yage.core.color;
	import yage.core.memory;
	import yage.core.misc;
	import yage.core.object2;
	import yage.core.parallel;
	import yage.core.repeater;
	import yage.core.timer;
	import yage.core.tree;
	import yage.core.types;
}