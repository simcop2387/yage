/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 * 
 * This is a work-in-progress wrapper around  a systems-level graphics API 
 * (Currently only OpenGL) which adds the following features:
 * <ul>
 * <li>Transparently creates separate virtual contexts for each calling thread.</li>
 * <li>Checks errors and throws exceptions</li>
 * <li>Aggregates operations instead of performing them instantly.</li>
 * <li>Allows easily pushing and popping the entire state.</li>
 * <li>"Infinite" stack depth (matrices, etc.)</li>
 * <li>Allows easily swapping out OpenGL for another graphics system, if ever needed.</li>
 * </ul>
 * For ease of implementation, only calls and states that are used by Yage are wrapped.
 * For ease of use, function and parameter names are very similar to OpenGL.  See: http://opengl.org/sdk/docs/man
 */
module yage.system.graphics.graphics;

import std.stdio;
import tango.core.Thread;
import tango.math.IEEE;
import tango.stdc.stringz;
import tango.text.convert.Format;
import tango.util.container.HashMap;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;
import yage.core.array;
import yage.core.fastmap;
import yage.core.object2;
import yage.core.math.all;
import yage.core.timer;

/**
 * Use OpenGL for graphics API calls. 
 * This allows easily swapping out OpenGL for another graphics wrapper if ever needed. 
 * Example:
 * --------
 * Graphics.color([1, 1, 1, 1]); // is the same as:
 * OpenGL.color([1, 1, 1, 1]);
 * --------
 */
OpenGL Graphics()
{	return OpenGL.getContext();
}


// Used in OpenGL State for storing parameters
private struct Float4
{
	float[4] v;
	byte length=4;
	
	// Constructor
	static Float4 opCall(float a, float b=float.nan, float c=float.nan, float d=float.nan)
	{	Float4 result;
		result.v[0] = a;
		result.v[1] = b;
		result.v[2] = c;
		result.v[3] = d;
		for (int i=0; i<4; i++)
			if (isNaN(result.v[i]))
			{	result.length = i;
				break;				
			}
		return result;
	}
	unittest {
		assert(Float4(0).length==1);
		assert(Float4(0, 1, 2, 3).length==4);
	}
}


/*
 * This represents a current OpenGL state that can be pushed or popped. 
 * It is currently unfinished and has bugs. */
private struct OpenGLState
{
	union {
		struct {
			Matrix matrix;	
			Matrix textureMatrix;
			Matrix projectionMatrix;
		}
		Matrix[3] matrices;
	}
	
	union {
		struct {	
			Matrix[] matrixStack;
			Matrix[] textureMatrixStack;
			Matrix[] projectionMatrixStack;
		}
		Matrix[][3] matrixStacks;	
	}

	FastMap!(uint, bool) enable;		
	FastMap!(uint, bool) enableClientState; // used with glEnableClientSideState
	
	FastMap!(uint, Float4)[8] lights;

	float[][uint][uint] materials;
	int[uint][uint] texEnvi;
	//float[uint][uint] texEnvf;
	int[uint][uint] texParameteri;
	//float[uint][uint] texParameterf;
	uint[uint][uint] textures;
	
	
	struct AlphaFunc
	{	uint func = GL_ALWAYS;
		float value = 0;		
	}
	AlphaFunc alphaFunc;
	
	struct BlendFunc
	{	uint sfactor = GL_ONE;
		uint dfactor = GL_ZERO;
	}
	BlendFunc blendFunc;
	
	float[4] color = [1f, 1, 1, 1];
	uint cullFace = GL_BACK;	
	bool depthMask = true;
	
	float lineWidth = 1;
	float pointSize = 1;
	
	struct PolygonMode
	{	uint front = GL_FILL;
		uint back = GL_FILL;
	}
	PolygonMode polygonMode;

