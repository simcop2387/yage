/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.resource.vertexbuffer;

import std.stdio;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.closure;
import yage.core.interfaces;
import yage.core.parse;
import yage.resource.resource;
import yage.resource.lazyresource;
import yage.system.system;
import yage.system.probe;

/**
 * A VertexBuffer stores the parameters of an OpenGL Vertex Buffer Object */
struct VertexBuffer /*: Resource, IExternalResource*/
{
	/// A vertex or tirangle array, see derelict.opengl.extension.arb.vertex_buffer_object
	enum Type
	{   GL_ARRAY_BUFFER_ARB         = 0x8892,
	    GL_ELEMENT_ARRAY_BUFFER_ARB = 0x8893
	}
	
	protected Type type;
	protected void[] data;
	protected uint id;
	
	static protected VertexBuffer[VertexBuffer] all;

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
		{	if (!System.isSystemThread())
			{	LazyResourceManager.addToQueue(closure(&this.create, type, data, just_create));
			} else
			{	if (!id)
				{	glGenBuffersARB(1, &id);
					all[*this] = *this;
				}
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
	void finalize()
	{	if (id)
			if (!System.isSystemThread())
			{	LazyResourceManager.addToQueue(closure(&this.finalize));			
			} else
			{	glDeleteBuffersARB(1, &id);
				id = 0;
				all.remove(*this);
			}
	}

	
	/**
	 * Get the OpenGL id of the vertex buffer, or 0 if it hasn't yet been allocated. */
	uint getId()
	{	return id;
	}	

	///
	char[] toString()
	{	return swritef("<VertexBuffer dataBytes=\"%d\" id=\"%d\"/>", data.length, id);
	}
	
	/// Get a list of all VertexBuffers that have been created but not finalized. 
	static VertexBuffer[VertexBuffer] getAll()
	{	return all;
	}
}