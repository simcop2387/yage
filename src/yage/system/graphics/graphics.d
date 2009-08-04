/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 * 
 * This is a work-in-progress wrapper around OpenGL which adds the following features:
 * <ul>
 * <li>Transparently creates separate virtual contexts for each calling thread thread.</li>
 * <li>Checks errors and throws exceptions</li>
 * <li>Aggregates operations instead of performing them instantly.</li>
 * <li>Allows easily pushing and popping the entire state.</li>
 * <li>"Infinite" stack depth (matrices, etc.)</li>
 * <li>Allows easily swapping out OpenGL for another graphics system, if ever needed.</li>
 * </ul>
 */
module yage.system.graphics.graphics;

import std.stdio;
import tango.io.Stdout;
import tango.core.Thread;
import tango.stdc.stringz;
import tango.text.convert.Format;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;
import yage.core.object2;
import yage.core.math.all;



/**
 * This represents a current OpenGL state that can be pushed or popped. */
struct GLState
{
	Matrix matrix;	
	Matrix matrixStack[];
	
	enum DepthFunc
	{
		LEQUAL
	}
	
	static GLState opCall()
	{	GLState result;
		result.matrix = Matrix();
		return result;		
	}
	
	struct ClearColor
	{	public float r;
		public float g;
		public float b;
		public float a;		
	}
	ClearColor clearColor;
}

/**
 * Wrapper around all graphics operations.
 * Functions:
 * Automaticaly creates separate virtual contexts for each thread.
 * Allows easily swapping out OpenGL for another graphics system, if ever needed
 * Checks errors and throws exceptions
 * Aggregates operations instead of performing them instantly.
 * Allows easily pushing and popping the entire state.
 * "Infinite" stack depth (matrices, etc.)
 *  */
class Graphics
{
	GLState state;
	GLState[] states;
	
	private static Object openGLMutex;
	private static Object contextMutex;
	private static Graphics[Thread] contexts; // immutable
	
	static this()
	{	contextMutex = new Object();
		openGLMutex = new Object();
	}
	
	this()
	{	state = GLState();
	}

	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glPushMatrix.xml
	static void pushMatrix()
	{	st.matrixStack ~= Graphics.getContext().state.matrix;
	}
	unittest
	{	int l = st.matrixStack.length;
		pushMatrix();
		popMatrix();
		assert (l==st.matrixStack.length);
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glPopMatrix.xml
	static void popMatrix()
	{	assert(st.matrixStack.length);
		st.matrix = st.matrixStack[$-1];
		st.matrixStack.length = st.matrixStack.length-1;
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glRotate.xml
	static void rotate(float angle, float x, float y, float z)
	{	st.matrix = st.matrix.rotate(Vec3f(angle, x, y, z));
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glTranslate.xml
	static void translate(float x, float y, float z)
	{	st.matrix.v[12] += x;
		st.matrix.v[13] += y;
		st.matrix.v[14] += z;
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glScale.xml
	static void scale(float x, float y, float z)
	{	st.matrix.v[0] *= x;
		st.matrix.v[5] *= y;
		st.matrix.v[9] *= z;
	}
	
	
	
	
	
	// Internal functions:
	
		
	// Get the context for the current thread.
	private static Graphics getContext()
	{	
		Thread thread = Thread.getThis();
		if (!(thread in contexts))
		{			
			// Add to a copy of contexts to preserve immutability (and keep things thread safe)
			synchronized(contextMutex) // would ReadWriteMutex work better?
			{	scope newContexts = contexts; // TODO: need to .dup
				newContexts[thread] = new Graphics();
				contexts = newContexts; // array assignment isn't atomic?
				contexts.rehash;
		}	}
	
		return contexts[thread];
	}
	unittest
	{	assert(getContext() == getContext());
	}
	
	/*
	 * Shortcut for getting the state for the current virtual context. */
	private static GLState* st()
	{	return &getContext().state;
	}
	unittest
	{	assert(st == st);
	}
	
	/**
	 * Apply the current OpenGL state
	 * Returns: the number of necessary OpenGL calls. */
	public static int applyState()
	{	int calls;
		GLState def = GLState();
		synchronized (openGLMutex)
		{	if (st.matrix != def.matrix)
			{	glLoadMatrixf(cast(float*)st.matrix.ptr);
				checkError();
			}
		}
		return calls;
	}
	
	private static void checkError()
	{	int err = glGetError();
		if (err != GL_NO_ERROR)
			throw new GraphicsException(fromStringz(cast(char*)gluErrorString(err)));
	}
}

///
class GraphicsException : YageException
{	this(char[] message, ...)
	{	super(Format.convert(_arguments, _argptr, message));
	}	
}