	// Constructor
	static OpenGLState opCall()
	{	OpenGLState result;
		result.matrix = Matrix();
		result.textureMatrix = Matrix();
		//result.projectionMatrix = Matrix();
		
		// Set enable options to their defaults.
		scope enableCaps = 
			[GL_ALPHA_TEST, GL_AUTO_NORMAL, GL_BLEND, GL_CLIP_PLANE0, GL_CLIP_PLANE1, GL_CLIP_PLANE2, GL_CLIP_PLANE3, 
			  GL_CLIP_PLANE4, GL_CLIP_PLANE5, GL_COLOR_LOGIC_OP, GL_COLOR_MATERIAL, GL_COLOR_SUM/*, GL_COLOR_TABLE, 
			 GL_CONVOLUTION_1D, GL_CONVOLUTION_2D*/, GL_CULL_FACE, GL_DEPTH_TEST, GL_FOG/*, GL_HISTOGRAM*/, 
			 GL_INDEX_LOGIC_OP, GL_LIGHT0, GL_LIGHT1, GL_LIGHT2, GL_LIGHT3, GL_LIGHT4, GL_LIGHT5, GL_LIGHT6, GL_LIGHT7, 
			 GL_LIGHTING, GL_LINE_SMOOTH, GL_LINE_STIPPLE, GL_MAP1_COLOR_4, GL_MAP1_INDEX, GL_MAP1_NORMAL, 
			 GL_MAP1_TEXTURE_COORD_1, GL_MAP1_TEXTURE_COORD_2, GL_MAP1_TEXTURE_COORD_3, GL_MAP1_TEXTURE_COORD_4, 
			 GL_MAP1_VERTEX_3, GL_MAP1_VERTEX_4, GL_MAP2_COLOR_4, GL_MAP2_INDEX, GL_MAP2_NORMAL, 
			 GL_MAP2_TEXTURE_COORD_1, GL_MAP2_TEXTURE_COORD_2, GL_MAP2_TEXTURE_COORD_3, GL_MAP2_TEXTURE_COORD_4, 
			 GL_MAP2_VERTEX_3, GL_MAP2_VERTEX_4/*, GL_MINMAX*/, GL_NORMALIZE, GL_POINT_SMOOTH, GL_POINT_SPRITE, 
			 GL_POLYGON_OFFSET_FILL, GL_POLYGON_OFFSET_LINE, GL_POLYGON_OFFSET_POINT, GL_POLYGON_SMOOTH, 
			 GL_POLYGON_STIPPLE/*, GL_POST_COLOR_MATRIX_COLOR_TABLE, GL_POST_CONVOLUTION_COLOR_TABLE*/, 
			 GL_RESCALE_NORMAL, GL_SAMPLE_ALPHA_TO_COVERAGE, GL_SAMPLE_ALPHA_TO_ONE, GL_SAMPLE_COVERAGE/*, 
			 GL_SEPARABLE_2D*/, GL_SCISSOR_TEST, GL_TEXTURE_1D, GL_TEXTURE_2D, GL_TEXTURE_3D, GL_TEXTURE_CUBE_MAP, 
			 GL_TEXTURE_GEN_Q, GL_TEXTURE_GEN_R, GL_TEXTURE_GEN_S, GL_TEXTURE_GEN_T, GL_VERTEX_PROGRAM_POINT_SIZE, 
			 GL_VERTEX_PROGRAM_TWO_SIDE];
		foreach (cap; enableCaps)
			result.enable[cap] = false;
		result.enable[GL_DITHER] = true;		
		result.enable[GL_MULTISAMPLE] = true;
		
		// Set light values to their defaults
		foreach (inout light; result.lights)
		{
			light[GL_AMBIENT]               = Float4(0, 0, 0, 1);
			light[GL_DIFFUSE]               = Float4(0, 0, 0, 1);
			light[GL_SPECULAR]              = Float4(0, 0, 0, 1);
			light[GL_POSITION]              = Float4(0, 0, 1, 0);
			light[GL_SPOT_DIRECTION]        = Float4(0, 0, -1);
			light[GL_SPOT_EXPONENT]         = Float4(0);
			light[GL_SPOT_CUTOFF]           = Float4(180);
			light[GL_CONSTANT_ATTENUATION]  = Float4(1);
			light[GL_LINEAR_ATTENUATION]    = Float4(0);
			light[GL_QUADRATIC_ATTENUATION] = Float4(0);
		}
	
			
		//result.enableClientState[GL_NORMAL_ARRAY] = false;
		
		result.textures[GL_TEXTURE_1D] = [0:0u, 1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0];
		result.textures[GL_TEXTURE_2D] = [0:0u, 1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0];
		result.textures[GL_TEXTURE_3D] = [0:0u, 1:0, 2:0, 3:0, 4:0, 5:0, 6:0, 7:0];
		result.textures.rehash;
		
		return result;		
	}
	
	/**
	 * Returns: A deep copy of this OpenGLState. */
	OpenGLState dup()
	{	OpenGLState result = *this;
		result.enable = enable.dup();
		result.enableClientState = result.enableClientState.dup();
		result.materials = .dup(result.materials, true);		
		result.texEnvi = .dup(result.texEnvi, true);
		result.texParameteri = .dup(result.texParameteri, true);
		result.textures = .dup(result.textures);
		result.lights[0..$] = result.lights.dup[0..$];
		
		for (int i=0; i<matrixStacks.length; i++)
			result.matrixStacks[i] = result.matrixStacks[i].dup;
		return result;
	}
	
