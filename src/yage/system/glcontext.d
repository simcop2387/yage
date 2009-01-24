/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel, Joe Pusderis (deformative0@gmail.com)
 * License:    <a href="lgpl.txt">LGPL</a>
 * 
 * This is an experiment toward a wrapper around OpenGL's state manager, or perhaps eventually all of OpenGL. 
 */
module yage.system.glcontext;


import tango.core.Thread;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.exceptions;

/**
 * This represents a current OpenGL state that can be pushed or popped.
 */
struct GLState
{
	
	enum DepthFunc
	{
		LEQUAL
	}
	
	static GLState opCall()
	{	GLState result;
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
 * Wrapping all of OpenGL's functionality as I'm doing here would take 1000's of LoC.
 * I need to find a way to do this more quickly using templates.
 */
class GLContext
{
	GLState[] states;
	GLState state;
	GLState applied_state;
	
	Object opengl_mutex;
	
	Thread self_thread;
	
	this()
	{	self_thread = Thread.getThis();
		opengl_mutex = new Object();
	}

	
	void clearColor(float r, float g, float b, float a)
	{	state.clearColor.r = r;
		state.clearColor.g = g;
		state.clearColor.b = b;
		state.clearColor.a = a;
	}
	
	/**
	 * Apply the current virtual OpenGL state to the real OpenGL state. 
	 * Returns: The number of OpenGL state changes that were required to apply the state.*/
	protected int apply()
	{	int func_calls = 0;
		
		synchronized (opengl_mutex)
		{	int error = glGetError(); // clear error state
			
			// Set the clearColor
			if (state.clearColor != applied_state.clearColor)
			{	glGetError();
				glClearColor(state.clearColor.r, state.clearColor.g, state.clearColor.b, state.clearColor.a);
				error = glGetError();
				if (error)
					throw new YageException("glClearColor error %d", error);
				
				applied_state.clearColor = state.clearColor;
				func_calls++;
			}
		}
		
		return func_calls;
	}
	
	/**
	 * Execute the following OpenGL code in an asynchronous-safe way.
	 * This can be called from any thread
	 * Params:
	 *     code =
	 */
	void execute(void delegate() code)
	{	synchronized (opengl_mutex)
			code();
	}
	
	
	void push(GLState new_state=state)
	{	states ~= state;
	}
	
	/**
	 * If this is called from an empty stack, then the state will be set to the default OpenGL state.
	 * Returns:
	 */
	GLState pop()
	{	GLState result = state;
		
		if (states.length)
		{	states.length = states.length -1;
			state = states[length];
		} else
		{	state = GLState();			
		}
		return result;
	}
}
