/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.graphics.api;

import yage.core.array;
import yage.core.format;
import yage.core.object2;
import yage.core.math.matrix;
import yage.resource.geometry;
import yage.resource.texture;
import yage.resource.material;
import yage.resource.shader;
import yage.scene.scene;
import yage.scene.light;
import yage.system.graphics.opengl;

/**
 * Base class of all Graphics API wrappers
 * TODO: Add more functions to this class. */
abstract class GraphicsAPI
{
	/// Track the currently bound resource to minimize state changes.
	protected struct Current
	{	
		static CameraNode camera; ///
		static IRenderTarget renderTarget; ///
		static Scene scene; ///
		static Shader shader; ///
		static VertexBuffer[char[]] vertexBuffers; ///
		static LightNode[8] lights;	///
		static MaterialPass pass; ///
		static ArrayBuilder!(TextureInstance) textures;

		static Current opCall()
		{	Current result;
			LightNode light = new LightNode();
			for (int i=0; i<lights.length; i++)
				lights[i] = light;
			return result;
		}
	}
	Current current; /// ditto
	
	static MaterialPass defaultPass;
	
	this()
	{	current = Current();
		defaultPass = new MaterialPass();
	}
}

/**
 * Exception thrown on an error in the graphics system.. */
class GraphicsException : YageException
{	///
	this(...)
	{	super(format(_arguments, _argptr));
	}	
}