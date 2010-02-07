/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.shader;

import std.file;
import std.string;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.system.system;
import yage.system.log;
import yage.core.object2;;
import yage.resource.manager;
import yage.resource.resource;


/**
 * */
class Shader
{
	/// Compile status of the shader.
	enum Status
	{	NONE,		///
		COMPILED,	/// ditto
		LINKED,		/// ditto
		EXECUTED,	/// ditto
		FAILED		/// ditto
	}		
	Status status;			/// ditto
	
	char[] compileLog;		///
	
	protected char[] vertexSource;
	protected char[] fragmentSource;
	
	///
	this(char[] vertexSource, char[] fragmentSource)
	{	this.vertexSource = vertexSource;
		this.fragmentSource = fragmentSource;
	}
	
	///
	char[] getVertexSource()
	{	return vertexSource;		
	}
	
	///
	char[] getFragmentSource()
	{	return fragmentSource;		
	}
}
