/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.graphics.api.api;

import yage.core.format;
import yage.core.object2;
import yage.resource.texture;
import yage.resource.material;
import yage.resource.shader;
import yage.scene.scene;
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
		static Scene scene; ///
		static Shader shader; ///
		static Texture texture; ///
		
		static MaterialPass pass; ///
	}
	Current current; /// ditto
	
	static MaterialPass defaultPass;

}

/**
 * Exception thrown on an error in the graphics system.. */
class GraphicsException : YageException
{	///
	this(...)
	{	super(format(_arguments, _argptr));
	}	
}