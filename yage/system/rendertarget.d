/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.system.rendertarget;

/**
 * Anything that implements this can act as a target for anything that
 * renders using OpenGL operations. */
interface IRenderTarget
{
	void bind();
	void unbind();	
}