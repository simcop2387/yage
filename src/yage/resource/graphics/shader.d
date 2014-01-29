/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.graphics.shader;

import yage.system.log;


/**
 * Shader stores vertex and fragment shader source code 
 * used by the graphics API to create a shader program. 
 * GraphicsApi.bindShader(Shader) binds the shader program, creating it if it doesn't exist.*/
class Shader
{
	//bool failed = false;
	
	string compileLog;		///
	
	protected string vertexSource;
	protected string fragmentSource;
	
	/**
	 * Params:
	 *     vertexSource = Source code of a vertex shader.
	 *     fragmentSource = Source code of a fragment shader. */
	this(string vertexSource, char[] fragmentSource)
	{	this.vertexSource = vertexSource~"\0";
		this.fragmentSource = fragmentSource~"\0";
	}
	
	///
	string getVertexSource(bool nullTerminated=false)
	{	if (nullTerminated)		
			return vertexSource;
		return vertexSource[0..$-1];
	}
	
	///
	string getFragmentSource(bool nullTerminated=false)
	{	if (nullTerminated)		
			return fragmentSource;	
		return fragmentSource[0..$-1];
	}
	
	/// TODO, this should get the uniform variable names and types.
	// The uniform data should be separate from the Shader.
	ShaderUniform[] getUniforms()
	{
		ShaderUniform[] result;
		
		return result;
	}
}


/**
 * Used to pass variables to a shader */
struct ShaderUniform
{
	///
	enum Type
	{	I1, I2, I3, I4,
		F1, F2, F3, F4,
		M2x2, M3x3, M4x4,
		M2x3, M3x2, M2x4, M4x2, M4x3, M3x4
	}
	Type type;		///
	char[64] name = 0;	///
	union { ///
		int[16] intValues;	///
		float[16] floatValues; ///
	}
	
	/// Constructors
	static ShaderUniform opCall(string name, Type type, float[] values...)
	{	ShaderUniform result;
		result.name[0..name.length] = name[0..$];		
		result.floatValues[0..values.length] = values[0..$];
		result.type = type;
		return result;
	}	
	static ShaderUniform opCall(string name, Type type, int[] values...) /// ditto
	{	ShaderUniform result;
		result.name[0..name.length] = name[0..$];
		result.intValues[0..values.length] = values[0..$];
		result.type = type;
		return result;
	}
}