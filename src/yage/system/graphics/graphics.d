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
alias OpenGL Graphics;

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


/**
 * This represents a current OpenGL state that can be pushed or popped. 
 * It is currently unfinished and has bugs. */
private struct OpenGLState
{
	Matrix matrix;	
	Matrix[] matrixStack;
	//Matrix projectionMatrix;	
	//Matrix[] projectionMatrixStack;
	Matrix textureMatrix;
	Matrix[] textureMatrixStack;
	
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

	/// Constructor
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
		result.enable = enable.dup;
		result.enableClientState = result.enableClientState.dup;
		result.materials = .dup(result.materials, true);		
		result.texEnvi = .dup(result.texEnvi, true);
		result.texParameteri = .dup(result.texParameteri, true);
		result.textures = .dup(result.textures);
		result.lights[0..$] = result.lights.dup[0..$];
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
	OpenGLState state;
	OpenGLState appliedState; // last state that was applied.
	OpenGLState[] states; // stack of states
	
	private static Object openGLMutex;
	private static Object contextMutex;
	private static OpenGL[Thread] contexts; // immutable
	
	static this()
	{	contextMutex = new Object();
		openGLMutex = new Object();
	}
	
	/// Construct and create an initial state on the state stack.
	this()
	{	state = appliedState = OpenGLState();
	}

	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glAlphaFunc.xml
	static void alphaFunc(uint func, float value)
	{	st.alphaFunc.func = func;
		st.alphaFunc.value = value;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glBindBuffer.xml
	static void bindBuffer(uint target, uint buffer)
	{	synchronized (openGLMutex)
		{	glBindBufferARB(target, buffer);
			checkError();
		}
	}

	/// See: http://opengl.org/sdk/docs/man/xhtml/glBindTexture.xml, http://opengl.org/sdk/docs/man/xhtml/glActiveTexture.xml
	/// TODO: textureUnit
	static void bindTexture(uint target, uint texture, uint textureUnit=GL_TEXTURE0_ARB)
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
	static void blendFunc(uint sfactor, uint dfactor)
	{	st.blendFunc.sfactor = sfactor;
		st.blendFunc.dfactor = dfactor;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glBufferData.xml
	static void bufferData(uint target, void[] data, uint usage=GL_STATIC_DRAW_ARB)
	{	synchronized (openGLMutex)
		{	glBufferDataARB(target, data.length, data.ptr, usage);
			checkError();
		}
	}

	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glClear.xml
	static void clear(uint mask)
	{
		applyState(); /// TODO: only need to apply the color state.
		synchronized (openGLMutex)
		{	glClear(mask);
			checkError();
		}
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glColor.xml
	static void color(float[] value)
	{	int l = value.length > 4 ? 4 : value.length;
		st.color[0..l] = value[0..l];		
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glCullFace.xml
	static void cullFace(uint mode)
	{	st.cullFace = mode;		
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glDeleteBuffers.xml
	static void deleteBuffer(uint buffer)
	{	synchronized (openGLMutex)
		{	glDeleteBuffersARB(1, &buffer);
			checkError();
		}
	}

	/// See: http://opengl.org/sdk/docs/man/xhtml/glDeleteTextures.xml
	static void deleteTexture(uint texture)
	{	synchronized (openGLMutex)
		{	glDeleteTextures(1, &texture);
			checkError();
		}
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glDepthMask.xml
	static void depthMask(bool flag)
	{	st.depthMask = flag;
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glDisable.xml
	static void disable(uint cap)
	{	st.enable[cap] = false;		
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glDisableClientState.xml
	static void disableClientState(uint cap)
	{	st.enableClientState[cap] = false;		
	}
		
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glEnable.xml
	static void enable(uint cap)
	{	st.enable[cap] = true;		
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glEnableClientState.xml
	static void enableClientState(uint cap)
	{	st.enableClientState[cap] = true;		
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glGenBuffers.xml
	static uint genBuffer()
	{	uint buffer;
		synchronized (openGLMutex)
		{	glGenBuffersARB(1, &buffer);
			checkError();
		}
		return buffer;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glGenTextures.xml
	static uint genTexture()
	{	uint buffer;
		synchronized (openGLMutex)
		{	glGenTextures(1, &buffer);
			checkError();
		}
		return buffer;
	}
	
	// broken
	static void light(ubyte light, uint pname, float param)
	{	st.lights[light][pname] = Float4(param);
		assert(st.lights[light][pname].v[0] == param);
	}
	static void light(ubyte light, uint pname, float[] param)
	{	st.lights[light][pname].v[0..$] = param[0..$];
	}
		
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glLineWidth.xml
	static void lineWidth(float width)
	{	st.lineWidth = width;		
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glLoadIdentity.xml
	static void loadIdentity()
	{	st.matrix = Matrix();	
	}
	static void loadIdentityTexture() /// ditto
	{	st.textureMatrix = Matrix();
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glLoadMatrix.xml
	static void loadMatrix(Matrix m)
	{	st.matrix = m;
	}
	static void loadTextureMatrix(Matrix m) /// ditto
	{	st.textureMatrix = m;		
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glMaterial.xml
	static void material(uint face, uint pname, float[] param)
	{	st.materials[face][pname] = param;
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glMultMatrix.xml
	static void multMatrix(Matrix m)
	{	st.matrix *= m;
	}
	static void multTextureMatrix(Matrix m) /// ditto
	{	st.textureMatrix *= m;		
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glPointSize.xml
	static void pointSize(float size)
	{	st.pointSize = size;		
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glPolygonMode.xml
	static void polygonMode(uint face, uint mode)
	{	if (face==GL_FRONT || face==GL_FRONT_AND_BACK)
			st.polygonMode.front = mode;
		else if (face==GL_BACK || face==GL_FRONT_AND_BACK)
			st.polygonMode.back = mode;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glPopMatrix.xml
	static void popMatrix()
	{	assert(st.matrixStack.length);
		st.matrix = st.matrixStack[$-1];
		st.matrixStack.length = st.matrixStack.length-1;
	}
	static void popTextureMatrix() /// ditto
	{	assert(st.textureMatrixStack.length);
		st.textureMatrix = st.textureMatrixStack[$-1];
		st.textureMatrixStack.length = st.textureMatrixStack.length-1;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glPushMatrix.xml
	static void pushMatrix()
	{	st.matrixStack ~= st.matrix;
	}
	static void pushTextureMatrix() /// ditto
	{	st.textureMatrixStack ~= st.textureMatrix;
	}
	unittest
	{	int l = st.matrixStack.length;
		pushMatrix();
		popMatrix();
		assert (l==st.matrixStack.length);
	}

	/// Pop all OpenGL state from the stack. This is equivalent of glPopAttrib() and glPopClientAttrib()
	static void popState()
	{	OpenGL context = getContext();
		
		assert(context.states.length);
		context.state = context.states[$-1];
		context.states.length = context.states.length - 1;	
	}
	
	/// Push all OpenGL state onto a stack. This is equivalent of glPushAttrib() and glPushClientAttrib()
	static void pushState()
	{	OpenGL context = getContext();
		context.states ~= context.state;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glRotate.xml
	static void rotate(float angle, float x, float y, float z)
	{	st.matrix = st.matrix.rotate(Vec3f(angle, x, y, z));
	}
	static void rotateTexture(float angle, float x, float y, float z) /// ditto
	{	st.textureMatrix = st.textureMatrix.rotate(Vec3f(angle, x, y, z));
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glScale.xml
	static void scale(float x, float y, float z)
	{	st.matrix.v[0] *= x;
		st.matrix.v[5] *= y;
		st.matrix.v[9] *= z;
	}
	static void scaleTexture(float x, float y, float z) /// ditto
	{	st.textureMatrix.v[0] *= x;
		st.textureMatrix.v[5] *= y;
		st.textureMatrix.v[9] *= z;
	}
	
	//// See: http://www.opengl.org/sdk/docs/man/xhtml/glTexEnv.xml
	static void texEnv(uint target, uint pname, int param)
	{	st.texEnvi[target][pname] = param;
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glTexImage2D.xml
	static void texImage2D(uint target, int level, int internalFormat, int width, int height, int border, uint format, uint type, void[] data)
	{	synchronized (openGLMutex)
		{	applyState();
			glTexImage2D(target, level, internalFormat, width, height, border, format, type, data.ptr);
			checkError();
		}
	}
	
	/// See: http://www.opengl.org/sdk/docs/man/xhtml/glTexParameter.xml
	static void texParameter(uint target, uint pname, int param)
	{	st.texParameteri[target][pname] = param;
	}
	
	/// See: http://opengl.org/sdk/docs/man/xhtml/glTranslate.xml
	static void translate(float x, float y, float z)
	{	float[] v = st.matrix.v;
		v[12] += x;
		v[13] += y;
		v[14] += z;
	}
	static void translateTexture(float x, float y, float z) /// ditto
	{	float[] v = st.matrix.v;
		v[12] += x;
		v[13] += y;
		v[14] += z;
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
	
	/*
	 * Shortcut for getting the state for the current virtual context. */
	private static OpenGLState* st()
	{	return &getContext().state;
	}
	unittest
	{	assert(st == st);
	}
	
	/**
	 * Apply the current OpenGL state
	 * Returns: the number of necessary OpenGL calls. */
	static int applyState()
	{	
		int calls;
		//synchronized (openGLMutex)
		{	
			OpenGL context = getContext();
			OpenGLState* st = &context.state;
			OpenGLState* appliedState = &context.appliedState;
			
			//if (random(0, 1) > .99)
			//	st.rehash();
			
			{
				scope keys = st.enable.keys;
				scope values = st.enable.values;
				scope oldValues = appliedState.enable.values;
				for (int i=0; i<values.length; i++)
					if (values[i] != oldValues[i])
					{	values[i] ? glEnable(keys[i]) : glDisable(keys[i]);
						calls++;
					}
				
				keys = st.enableClientState.keys;
				values = st.enableClientState.values;
				oldValues = appliedState.enableClientState.values;
				for (int i=0; i<values.length; i++)
					if (values[i] != oldValues[i])
					{	values[i] ? glEnableClientState(keys[i]) : glEnableClientState(keys[i]);
						calls++;
					}
			}
			
			// Matrices
			if (st.matrix != appliedState.matrix)
			{	glLoadMatrixf(cast(float*)st.matrix.ptr);
				calls++;
				//checkError();
			}
			if (st.textureMatrix != appliedState.textureMatrix)
			{	glMatrixMode(GL_TEXTURE);
				glLoadMatrixf(cast(float*)st.textureMatrix.ptr);
				glMatrixMode(GL_MODELVIEW);
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
			
			if (st.color != appliedState.color)
			{	glColor4fv(st.color.ptr);
				calls++;
				//checkError();
			}
			
			if (st.alphaFunc != appliedState.alphaFunc)
			{	glAlphaFunc(st.alphaFunc.func, st.alphaFunc.value);
				calls++;
				//checkError();
			}
			
			if (st.blendFunc != appliedState.blendFunc)
			{	glBlendFunc(st.blendFunc.sfactor, st.blendFunc.dfactor);
				calls++;
				//checkError();
			}
			
			if (st.cullFace != appliedState.cullFace)
			{	glCullFace(GL_BACK);
				calls++;
				//checkError();
			}
			
			if (st.depthMask != appliedState.depthMask)
			{	glDepthMask(st.depthMask);
				calls++;
				//checkError();
			}
			
			if (st.lineWidth != appliedState.lineWidth)
			{	glLineWidth(st.lineWidth);
				calls++;
				//checkError();
			}
			
			if (st.pointSize != appliedState.pointSize)
			{	glPointSize(st.pointSize);
				calls++;
				//checkError();
			}
			
			if (calls)
				context.appliedState = context.state.dup();
		}
		
		//writefln(calls);
		
		return calls;
	}
	
	private static int applyTextures()
	{	int calls;
	
		OpenGL context = getContext();
		OpenGLState* st = &context.state;
		OpenGLState* appliedState = &context.appliedState;
			
		// TODO: unit
		foreach (target, params; st.textures) // [below] Can be uncommented when all calls to glBindTexture are made through OpenGL.
			foreach (unit, value; params) 
				if (appliedState.textures[target][unit] != value)
				{	glBindTexture(target, value);
					calls++;
				}
		//checkError();
		
		foreach (target, params; st.texParameteri)
			foreach (pname, value; params) 
				if (!keysExist(appliedState.texParameteri, target, pname) || appliedState.texParameteri[target][pname] != value)
				{	glTexParameteri(target, pname, value);
					calls++;
				}
		//checkError();
		
		foreach (target, params; st.texEnvi)
			foreach (pname, value; params) 
				if (!keysExist(appliedState.texEnvi, target, pname) || appliedState.texEnvi[target][pname] != value)
				{	glTexEnvi(target, pname, value);
					calls++;
				}
		//checkError();
		
		return calls;
	}
	
	private static int applyLights()
	{	
		int calls;
		
		OpenGL context = getContext();
		OpenGLState* st = &context.state;
		OpenGLState* appliedState = &context.appliedState;
		checkError();
		foreach (i, light; st.lights)
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
	private static void checkError()
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