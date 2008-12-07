/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.lazyresource;

import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.closure;
import yage.core.array;
import yage.core.exceptions;
import yage.core.interfaces;
import yage.system.device;
import yage.system.probe;
import yage.resource.texture;


struct LazyResourceOp
{	IExternalResource resource;
	void delegate() op;
}

/**
 * This class manages lazy resources.
 * A lazy resource is not bound when it is created, but rather the next time rendering calls are started by the rendering thread.
 * This is required since OpenGL is a state machine and can't receive simultaneous calls from multiple threads.
 * 
 * These do or may end up using LazyResoureManager
 * VertexBuffer
 * Texture
 * Shader
 * Sound - No, because each scene should have its own alContext?
 */
class LazyResourceManager
{
	protected static LazyVBO*[] vbo_queue; // array of pointers since LazyVBO is a struct.
	//protected static IExternalResource[] queue;
	
	protected static Closure[] queue;
	protected static Object queue_mutex;
	
	static this()
	{	queue_mutex = new Object();		
	}
	
	/**
	 * Process the queues. */
	static void processQueue()
	in {
		assert(Device.isDeviceThread());
	}
	body
	{	
		// Vertex buffers
		foreach_reverse (i, vbo; vbo_queue)
		{	
			// what happens if vbo becomes an invalid pointer?
			if (vbo.data)					
			{	if (!vbo.id)
					glGenBuffersARB(1, &vbo.id);
				glBindBufferARB(vbo.type, vbo.id);
				glBufferDataARB(vbo.type, vbo.data.length, vbo.data.ptr, GL_STATIC_DRAW_ARB);
				glBindBufferARB(vbo.type, 0);
			}
			else
			{	if (vbo.id)
				{	glDeleteBuffersARB(1, &vbo.id);
					vbo.id = 0;
			}	}
		
			vbo_queue.length = vbo_queue.length - 1;
		}
		synchronized(queue_mutex)
		{	if (queue.length)
				std.stdio.writefln("processing closure queue of length %d", queue.length);
			foreach(i, func; queue)
				func.call();			
			queue.length = 0;
		}
	}
	
	static void addToQueue(Closure c)
	{	 synchronized(queue_mutex) queue ~= c;
	}
	
	static void addToQueue(LazyVBO *v)
	{	vbo_queue ~= v;		
	}
	
	
}

/**
 * A LazyVBO stores the parameters of an OpenGL Vertex Buffer Object 
 * until the rendering thread is ready to initialize it. */
struct LazyVBO
{
	/// A vertex or tirangle array, see derelict.opengl.extension.arb.vertex_buffer_object
	enum Type
	{   GL_ARRAY_BUFFER_ARB         = 0x8892,
	    GL_ELEMENT_ARRAY_BUFFER_ARB = 0x8893
	}
	
	protected Type type;
	protected void[] data;
	protected uint id;
	
	/**
	 * Create or update the vertex buffer object with data.
	 * Params:
	 *     type = A vertex or triangle array
	 *     data = The raw vertex data */
	void create(Type type, void[] data)
	{	this.type = type;
		this.data = data;
		if (Probe.openGL(Probe.OpenGL.VBO))
			LazyResourceManager.addToQueue(this);
	}
	
	/**
	 * Free the vbo.
	 * Create can be called again if necessary. */
	void destroy()
	{	if (id)
			LazyResourceManager.addToQueue(this);
	}
	
	/**
	 * Get the OpenGL id of the vertex buffer, or 0 if it hasn't yet been allocated.
	 * Returns:
	 */
	uint getId()
	{	return id;
	}	
}

/// TODO
struct lazyTexture
{	
	
	uint id;
	
}

/// TODO
struct lazyShader
{
}