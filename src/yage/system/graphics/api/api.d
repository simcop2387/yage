module yage.system.graphics.api.api;

import yage.core.format;
import yage.core.object2;
import yage.resource.texture;
import yage.resource.layer;
import yage.system.graphics.api.opengl;

/**
 * Base class of all Graphics API wrappers
 * TODO: Add more functions to this class. */
class GraphicsAPI
{
	protected struct Current
	{	static CameraNode camera;
		static IRenderTarget renderTarget;
		static Texture texture;
		static Layer layer;
	}
	Current current;

}

/**
 * Exception thrown on glError. */
class GraphicsException : YageException
{	///
	this(...)
	{	super(swritef(_arguments, _argptr));
	}	
}