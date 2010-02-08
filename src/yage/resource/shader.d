/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.shader;


/**
 * Shader stores vertex and fragment shader source code 
 * used by the graphics API to create a shader program. 
 * GraphicsApi.bindShader(Shader) binds the shader program, creating it if it doesn't exist.*/
class Shader
{
	/// Compile status of the shader.
	enum Status
	{	NONE,		///
		SUCCESS,	/// ditto
		FAIL		/// ditto
	}		
	Status status;			/// ditto
	
	char[] compileLog;		///
	
	protected char[] vertexSource;
	protected char[] fragmentSource;
	protected ShaderUniform[] uniforms;
	
	/**
	 * Params:
	 *     vertexSource = Source code of a vertex shader.
	 *     fragmentSource = Source code of a fragment shader. */
	this(char[] vertexSource, char[] fragmentSource)
	{	this.vertexSource = vertexSource~"\0";
		this.fragmentSource = fragmentSource~"\0";
	}
	
	///
	char[] getVertexSource(bool nullTerminated=false)
	{	if (nullTerminated)		
			return vertexSource;
		return vertexSource[0..$-1];
	}
	
	///
	char[] getFragmentSource(bool nullTerminated=false)
	{	if (nullTerminated)		
			return fragmentSource;	
		return fragmentSource[0..$-1];
	}
	
	
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
	
	enum Type
	{	I1, I2, I3, I4,
		F1, F2, F3, F4,
		M2x2, M3x3, M4x4,
		M2x3, M3x2, M2x4, M4x2, M4x3, M3x4
	}
	Type type;
	char[] name;
	void* values;
	
	///
	static ShaderUniform opCall(char[] name, Type type, float[] values...)
	{	ShaderUniform result;
		result.name = name;
		result.values = values.ptr;
		result.type = type;
		return result;
	}	
	static ShaderUniform opCall(char[] name, Type type, int[] values...) /// ditto
	{	ShaderUniform result;
		result.name = name;
		result.values = values.ptr;
		result.type = type;
		return result;
	}
}