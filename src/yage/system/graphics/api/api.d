/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.graphics.api.api;

import yage.core.format;
import yage.core.object2;
import yage.resource.texture;
import yage.resource.layer;
import yage.resource.shader;
import yage.system.graphics.api.opengl;

/**
 * Base class of all Graphics API wrappers
 * TODO: Add more functions to this class. */
class GraphicsAPI
{
	/// Track the currently bound resource to minimize state changes.
	protected struct Current
	{	static CameraNode camera; ///
		static IRenderTarget renderTarget; ///
		static Shader shader; ///
		static Texture texture; ///
		static Layer layer; ///
	}
	Current current; /// ditto

}

/**
 * Exception thrown on an error in the graphics system.. */
class GraphicsException : YageException
{	///
	this(...)
	{	super(swritef(_arguments, _argptr));
	}	
}