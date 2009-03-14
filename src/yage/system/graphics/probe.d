/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.system.graphics.probe;

import std.string;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.system.system;

/**
 * Provides hardware probing capabilities for Yage. */
abstract class Probe
{
	/**
	 * Options for Probe.openGL() */
	enum OpenGL
	{	MAX_LIGHTS,			/// Maximum number of lights that can be used at one time
		MAX_TEXTURE_SIZE,	/// Maximum allowed size for a texture
		MAX_TEXTURE_UNITS,	/// Maximum number of textures that can be used in multitexturing
		
		FBO,				/// Hardware support for rendering directly to a texture (Frame Buffer Object)
		MULTITEXTURE,		/// Hardware support for using multiple textures in a single rendering pass
		NON_2_TEXTURE,		/// Hardware support for textures of arbitrary size
		SHADER,				/// Hardware support for openGl vertex and fragment shaders
		VBO,				/// Hardware support for caching vertex data in video memory (Vertex Buffer Object)
		BLEND_COLOR,
		BLEND_FUNC_SEPARATE
	}	
	
	/**
	 * Query an OpenGL value.
	 * Params:
	 *     constant = A value from the OpenGL enum defined above.
	 * Returns: 1/0 for true/false queries or an integer value for numeric queries.
	 * 
	 * Example:
	 * --------
	 * Probe.openGL(Probe.OpenGL.SHADER); // returns 1 if shaders are supported or 0 otherwise.
	 * --------
	 */
	static int openGL(OpenGL query)
	{	static int shader=-1, vbo=-1, mt=-1, np2=-1, bc=-1, bfs=-1;	// so lookup only has to occur once.
		int result;
		
		switch (query)
		{	
			// TODO: These need to be cached so we don't do opengl calls from threads besides the rendering thread.
			case OpenGL.MAX_LIGHTS:				
				glGetIntegerv(GL_MAX_LIGHTS, &result);
				return result;
			case OpenGL.MAX_TEXTURE_SIZE:
				glGetIntegerv(GL_MAX_TEXTURE_SIZE, &result);
				return result;
			case OpenGL.MAX_TEXTURE_UNITS:
				glGetIntegerv(GL_MAX_TEXTURE_UNITS, &result);
				return result;
		
			case OpenGL.SHADER:
				//version(linux)		// Shaders often fail on linux due to poor driver support!  :(
				//	return 0;	// ATI drivers will claim shader support but fail on shader compile.
									// This needs a better workaround.
				if (shader==-1)
					shader = cast(int)checkExtension("GL_ARB_shader_objects") && checkExtension("GL_ARB_vertex_shader");
				return shader;				
			case OpenGL.VBO: //return false; // true breaks custom vertex attributes
				if (vbo==-1)
					vbo = cast(int)checkExtension("GL_ARB_vertex_buffer_object");
				return cast(bool)vbo;
			case OpenGL.MULTITEXTURE:
				if (mt==-1)
					mt = cast(int)checkExtension("GL_ARB_multitexture");
				return mt;
			case OpenGL.NON_2_TEXTURE:
				if (np2==-1)
					np2 = cast(int)checkExtension("GL_ARB_texture_non_power_of_two");
				return np2;
			case OpenGL.BLEND_COLOR:
				if (bc==-1)
					bc = cast(int)checkExtension("GL_EXT_blend_color");
				return bc;
			case OpenGL.BLEND_FUNC_SEPARATE: // unused.
				if (bfs==-1)
					bfs = cast(int)checkExtension("GL_EXT_blend_func_separate");
				return bfs;	
		}
		
	}
	
	/**
	 * Searches to see if the given extension is supported in hardware.*/
	static bool checkExtension(char[] name)
	{	char[] exts = std.string.toString(cast(char*)glGetString(GL_EXTENSIONS));
	    int result = find(tolower(exts), tolower(name)~" "); 
	    delete exts; // [above] append space to ensure we're not matching part of another extension.
		if (result>=0)
			return true;
	    return false;
	}

	/// Return an array of all supported OpenGL extensions.
	static char[][] getExtensions()
	{	char[] exts = std.string.toString(cast(char*)glGetString(GL_EXTENSIONS));
		return split(exts, " ");
	}
}