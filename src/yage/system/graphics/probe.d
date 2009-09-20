/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.graphics.probe;

import tango.util.Convert;
import tango.stdc.stringz;
import tango.text.Unicode;
import tango.text.Util;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.system.system;

/**
 * Provides hardware probing capabilities for Yage. */
abstract class Probe
{
	/**
	 * Options for Probe.feature() */
	enum Feature
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
	 * Query the hardware to see if a feature is supported
	 * For OpenGL features, the window must first be created.
	 * Params:
	 *     constant = A value from the Feature enum defined above.
	 * Returns: 1/0 for true/false queries or an integer value for numeric queries.
	 * 
	 * Example:
	 * --------
	 * Probe.feature(Probe.Feature.SHADER); // returns 1 if shaders are supported or 0 otherwise.
	 * --------
	 */
	static int feature(Feature query)
	{	static int fbo=-1, shader=-1, vbo=-1, mt=-1, np2=-1, bc=-1, bfs=-1;	// so lookup only has to occur once.
		int result;
		
		switch (query)
		{	
			// TODO: These need to be cached so we don't do opengl calls from threads besides the rendering thread.
			case Feature.MAX_LIGHTS:				
				glGetIntegerv(GL_MAX_LIGHTS, &result);
				return result;
			case Feature.MAX_TEXTURE_SIZE:
				glGetIntegerv(GL_MAX_TEXTURE_SIZE, &result);
				return result;
			case Feature.MAX_TEXTURE_UNITS:
				glGetIntegerv(GL_MAX_TEXTURE_UNITS, &result);
				return result;
				
			case Feature.FBO:
				if (fbo==-1)
					fbo = cast(int)checkExtension("GL_EXT_frame_buffer_object");
				return fbo;
			
			case Feature.SHADER:
				if (shader==-1)
					shader = cast(int)checkExtension("GL_ARB_shader_objects") && checkExtension("GL_ARB_vertex_shader");
				return shader;				
			case Feature.VBO: //return false; // true breaks custom vertex attributes
				if (vbo==-1)
					vbo = cast(int)checkExtension("GL_ARB_vertex_buffer_object");
				return cast(bool)vbo;
			case Feature.MULTITEXTURE:
				if (mt==-1)
					mt = cast(int)checkExtension("GL_ARB_multitexture");
				return mt;
			case Feature.NON_2_TEXTURE:
				if (np2==-1)
					np2 = cast(int)checkExtension("GL_ARB_texture_non_power_of_two");
				return np2;
			case Feature.BLEND_COLOR:
				if (bc==-1)
					bc = cast(int)checkExtension("GL_EXT_blend_color");
				return bc;
			case Feature.BLEND_FUNC_SEPARATE: // unused.
				if (bfs==-1)
					bfs = cast(int)checkExtension("GL_EXT_blend_func_separate");
				return bfs;
			default:
				return 0;
		}
		return 0;		
	}
	
	/**
	 * Searches to see if the given extension is supported in hardware.
	 * Due to the nature of sdl, a window must first be created before calling this function. */
	static bool checkExtension(char[] name)
	{	char[] exts = fromStringz(cast(char*)glGetString(GL_EXTENSIONS));
	    int result = containsPattern(toLower(exts), toLower(name.dup)~" "); 
	    delete exts; // [above] append space to ensure we're not matching part of another extension.
		if (result>=0)
			return true;
	    return false;
	}

	/**
	 * Return an array of all supported OpenGL extensions.
	 * Due to the nature of sdl, a window must first be created before calling this function. */ 
	static char[][] getExtensions()
	{	char[] exts = fromStringz(cast(char*)glGetString(GL_EXTENSIONS));
		return split(exts, " ");
	}
}