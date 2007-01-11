/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * Import every module in the resource package.
 *
 * A Resource is anything commonly loaded once and referenced
 * many times.  Examples include, 3D models, sounds, shaders, and textures.
 * See the other resource modules for more details.
 */

module yage.resource.all;

public
{	import yage.resource.image;
	import yage.resource.material;
	import yage.resource.model;
	import yage.resource.resource;
	import yage.resource.shader;
	import yage.resource.sound;
	import yage.resource.texture;
}
