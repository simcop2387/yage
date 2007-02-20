/**
 * Copyright:  (c) 2006-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.layer;

import std.math;
import std.stdio;
import std.string;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.horde;
import yage.core.misc;
import yage.core.matrix;
import yage.core.vector;
import yage.system.constant;
import yage.system.device;
import yage.system.log;
import yage.system.render;
import yage.resource.texture;
import yage.resource.resource;
import yage.resource.shader;
import yage.node.light;

/**
 * Each material is divided into one or more layers.
 * Layers represent a single rendering pass.  They can optionally have shaders
 * that compile into a single program, multiple textures, and various other
 * rendering attributes.
 * If no shaders are specified, the material uses the default fixed-function
 * OpenGL rendering mode. If Textures are supplied, the first will be used as
 * the regular diffuse color map, the second as a normal map, and the third as
 * an environment map.  (This part still needs to be completed).
 *
 * When an xml Material file is loaded, this class is used to represent each Layer
 * defined in the file. */
class Layer
{
	Vec4f	ambient;				/// Property for the RGBA ambient layer color, default is Vec4f(0).
	Vec4f	diffuse;				/// Property for the RGBA diffuse layer color, default is Vec4f(1).
	Vec4f	specular;				/// Property for the RGBA specular layer color, default is Vec4f(0).
	Vec4f	emissive;				/// Property for the RGBA emissive layer color, default is Vec4f(0).
	float	specularity=0;			/// Shininess exponential value, default is zero (no shininess).

	/// Property to set the blending for this Layer.
	/// See_Also: the LAYER_BLEND_* constants in yage.system.constant;
	int		blend = LAYER_BLEND_NONE;

	/// Property to set whether the front or back faces of polygons are culled (invisible).
	/// See_Also: the LAYER_CULL_* constants in yage.system.constant
	int		cull = LAYER_CULL_BACK;

	/// Property to set whether the layer is drawn as polygons, lines or points.
	/// See_Also: the LAYER_DRAW_* constants in yage.system.constant
	int		draw = LAYER_DRAW_DEFAULT;

	/// Property to set the width of lines and points when the layer is rendered as such.
	int		width = 1;

	/// Property enable or disable clamping of the textures of this layer.
	/// See_Also: <a href="http://en.wikipedia.org/wiki/Texel_%28graphics%29">The Wikipedia entry for texel</a>
	bool 	clamp	=	false;

	/// Property to set the type of filtering used for the textures of this layer.
	/// See_Also: the TEXTURE_FILTER_* constants in yage.system.constant
	int 	filter	=	TEXTURE_FILTER_DEFAULT;

	protected Horde!(Texture) textures;
	protected Horde!(Shader) shaders;
	protected int program=0;
	static int current_program=0;


	/// Set material properties to default values.
	this()
	{	diffuse.set(1);
	}

	~this()
	{	if (program != 0)
			glDeleteObjectARB(program);
	}

	/**
	 * Add a Shader to this Layer.  Call linkShaders() to recompile the program.
	 * Returns: the index of the new Shader in the Shader array. */
	int addShader(Shader shader)
	{	return shaders.add(shader);
	}

	/// Add a new texture to this layer and return it.
	int addTexture(Texture texture)
	{	return textures.add(texture);
	}

	/**
	 * Return the OpenGL handle to the linked shader program.
	 * This value will most likely be zero unless shaders have been
	 * loaded and linked.*/
	uint getShaderProgram()
	{	return program;
	}

	/// Return the array of shader obects used by this layer.
	Shader[] getShaders()
	{	return shaders.array();
	}

	/// Get an array of all the textures of this layer.
	Texture[] getTextures()
	{	return textures.array();
	}

	/**
	 * Get messages from the shader program.*/
	char[] getShaderProgramLog()
	{	int len;  char *log;
		glGetObjectParameterivARB(program, GL_OBJECT_INFO_LOG_LENGTH_ARB, &len);
		if (len > 0)
		{	log = (new char[len]).ptr;
			glGetInfoLogARB(program, len, &len, log);
		}
		return .toString(log);
	}

	/// Link vertex and fragment shaders together into a vertex program.
	void linkShaders()
	{
		if (program != 0)
			glDeleteObjectARB(program);

		// Don't do anything if we have no shaders
		if (shaders.length ==0)
			return;
		program = glCreateProgramObjectARB();

		// Add shaders to the program
		foreach (Shader shader; shaders.array())
		{	glAttachObjectARB(program, shader.getShader());
			Log.write("Linking shader " ~ shader.getSource());
		}

		// Link the program and check for errors
		int status;
		try {
			glLinkProgramARB(program);
		} catch { Log.write("Link Failed");}
		glGetObjectParameterivARB(program, GL_OBJECT_LINK_STATUS_ARB, &status);
		if (!status)
		{	Log.write(getShaderProgramLog());
			throw new Exception("Could not link the shaders.");
		}
		glValidateProgram(program);
		Log.write(getShaderProgramLog());
		Log.write("Finished link");
	}

	/// Set a the value of a uniform variable (or array of uniform variables) in this Layer's Shader program.
	void setUniform(char[] name, float[] values ...)
	{	setUniform(name, 1, values);
	}
	/// Ditto
	void setUniform(char[] name, Vec2f[] values ...)
	{	setUniform(name, 2, cast(float[])values);
	}
	/// Ditto
	void setUniform(char[] name, Vec3f[] values ...)
	{	setUniform(name, 3, cast(float[])values);
	}
	/// Ditto
	void setUniform(char[] name, Vec4f[] values ...)
	{	setUniform(name, 4, cast(float[])values);
	}
	/// Ditto
	void setUniform(char[] name, Matrix[] values ...)
	{	setUniform(name, 14, cast(float[])values);
	}