	void rehash()
	{	materials.rehash;
		texEnvi.rehash;
		texParameteri.rehash;
		textures.rehash;
	}
}

/**
 * Wrapper around a systems-level graphics API (Currently only OpenGL) 
 * It is currently unfinished and has bugs.*/
class OpenGL
{
	OpenGLState state;			// current modified state
	OpenGLState appliedState;	// last state that was applied.
	OpenGLState[] states;		// stack of states
	
	static Object openGLMutex;
	static Object contextMutex;
	static OpenGL[Thread] contexts; // immutable, copied on write
	
	static this()
	{	contextMutex = new Object();
		openGLMutex = new Object();
	}
	
	/// Construct and create an initial state on the state stack.
	private this()
	{	state = OpenGLState();
		appliedState = state.dup();
	}

	/// See: http://opengl.org/sdk/docs/man/xhtml/glAlphaFunc.xml
	void alphaFunc(uint func, float value)
	{	state.alphaFunc.func = func;
		state.alphaFunc.value = value;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glBindBuffer.xml
	void bindBuffer(uint target, uint buffer)
	{	synchronized (openGLMutex)
		{	glBindBufferARB(target, buffer);
			checkError();
		}
	}

	/// See: http://opengl.org/sdk/docs/man/xhtml/glBindTexture.xml, http://opengl.org/sdk/docs/man/xhtml/glActiveTexture.xml
	/// TODO: textureUnit
	void bindTexture(uint target, uint texture, uint textureUnit=GL_TEXTURE0_ARB)
	{	OpenGL context = getContext();
		OpenGLState* st = &context.state;
		OpenGLState* appliedState = &context.appliedState;
		
		if (!keysExist(appliedState.textures, target, textureUnit) || appliedState.textures[target][textureUnit] != texture)
		{	applyState();
			st.textures[target][textureUnit] = texture;
			synchronized (openGLMutex) glBindTexture(target, texture);
			checkError();
		}
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glBlendFunc.xml
	void blendFunc(uint sfactor, uint dfactor)
	{	state.blendFunc.sfactor = sfactor;
		state.blendFunc.dfactor = dfactor;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glBufferData.xml
	void bufferData(uint target, void[] data, uint usage=GL_STATIC_DRAW_ARB)
	{	synchronized (openGLMutex)
		{	glBufferDataARB(target, data.length, data.ptr, usage);
			checkError();
		}
	}

	/// See: http://opengl.org/sdk/docs/man/xhtml/glClear.xml
	void clear(uint mask)
	{
		applyState(); /// TODO: only need to apply the color state.
		synchronized (openGLMutex)
		{	glClear(mask);
			checkError();
		}
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glColor.xml
	void color(float[] value)
	{	int l = value.length > 4 ? 4 : value.length;
		state.color[0..l] = value[0..l];		
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glCullFace.xml
	void cullFace(uint mode)
	{	state.cullFace = mode;		
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glDeleteBuffers.xml
	void deleteBuffer(uint buffer)
	{	synchronized (openGLMutex)
		{	glDeleteBuffersARB(1, &buffer);
			checkError();
		}
	}

	/// See: http://opengl.org/sdk/docs/man/xhtml/glDeleteTextures.xml
	void deleteTexture(uint texture)
	{	synchronized (openGLMutex)
		{	glDeleteTextures(1, &texture);
			checkError();
		}
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glDepthMask.xml
	void depthMask(bool flag)
	{	state.depthMask = flag;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glDisable.xml
	void disable(uint cap)
	{	state.enable[cap] = false;		
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glDisableClientState.xml
	void disableClientState(uint cap)
	{	state.enableClientState[cap] = false;		
	}
		
	/// See: http://opengl.org/sdk/docs/man/xhtml/glEnable.xml
	void enable(uint cap)
	{	state.enable[cap] = true;		
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glEnableClientState.xml
	void enableClientState(uint cap)
	{	state.enableClientState[cap] = true;		
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glGenBuffers.xml
	uint genBuffer()
	{	uint buffer;
		synchronized (openGLMutex)
		{	glGenBuffersARB(1, &buffer);
			checkError();
		}
		return buffer;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glGenTextures.xml
	uint genTexture()
	{	uint buffer;
		synchronized (openGLMutex)
		{	glGenTextures(1, &buffer);
			checkError();
		}
		return buffer;
	}
	
	// broken
	void light(ubyte light, uint pname, float param)
	{	state.lights[light][pname] = Float4(param);
		assert(state.lights[light][pname].v[0] == param);
	}
	void light(ubyte light, uint pname, float[] param)
	{	state.lights[light][pname].v[0..$] = param[0..$];
	}
		
	/// See: http://opengl.org/sdk/docs/man/xhtml/glLineWidth.xml
	void lineWidth(float width)
	{	state.lineWidth = width;		
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glLoadIdentity.xml
	void loadIdentity()
	{	state.matrix = Matrix();
	}
	void loadTextureIdentity() /// ditto
	{	state.textureMatrix = Matrix();
	}
	void loadProjectionIdentity() /// ditto
	{	state.projectionMatrix = Matrix();
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glLoadMatrix.xml
	void loadMatrix(Matrix m)
	{	state.matrix = m;
	}
	void loadTextureMatrix(Matrix m) /// ditto
	{	state.textureMatrix = m;		
	}
	void loadProjectionMatrix(Matrix m) /// ditto
	{	state.projectionMatrix = m;		
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glMaterial.xml
	void material(uint face, uint pname, float[] param)
	{	state.materials[face][pname] = param;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glMultMatrix.xml
	void multMatrix(Matrix m)
	{	state.matrix *= m;
	}
	void multTextureMatrix(Matrix m) /// ditto
	{	state.textureMatrix *= m;		
	}
	void multProjectionMatrix(Matrix m) /// ditto
	{	state.projectionMatrix *= m;		
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glOrtho.xml
	void ortho(float left, float right, float bottom, float top, float near, float far)
	{	state.projectionMatrix = state.projectionMatrix * Matrix(left, right, bottom, top, near, far);		
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glPointSize.xml
	void pointSize(float size)
	{	state.pointSize = size;		
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glPolygonMode.xml
	void polygonMode(uint face, uint mode)
	{	if (face==GL_FRONT || face==GL_FRONT_AND_BACK)
			state.polygonMode.front = mode;
		else if (face==GL_BACK || face==GL_FRONT_AND_BACK)
			state.polygonMode.back = mode;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glPopMatrix.xml
	void popMatrix()
	{	assert(state.matrixStack.length);
		state.matrix = state.matrixStack[$-1];
		state.matrixStack.length = state.matrixStack.length-1;
	}
	void popTextureMatrix() /// ditto
	{	assert(state.textureMatrixStack.length);
		state.textureMatrix = state.textureMatrixStack[$-1];
		state.textureMatrixStack.length = state.textureMatrixStack.length-1;
	}
	void popProjectionMatrix() /// ditto
	{	assert(state.projectionMatrixStack.length);
		state.projectionMatrix = state.textureMatrixStack[$-1];
		state.projectionMatrixStack.length = state.textureMatrixStack.length-1;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glPushMatrix.xml
	void pushMatrix()
	{	state.matrixStack ~= state.matrix;
	}
	void pushTextureMatrix() /// ditto
	{	state.textureMatrixStack ~= state.textureMatrix;
	}
	void pushProjectionMatrix() /// ditto
	{	state.projectionMatrixStack ~= state.projectionMatrix;
	}
	unittest
	{	OpenGL context = OpenGL.getContext();
		int l = context.state.matrixStack.length;
		context.pushMatrix();
		context.popMatrix();
		assert (l==context.state.matrixStack.length);
	}

	/// Pop all OpenGL state from the stack. This is equivalent of glPopAttrib() and glPopClientAttrib()
	void popState()
	{	assert(states.length);
		state = states[$-1];
		states.length = states.length - 1;	
	}
	
	/// Push all OpenGL state onto a stack. This is equivalent of glPushAttrib() and glPushClientAttrib()
	void pushState()
	{	states ~= state.dup();
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glRotate.xml
	void rotate(float angle, float x, float y, float z)
	{	state.matrix = state.matrix.rotate(Vec3f(angle, x, y, z));
	}
	void rotateTexture(float angle, float x, float y, float z) /// ditto
	{	state.textureMatrix = state.textureMatrix.rotate(Vec3f(angle, x, y, z));
	}
	void rotateProjection(float angle, float x, float y, float z) /// ditto
	{	state.projectionMatrix = state.projectionMatrix.rotate(Vec3f(angle, x, y, z));
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glScale.xml
	void scale(float x, float y, float z)
	{	state.matrix.v[0] *= x;
		state.matrix.v[5] *= y;
		state.matrix.v[9] *= z;
	}
	void scaleTexture(float x, float y, float z) /// ditto
	{	state.textureMatrix.v[0] *= x;
		state.textureMatrix.v[5] *= y;
		state.textureMatrix.v[9] *= z;
	}
	void scaleProjection(float x, float y, float z) /// ditto
	{	state.projectionMatrix.v[0] *= x;
		state.projectionMatrix.v[5] *= y;
		state.projectionMatrix.v[9] *= z;
	}
	
	//// See: http://opengl.org/sdk/docs/man/xhtml/glTexEnv.xml
	void texEnv(uint target, uint pname, int param)
	{	state.texEnvi[target][pname] = param;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glTexImage2D.xml
	void texImage2D(uint target, int level, int internalFormat, int width, int height, int border, uint format, uint type, void[] data)
	{	synchronized (openGLMutex)
		{	applyState();
			glTexImage2D(target, level, internalFormat, width, height, border, format, type, data.ptr);
			checkError();
		}
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glTexParameter.xml
	void texParameter(uint target, uint pname, int param)
	{	state.texParameteri[target][pname] = param;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glTranslate.xml
	void translate(float x, float y, float z)
	{	state.matrix.v[12] += x;
		state.matrix.v[13] += y;
		state.matrix.v[14] += z;
	}
	void translateTexture(float x, float y, float z) /// ditto
	{	state.textureMatrix.v[12] += x;
		state.textureMatrix.v[13] += y;
		state.textureMatrix.v[14] += z;
	}
	void translateProjection(float x, float y, float z) /// ditto
	{	state.projectionMatrix.v[12] += x;
		state.projectionMatrix.v[13] += y;
		state.projectionMatrix.v[14] += z;
	}
	
	// Internal functions:
	
		
	// Get the context for the current thread.
	private static OpenGL getContext()
	{	
		Thread thread = Thread.getThis();
		if (!(thread in contexts))
		{			
			// Add to a copy of contexts to preserve immutability (and keep things thread safe)
			synchronized(contextMutex) // would ReadWriteMutex work better?
			{	scope newContexts = contexts; // TODO: need to .dup
				newContexts[thread] = new OpenGL();
				contexts = newContexts; // array assignment isn't atomic?
				contexts.rehash;
		}	}
	
		return contexts[thread];
	}
	unittest
	{	assert(getContext() == getContext());
	}
	
	/**
	 * Apply the current OpenGL state
	 * Returns: the number of necessary OpenGL calls. */
	int applyState()
	{	
		int calls;
		//synchronized (openGLMutex)
		{	
					
			//if (random(0, 1) > .99)
			//	st.rehash();
			
			
			// Enabled states
			{
				scope keys = state.enable.keys;
				scope values = state.enable.values;
				scope oldValues = appliedState.enable.values;
				for (int i=0; i<values.length; i++)
					if (values[i] != oldValues[i])
					{	values[i] ? glEnable(keys[i]) : glDisable(keys[i]);
						calls++;
					}
				
				keys = state.enableClientState.keys;
				values = state.enableClientState.values;
				oldValues = appliedState.enableClientState.values;
				for (int i=0; i<values.length; i++)
					if (values[i] != oldValues[i])
					{	values[i] ? glEnableClientState(keys[i]) : glEnableClientState(keys[i]);
						calls++;
					}
			}
			
			// Matrices
			if (state.matrix != appliedState.matrix)
			{	glLoadMatrixf(cast(float*)state.matrix.ptr);
				calls++;
				//checkError();
			}
			if (state.textureMatrix != appliedState.textureMatrix)
			{	glMatrixMode(GL_TEXTURE); 
				glLoadMatrixf(cast(float*)state.textureMatrix.ptr);
				glMatrixMode(GL_MODELVIEW); // This won't be needed once everything uses Graphics.
				calls+= 3;
				//checkError();
			}
			if (state.projectionMatrix != appliedState.projectionMatrix)
			{	glMatrixMode(GL_PROJECTION); 
				glLoadMatrixf(cast(float*)state.projectionMatrix.ptr);
				glMatrixMode(GL_MODELVIEW); // This won't be needed once everything uses Graphics.
				calls+= 3;
				//checkError();
			}
			
			//if (st.enable[GL_TEXTURE_2D])
			//	calls+= applyTextures();
			
			calls+= applyLights();
			
			/*
			// Material
			foreach (face, params; st.materials)
				foreach (pname, value; params)
					//if (!keysExist(appliedState.material, face, pname) || appliedState.materials[face][pname] != value)
					{	glMaterialfv(face, pname, value.ptr);
						calls++;
					}
			//checkError();
			*/
			
			if (state.color != appliedState.color)
			{	glColor4fv(state.color.ptr);
				calls++;
				//checkError();
			}
			
			if (state.alphaFunc != appliedState.alphaFunc)
			{	glAlphaFunc(state.alphaFunc.func, state.alphaFunc.value);
				calls++;
				//checkError();
			}
			
			if (state.blendFunc != appliedState.blendFunc)
			{	glBlendFunc(state.blendFunc.sfactor, state.blendFunc.dfactor);
				calls++;
				//checkError();
			}
			
			if (state.cullFace != appliedState.cullFace)
			{	glCullFace(state.cullFace);
				calls++;
				//checkError();
			}
			
			if (state.depthMask != appliedState.depthMask)
			{	glDepthMask(state.depthMask);
				calls++;
				//checkError();
			}
			
			if (state.lineWidth != appliedState.lineWidth)
			{	glLineWidth(state.lineWidth);
				calls++;
				//checkError();
			}
			
			if (state.pointSize != appliedState.pointSize)
			{	glPointSize(state.pointSize);
				calls++;
				//checkError();
			}
			
			if (calls)
				appliedState = state.dup();
		}
		
		//writefln(calls);
		
		return calls;
	}
	
	private int applyTextures()
	{	int calls;
			
		// TODO: unit
		foreach (target, params; state.textures) // [below] Can be uncommented when all calls to glBindTexture are made through OpenGL.
			foreach (unit, value; params) 
				if (appliedState.textures[target][unit] != value)
				{	glBindTexture(target, value);
					calls++;
				}
		//checkError();
		
		foreach (target, params; state.texParameteri)
			foreach (pname, value; params) 
				if (!keysExist(appliedState.texParameteri, target, pname) || appliedState.texParameteri[target][pname] != value)
				{	glTexParameteri(target, pname, value);
					calls++;
				}
		//checkError();
		
		foreach (target, params; state.texEnvi)
			foreach (pname, value; params) 
				if (!keysExist(appliedState.texEnvi, target, pname) || appliedState.texEnvi[target][pname] != value)
				{	glTexEnvi(target, pname, value);
					calls++;
				}
		//checkError();
		
		return calls;
	}
	
	private int applyLights()
	{	
		int calls;
		
		checkError();
		foreach (i, light; state.lights)
		{	scope keys = light.keys;
			scope values = light.values;
			scope oldValues = appliedState.lights[i].values;
			for (int j=0; j<values.length; j++)
			{	//writefln("%s %s %s", keys[j], values[j].v, oldValues[j].v);
				if (values[j] != oldValues[j])
				{	if (values[j].length > 1)
					{//	writefln("%0x %0x %f", GL_LIGHT0+i, keys[j], values[j].v);
						glLightfv(GL_LIGHT0+i, keys[j], values[j].v.ptr);
					//	checkError();
					}
					else
					{//	writefln("%0x %0x %f", GL_LIGHT0+i, keys[j], values[j]);
						glLightf(GL_LIGHT0+i, keys[j], values[j].v[0]);
					//	checkError();
					}
					calls++;
				}
			}
		}
		//writefln("apply lights");
		return calls;
	}

	/**
	 * Throw GraphicsException if the last OpenGL operation resulted in an error. */
	private void checkError()
	{	int err = glGetError();
		if (err != GL_NO_ERROR)
			throw new GraphicsException("Error {}, {}", err, fromStringz(cast(char*)gluErrorString(err)));
	}
}

/**
 * Exception thrown on a Graphics error. */
class GraphicsException : YageException
{	this(char[] message, ...)
	{	super(Format.convert(_arguments, _argptr, message));
	}	
}

import tango.core.Traits;

private bool keysExist(T, K, L, A, B)(T[A][B] aa, K k, L l)
{	T[A]* elem = k in aa;
	return (elem && (l in *elem));
}
unittest 
{	{
		int[char[]][char[]] foo;
		foo["a"]["b"] = 1;
		assert(keysExist(foo, "a", "b"));
		assert(!keysExist(foo, "b", "a"));
	} {
		int[uint][uint] foo;
		foo[1][2] = 1;
		assert(keysExist(foo, 1, 2));
		assert(!keysExist(foo, 2, 1));
	}
}