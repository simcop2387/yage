/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 *
 * Import every module in the resource package.
 *
 * A ResourceManager is anything commonly loaded once and referenced
 * many times.  Examples include, 3D models, sounds, shaders, and textures.
 * See the other resource modules for more details.
 */

module yage.resource.all;

public
{	import yage.resource.graphics.all;
	import yage.resource.collada;
	import yage.resource.font;
	import yage.resource.image;
	import yage.resource.manager;
	import yage.resource.model;
	import yage.resource.sound;
}