	/// Return a string of xml for this layer.
	char[] toString()
	{	char[] result;
		result = "<layer" ~
			" ambient=\"" ~ floatToHex(ambient.v[0..3]) ~ "\"" ~
			" diffuse=\"" ~ floatToHex(diffuse.v[0..3]) ~ "\"" ~
			" specular=\"" ~ floatToHex(specular.v[0..3]) ~ "\"" ~
			" emissive=\"" ~ floatToHex(emissive.v[0..3]) ~ "\"" ~
			" specularity=\"" ~ .toString(specularity) ~ "\"" ~
			" blend=\"" ~ .toString(blend) ~ "\"" ~
			" clamp=\"" ~ .toString(clamp) ~ "\"" ~
			" filter=\"" ~ .toString(filter) ~ "\"" ~
			">";
		result~= "</layer>";
		return result;
	}

	/*
	 * Set all of the OpenGL states to the values of this material layer.
	 * This essentially applies the material.  Call unApply() to reset
	 * the OpenGL states back to the engine defaults in preparation for
	 * whatever will be rendered next.
	 * Params:
	 * lights = An array containing the LightNodes that affect this material,
	 * passed to the shader through uniform variables (unfinished).
	 * This function is used internally by the engine and doesn't normally need to be called. */
	void apply(LightNode[] lights = null, Vec4f color = Vec4f(1))
	{

		glMaterialfv(GL_FRONT, GL_AMBIENT, ambient.scale(color).v.ptr);
		glMaterialfv(GL_FRONT, GL_DIFFUSE, diffuse.scale(color).v.ptr);
		glMaterialfv(GL_FRONT, GL_SPECULAR, specular.v.ptr);
		glMaterialfv(GL_FRONT, GL_EMISSION, emissive.scale(color).v.ptr);
		glMaterialfv(GL_FRONT, GL_SHININESS, &specularity);

		// Blend
		if (blend != LAYER_BLEND_NONE)
		{	glEnable(GL_BLEND);
			glDepthMask(false);
			switch (blend)
			{	case LAYER_BLEND_ADD:
					glBlendFunc(GL_SRC_ALPHA, GL_ONE);
					break;
				case LAYER_BLEND_AVERAGE:
					glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
					break;
				case LAYER_BLEND_MULTIPLY:
					glBlendFunc(GL_ZERO, GL_SRC_COLOR);
					break;
		}	}

		// Cull
		if (cull == LAYER_CULL_FRONT)
			glCullFace(GL_FRONT);

		// Polygon
		switch (draw)
		{	default:
			case LAYER_DRAW_FILL: 	glPolygonMode(GL_FRONT_AND_BACK, GL_FILL); break;
			case LAYER_DRAW_LINES:
				glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
				glLineWidth(width);
				break;
			case LAYER_DRAW_POINTS:
				glPolygonMode(GL_FRONT_AND_BACK, GL_POINT);
				glPointSize(width);
				break;
		}

		// Enable the first texture if it exists
		if (textures.length && textures[0])
		{	glEnable(GL_TEXTURE_2D);
			textures[0].bind(clamp, filter);
		}

		// Shader
		if (program != 0)
		{	glUseProgramObjectARB(program);
			current_program = program;
			try {	// bad for performance?
				setUniform("light_number", lights.length);
			} catch{}
			try {
				setUniform("fog_enabled", cast(float)Render.getCurrentCamera().getScene().getFogEnabled());
			} catch{}
		}
	}

	/*
	 * Reset the OpenGL state to the defaults.
	 * This function is used internally by the engine and doesn't normally need to be called. */
	void unApply()
	{
		float s=0;
		glMaterialfv(GL_FRONT, GL_AMBIENT, Vec4f().v.ptr);
		glMaterialfv(GL_FRONT, GL_DIFFUSE, Vec4f(1).v.ptr);
		glMaterialfv(GL_FRONT, GL_SPECULAR, Vec4f().v.ptr);
		glMaterialfv(GL_FRONT, GL_EMISSION, Vec4f().v.ptr);
		glMaterialfv(GL_FRONT, GL_SHININESS, &s);

		glDisable(GL_BLEND);
		glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		glCullFace(GL_BACK);
		glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
		glDisable(GL_TEXTURE_2D);
		glDepthMask(true);
		if (program != 0)
		{	glUseProgramObjectARB(0);
			current_program = 0;
		}
	}

	// Helper function for the public setUniform() functions.
	protected void setUniform(char[] name, int width, float[] values)
	{	if (!Device.getSupport(DEVICE_SHADER))
			throw new Exception("Layer.setUniform() is only supported on hardware that supports shaders.");

		// Bind this program
		if (current_program != program)
			glUseProgramObjectARB(program);

		// Get the location of name
		if (program == 0)
			throw new Exception("Cannot set uniform variable for a layer with no shader program.");
		char[256] string = 0;
		std.c.stdio.sprintf(string.ptr, "%.*s", name);
		int location = glGetUniformLocationARB(program, string.ptr);
		if (location == -1)
			throw new Exception("Unable to set uniform variable: " ~ name);

		// Send the uniform data
		switch (width)
		{	case 1:  glUniform1fvARB(location, values.length, values.ptr);  break;
			case 2:  glUniform2fvARB(location, values.length, values.ptr);  break;
			case 3:  glUniform3fvARB(location, values.length, values.ptr);  break;
			case 4:  glUniform4fvARB(location, values.length, values.ptr);  break;
			case 16: glUniformMatrix4fvARB(location, values.length, false, values.ptr);  break;
		}

		// Rebind old program
		if (current_program != program)
			glUseProgramObjectARB(current_program);
	}
}
