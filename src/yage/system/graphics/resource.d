/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.system.graphics.resource;

import tango.io.Stdout;
import tango.util.container.HashSet;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.system.graphics.probe;
import yage.system.graphics.context;

/**
 * This static class will manage all OpenGL specific resources, such as texture, vbo, and shader id's. */
class GraphicsResource
{
	private static HashSet!(uint) vbo_current;
	private static HashSet!(uint) vbo_reserve;
	
	protected static Object mutex;
	
	static this()
	{	mutex = new Object();
		vbo_current = new HashSet!(uint);
		vbo_reserve = new HashSet!(uint);
	}
	
	static uint getVBO()
	{	
		if (!Probe.openGL(Probe.OpenGL.VBO))
			return 0;

		synchronized(mutex)
		{
			// If the reserve is empty, replenish it.
			if (!vbo_reserve.size())
			{	std.gc.genCollect();
				if (!vbo_reserve.size())
					synchronized(GLContext.getInstance())
						for (int i=0; i<64; i++) // Generate 64 new vbo's
						{	uint id;
							glGenBuffersARB(1, &id);
							vbo_reserve.add(id);
			}			}
		
			// Get a vbo from the reserve
			uint id;
			vbo_reserve.take(id);
			vbo_current.add(id);				
			return id;
		}
	}
	static void freeVBO(uint id)
	{	if (id) // if it's 0, it was never created
			synchronized(mutex)
			{	vbo_current.remove(id);
				vbo_reserve.add(id);
			}
	}
	
	/**
	 * Release all resources, in use and in reserve.
	 * This basically resets this class to its starting state. */
	static void finalize()
	{	
		foreach (id; vbo_current) // for some reason iterating over this sometimes causes an exception.
			glDeleteBuffersARB(1, &id);
		vbo_current.reset();
		foreach (id; vbo_reserve)
			glDeleteBuffersARB(1, &id);
		vbo_reserve.reset();
	}
}