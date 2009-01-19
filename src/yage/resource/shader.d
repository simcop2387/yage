/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.shader;

import std.file;
import std.string;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.system.constant;
import yage.system.device;
import yage.system.log;
import yage.core.exceptions;
import yage.resource.manager;
import yage.resource.resource;


/**
 * A Shader is a class used to represent a vertex or fragment shader.
 * Material layers link shader objects together to form shader programs.
 * When a node that uses that material is rendered, the shader program is applied.*/
class Shader : Resource
{
	protected char[]	source;		// path to the source code.
	protected char[]	code;		// Source code of the shader.
	protected uint		shader;		// OpenGL handle to the compiled object code
	protected bool		type;		// 0 for vertex, 1 for fragment shader.


	/**
	 * Construct this shader and then load and compile the given shader file.
	 * Params:
	 * filename = The shader source code file to load.
	 * type = Set to 0 for a vertex shader or 1 for a fragment shader. */
	this(char[] filename, bool type)
	{
		// Load
		source = ResourceManager.resolvePath(filename);
		this.type = type;
		Log.write("Loading shader '", filename, "'.");
		code = cast(char[])read(source);

		// Compile
		Log.write("Compiling shader '", source, "'.");
		char** charcode = (new char*[1]).ptr;
		charcode[0] = (code~"\0").ptr;
		if (type==0)
			shader = glCreateShaderObjectARB(GL_VERTEX_SHADER_ARB);
		else
			shader = glCreateShaderObjectARB(GL_FRAGMENT_SHADER_ARB);
		glShaderSourceARB(shader, 1, charcode, null);
		glCompileShaderARB(shader);

		// Log
		int status;
		glGetObjectParameterivARB(shader, GL_OBJECT_COMPILE_STATUS_ARB, &status);
		if (!status)
		{	Log.write(getCompileLog());
			throw new ResourceManagerException("Could not compile shader '" ~ source ~ "'.");
		}
	}

	/// Free the shader object from OpenGL memory.
	~this()
	{	Log.write("Removing shader '", source, "'.");
		glDeleteObjectARB(shader);
	}

	/// Return the source filename of this shader.
	char[] getSource()
	{	return source;
	}

	/// Return the source code of this shader.
	char[] getCode()
	{	return code;
	}

	/// Return the OpenGL handle of the compiled shader.
	uint getShader()
	{	return shader;
	}

	/**
	 * Get messages from the shader compiler.*/
	char[] getCompileLog()
	{	int len;  char *log;
		glGetObjectParameterivARB(shader, GL_OBJECT_INFO_LOG_LENGTH_ARB, &len);
		if (len > 0)
		{	log = (new char[len]).ptr;
			glGetInfoLogARB(shader, len, &len, log);
		}
		return .toString(log);
	}

}
