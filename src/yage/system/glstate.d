/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel, Joe Pusderis (deformative0@gmail.com)
 * License:    <a href="lgpl.txt">LGPL</a>
 * 
 * This is an experiment toward a wrapper around OpenGL's state manager, or perhaps eventually all of OpenGL. 
 */
module yage.system.glstate;


import std.thread;
import derelict.opengl.gl;
import derelict.opengl.glext;

/**
 * This represents a current OpenGL state that can be pushed or popped.
 */
struct GLState
{
	
	enum DepthFunc
	{
		LEQUAL
	}
	
	public struct ClearColor
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
	
	Thread self_thread;
	
	this()
	{	self_thread = Thread.getThis();		
	}
	
	invariant
	{	assert(self_thread == Thread.getThis());		
	}
	
	void clearColor(float r, float g, float b, float a)
	{	state.clearColor.r = r;
		state.clearColor.g = g;
		state.clearColor.b = b;
		state.clearColor.a = a;
	}
	
	
	int apply()
	{	int func_calls = 0;
		
		if (state.clearColor != applied_state.clearColor)
		{	glClearColor(state.clearColor.r, state.clearColor.g, state.clearColor.b, state.clearColor.a);
			applied_state.clearColor = state.clearColor;
			func_calls++;
		}
		
		return func_calls;
	}
	
	void push()
	{	states ~= state;
	}
	
	void pop()
	{	state = states[length-1];
		states.length = states.length -1;
	}
}
