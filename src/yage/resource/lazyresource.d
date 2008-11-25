/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.lazyresource;

import yage.system.probe;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.array;
import yage.core.exceptions;

/**
 * This class manages lazy resources.
 * A lazy resource is not bound when it is created, but rather the next time rendering calls are started by the rendering thread.
 * This is required since OpenGL is a state machine and can't receive simultaneous calls from multiple threads.
 * 
 * VertexBuffer
 * Texture
 * Shader
 * Sound - No, because each scene should have its own alContext.
 */
class LazyResourceManager
{
	protected static LazyVBO*[] vbo_queue;
	
	/**
	 * Process the queues. */
	public static void apply()
	{	
		foreach_reverse (i, vbo; vbo_queue)
		{	
			// what happens if vbo becomes an invalid pointer?
			if (vbo.data)					
			{	if (!vbo.id)
					glGenBuffersARB(1, &vbo.id);
				glBindBufferARB(vbo.type, vbo.id);
				glBufferDataARB(vbo.type, vbo.data.length*float.sizeof, vbo.data.ptr, GL_STATIC_DRAW_ARB);
				glBindBufferARB(vbo.type, 0);				
			}
			else
			{	if (vbo.id)
				{	glDeleteBuffersARB(1, &vbo.id);
					vbo.id = 0;
			}	}
		
			vbo_queue.length = vbo_queue.length - 1;
		}
	}
}

struct LazyVBO
{
	// From derelict.opengl.extension.arb.vertex_buffer_object
	enum Type
	{   GL_ARRAY_BUFFER_ARB                            = 0x8892,
	    GL_ELEMENT_ARRAY_BUFFER_ARB                    = 0x8893
	}
	
	Type type;
	float[] data;
	uint id;
	
	/**
	 * Create or update the vertex buffer object with data.
	 * Params:
	 *     type = 
	 *     data =
	 */
	void create(Type type, float[] data)
	{	this.type = type;
		this.data = data;
		if (Probe.openGL(Probe.OpenGL.VBO))
			LazyResourceManager.vbo_queue ~= this;
	}
	
	/**
	 * Free the vbo.
	 * Create can be called again if necessary. */
	void destroy()
	{	if (id)
			LazyResourceManager.vbo_queue ~= this;
	}
	
	uint getId()
	{	//if (!data.length)
		//	throw new YageException("LazyVBO must have create() called before getId()");
		//if (!id)
		//	throw new YageException("LazyVBO cannot be used until it is ready.");
		return id;
	}	
}

/// TODO
struct lazyTexture
{
}

/// TODO
struct lazyShader
{
}