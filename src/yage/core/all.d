/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Either <a href="lgpl.txt">LGPL</a> or <a href="zlib-libpng.txt">zlib/libpng</a>
 *
 * Import every module in the core package.
 *
 * The core package is somewhat of a standard library for Yage.  It includes
 * 3D math classes, templated storage classes, and other miscellanous
 * functionality.  It has no external dependencies.
 *
 * Note that the core package carries the zlib/libpng license while every other
 * package is under the LGPL.
 */

module yage.core.all;

public
{	import yage.core.freelist;
	import yage.core.horde;
	import yage.core.matrix;
	import yage.core.misc;
	import yage.core.plane;
	import yage.core.quatrn;
	import yage.core.timer;
	import yage.core.tree;
	import yage.core.vector;
	import yage.core.xml;
}

