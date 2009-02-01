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
import yage.system.glcontext;

interface IVertexBuffer : IFinalizable
{
	enum Type
	{	VERTICES,
		NORMALS,
		TEXCOORDS0,
		TRIANGLE_INDICES
	}
	
	int length();
	void length(int);

	uint getId();
	void setId(uint);

	void[] getData();
	//void setData(void[]);
	//void[] opCast();

	bool getDirty();
	void setDirty(bool);
	
	int getSizeInBytes();

	void* ptr();

	float itemLength2(int);
	byte getWidth();

	static void finalizeAll();
}

/**
 * A VertexBuffer stores the parameters of an OpenGL Vertex Buffer Object
 * TODO: Would it make sense to implement several array operations
 * and then have an update function to synchronize? */
class VertexBuffer(T) : IVertexBuffer
{
	protected T[] data;
	package uint id;
	protected bool dirty = true;;

	static const byte width = T.width;

	static protected uint[uint] current_ids;

	/**
	 * Free the vbo.
	 * Create can be called again if necessary. */
	~this()
	{	finalize();
	}
	void finalize() /// ditto
	{	if (id)
			if (!System.isSystemThread())
			{	LazyResourceManager.addToQueue(closure(&this.finalize));
			} else
			{	current_ids.remove(id);
				glDeleteBuffersARB(1, &id);
				id = 0;
			}
	}

	void[] getData()
	{	return data;
	}
	void setData(T[] data)
	{	dirty = true;
		this.data = data;
	}

	bool getDirty()
	{	return dirty;
	}
	void setDirty(bool dirty)
	{	this.dirty = dirty;
	}

	/**
	 * Get/set the OpenGL id of the vertex buffer, or 0 if it hasn't yet been allocated. */
	uint getId()
	{	return id;
	}
	void setId(uint id)
	{	this.id = id;
		if (id)
			current_ids[id] = id;
	}

	/// Implement array operations
	int length()
	{	return data.length;
	}
	void length(int l)
	{	data.length = l;
	}
	
	int getSizeInBytes()
	{	return length * T.sizeof;
	}
	
	void* ptr()
	{	return data.ptr;
	}

	static void finalizeAll()
	{	foreach (id; current_ids)
			glDeleteBuffersARB(1, &id);
	}

	// Hackish: used by Geometry for radius calculation
	float itemLength2(int index)
	{	return data[index].length2();
	}
	byte getWidth()
	{	return width;
	}
}