/**
 * Copyright:  (c) 2006 Eric Poggel
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
	Vec4f	ambient;				/// RGBA ambient color values, default is black.
	Vec4f	diffuse;				/// RGBA diffuse color values, default is white.
	Vec4f	specular;				/// RGBA specular color values, default is black (none).
	Vec4f	emissive;				/// RGBA emissive color values, default is black.
	float	specularity=0;			/// Shininess exponential value, default is zero.

	int		blend = LAYER_BLEND_NONE;/// Type of blending for this Layer
	bool	sort = false;

	int		cull = LAYER_CULL_BACK;
	int		draw = LAYER_DRAW_DEFAULT;
	int		width = 1;

	bool 	clamp	=	false;
	int 	filter	=	TEXTURE_FILTER_DEFAULT;

	protected Horde!(Texture) textures;
	protected Horde!(Shader) shaders;
	protected int program=0;

	static int current_program=0;


	/// Set material properties to default values.
	this()
	{	diffuse.set(1, 1, 1, 1);
		textures = new Horde!(Texture);
		shaders = new Horde!(Shader);
	}

	~this()
	{	if (program != 0)
			glDeleteObjectARB(program);
	}

	/// Get the texture with the given index from this layer.
	Texture getTexture(uint index)
	{	return textures[index];
	}

	/// Get an array of all the textures of this layer.
	Texture[] getTextures()
	{	return textures.array();
	}

	/** Set the given index in the Textures array to texture.
	 *  The index must be valid.  Use addTexture() to add more textures. */
	void setTexture(uint index, Texture texture)
	{	textures[index] = texture;
	}

	/// Add a new texture to this layer and return it.
	int addTexture(Texture texture)
	{	return textures.add(texture);
	}

	/// Remove the texture with the given index from this layer.
	void removeTexture(uint index)
	{	textures.remove(index);
	}

	/**
	 * Return the OpenGL handle to the linked shader program.
	 * This value will most likely be zero unless shaders have been
	 * loaded and linked.*/
	uint getShaderProgram()
	{	return program;
	}

	/**
	 * Add a Shader to this Layer.  Call linkShaders() to recompile the program.
	 * Returns: the index of the new Shader in the Shader array. */
	int addShader(Shader shader)
	{	return shaders.add(shader);
	}

	/// Return the array of shader obects used by this layer.
	Shader[] getShaders()
	{	return shaders.array();
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

	/**
	 * Set all of the OpenGL states to the values of this material layer.
	 * This essentially applies the material.  Call unApply() to reset
	 * the OpenGL states back to the engine defaults in preparation for
	 * whatever will be rendered next.
	 * Params:
	 * lights = An array containing the LightNodes that affect this material,
	 * passed to the shader through uniform variables (unfinished).*/
	void apply(LightNode[] lights = null, Vec4f color = Vec4f(1))
	{

		glMaterialfv(GL_FRONT, GL_AMBIENT, ambient.scale(color).v.ptr);
		glMaterialfv(GL_FRONT, GL_DIFFUSE, diffuse.scale(color).v.ptr);
		glMaterialfv(GL_FRONT, GL_SPECULAR, specular.v.ptr);
		glMaterialfv(GL_FRONT, GL_EMISSION, emissive.scale(color).v.ptr);
		glMaterialfv(GL_FRONT, GL_SHININESS, &specularity);

		// Blending
		if (blend==LAYER_BLEND_AVERAGE)
		{	glEnable(GL_BLEND);
			glDepthMask(false);
			glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
		}
		if (blend==LAYER_BLEND_ADD)
		{	glEnable(GL_BLEND);
			glDepthMask(false);
			glBlendFunc(GL_SRC_ALPHA, GL_ONE);
		}

		// Cull
		if (cull == LAYER_CULL_BACK)
			glCullFace(GL_BACK);
		else
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
		else
			glDisable(GL_TEXTURE_2D);

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

	/// Reset the OpenGL state to the defaults.
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
		glCullFace(GL_FRONT);
		glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
		glDisable(GL_TEXTURE_2D);
		glDepthMask(true);
		if (program != 0)
		{	glUseProgramObjectARB(0);
			current_program = 0;
		}
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
