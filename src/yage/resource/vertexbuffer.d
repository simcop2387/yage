/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.resource.vertexbuffer;

import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.closure;
import yage.core.interfaces;
import yage.resource.resource;
import yage.resource.lazyresource;
import yage.system.device;
import yage.system.probe;

/**
 * A VertexBuffer stores the parameters of an OpenGL Vertex Buffer Object */
class VertexBuffer : Resource, IExternalResource
{
	/// A vertex or tirangle array, see derelict.opengl.extension.arb.vertex_buffer_object
	enum Type
	{   GL_ARRAY_BUFFER_ARB         = 0x8892,
	    GL_ELEMENT_ARRAY_BUFFER_ARB = 0x8893
	}
	
	protected Type type;
	protected void[] data;
	protected uint id;
	
	this()
	{	create();		
	}
	
	/**
	 * Create or update the vertex buffer object with data.
	 * Params:
	 *     type = A vertex or triangle array
	 *     data = The raw vertex data */
	void create(Type type, void[] data=[], bool just_create=false)
	{	
		this.type = type;
		this.data = data;
		
		if (Probe.openGL(Probe.OpenGL.VBO))
		{	if (!Device.isDeviceThread())
			{	LazyResourceManager.addToQueue(closure(&this.create, type, data));
			} else
			{	if (!id)
					glGenBuffersARB(1, &id);
				if (!just_create)
				{	glBindBufferARB(type, id);
					glBufferDataARB(type, data.length, data.ptr, GL_STATIC_DRAW_ARB);
					glBindBufferARB(type, 0);
				}
			}
		}
	}
	/// ditto
	void create()
	{	create(Type.GL_ARRAY_BUFFER_ARB, [], true);
	}
	
	/**
	 * Free the vbo.
	 * Create can be called again if necessary. */
	void destroy()
	{	if (id)
			if (!Device.isDeviceThread())
			{	LazyResourceManager.addToQueue(closure(&this.destroy));			
			} else
			{	glDeleteBuffersARB(1, &id);
				id = 0;
			}
	}
	
	/**
	 * Get the OpenGL id of the vertex buffer, or 0 if it hasn't yet been allocated.
	 * Returns:
	 */
	uint getId()
	{	return id;
	}	
}