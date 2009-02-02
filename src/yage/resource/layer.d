/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.layer;

import tango.math.Math;
import std.string;

import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.all;
import yage.system.constant;
import yage.system.system;
import yage.system.log;
import yage.system.probe;
import yage.system.render;
import yage.core.exceptions;
import yage.resource.geometry;
import yage.resource.model;
import yage.resource.manager;
import yage.resource.resource;
import yage.resource.shader;
import yage.resource.texture;
import yage.scene.light;


// Used as default values for function params
private const Vec2f one = {v:[1.0f, 1.0f]};
private const Vec2f zero = {v:[0.0f, 0.0f]};

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
class Layer : Resource
{
	Color	ambient;				/// Property for the RGBA ambient layer color, default is Vec4f(0).
	Color	diffuse;				/// Property for the RGBA diffuse layer color, default is Vec4f(1).
	Color	specular;				/// Property for the RGBA specular layer color, default is Vec4f(0).
	Color	emissive;				/// Property for the RGBA emissive layer color, default is Vec4f(0).
	float	specularity=0;			/// Shininess exponential value, default is zero (no shininess).

	/// Property to set the blending for this Layer.
	/// See_Also: the LAYER_BLEND_* constants in yage.system.constant;
	int	blend = BLEND_NONE;

	/// Property to set whether the front or back faces of polygons are culled (invisible).
	/// See_Also: the LAYER_CULL_* constants in yage.system.constant
	int	cull = LAYER_CULL_BACK;

	/// Property to set whether the layer is drawn as polygons, lines or points.
	/// See_Also: the LAYER_DRAW_* constants in yage.system.constant
	int	draw = LAYER_DRAW_DEFAULT;

	/// Property to set the width of lines and points when the layer is rendered as such.
	int	width = 1;

	// private
	protected Texture[] textures;
	protected Shader[] shaders;
	protected int program=0;
	protected static int current_program=0;


	/// Set layer properties to default values.
	this()
	{	ambient = Color("black");
		diffuse = Color("white");
		specular = Color("black");
		emissive = Color("black");
	}

	~this()
	{	if (program != 0)
			glDeleteObjectARB(program);
	}

	/**
	 * Add a Shader to this Layer.  Call linkShaders() to recompile the program.
	 * Returns: the index of the new Shader in the Shader array. */
	int addShader(Shader shader)
	{	shaders ~= shader;
		return shaders.length; 
	}

	/// Add a new texture to this layer and return it.
	int addTexture(GPUTexture texture, bool clamp=false, int filter=TEXTURE_FILTER_DEFAULT,
				Vec2f position=zero, float rotation=0, Vec2f scale=one)
	{
		return addTexture(Texture(texture, clamp, filter, position, rotation, scale));
	}
	/// ditto
	int addTexture(Texture texture)
	{	textures ~= texture;
		return textures.length;
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
	{	return shaders;
	}

	/// Get an array of all the textures of this layer.
	Texture[] getTextures()
	{	return textures;
	}

	///
	int getProgram()
	{	return program;
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

	/// Link all vertex and fragment shaders together into a shader program.
	void linkShaders()
	{
		if (program != 0)
			glDeleteObjectARB(program);

		// Don't do anything if we have no shaders
		if (shaders.length ==0)
			return;
		program = glCreateProgramObjectARB();

		// Add shaders to the program
		foreach (Shader shader; shaders)
		{	glAttachObjectARB(program, shader.getShader());
			Log.write("Linking shader ", shader.getSource());
		}

		// Link the program and check for errors
		int status;
		try {
			glLinkProgramARB(program);
		} catch { Log.write("Link Failed");}
		glGetObjectParameterivARB(program, GL_OBJECT_LINK_STATUS_ARB, &status);
		if (!status)
		{	Log.write(getShaderProgramLog());
			throw new ResourceManagerException("Could not link the shaders.");
		}
		glValidateProgramARB(program);
		Log.write(getShaderProgramLog());
		Log.write("Linking successful.");
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
			" ambient=\"" ~ ambient.hex ~ "\"" ~
			" diffuse=\"" ~ diffuse.hex ~ "\"" ~
			" specular=\"" ~ specular.hex ~ "\"" ~
			" emissive=\"" ~ emissive.hex ~ "\"" ~
			" specularity=\"" ~ .toString(specularity) ~ "\"" ~
		//	" blend=\"" ~ .toString(blend) ~ "\"" ~
		//	" cull=\"" ~ .toString(cull) ~ "\"" ~
			" draw=\"" ~ .toString(draw) ~ "\"" ~
			" width=\"" ~ .toString(width) ~ "\"" ~
			">\n";
			foreach (Shader s; shaders)
				result~= s.toString();
			//foreach (TextureInstance t; textures)
			//	result~= t.toString();
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
	 * This function is used internally by the engine and doesn't normally need to be called.
	 * color = Used to set color on a per-instance basis, combined with existing material colors.
	 * Model = Used to retrieve texture coordinates for multitexturing. */
	void bind(LightNode[] lights = null, Color color = Color("white"), Geometry model=null)
	{
		// Material
		glMaterialfv(GL_FRONT, GL_AMBIENT, ambient.vec4f.scale(color.vec4f).v.ptr);
		glMaterialfv(GL_FRONT, GL_DIFFUSE, diffuse.vec4f.scale(color.vec4f).v.ptr);
		glMaterialfv(GL_FRONT, GL_SPECULAR, specular.vec4f.scale(color.vec4f).v.ptr);
		glMaterialfv(GL_FRONT, GL_EMISSION, emissive.vec4f.scale(color.vec4f).v.ptr);
		glMaterialfv(GL_FRONT, GL_SHININESS, &specularity);

		// Blend
		if (blend != BLEND_NONE)
		{	glEnable(GL_BLEND);
			glDepthMask(false);
			switch (blend)
			{	case BLEND_ADD:
					glBlendFunc(GL_ONE, GL_ONE);
					break;
				case BLEND_AVERAGE:
					glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
					//glBlendFuncSeparateEXT(GL_SRC_COLOR, GL_ONE_MINUS_SRC_COLOR, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
					break;
				case BLEND_MULTIPLY:
					glBlendFunc(GL_ZERO, GL_SRC_COLOR);
					break;
		}	}
		else
			glEnable(GL_ALPHA_TEST);


		// Cull
		if (cull == LAYER_CULL_FRONT)
			glCullFace(GL_FRONT);

		// Polygon
		switch (draw)
		{	default:
			case LAYER_DRAW_FILL:
				glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
				break;
			case LAYER_DRAW_LINES:
				glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
				glLineWidth(width);
				break;
			case LAYER_DRAW_POINTS:
				glPolygonMode(GL_FRONT_AND_BACK, GL_POINT);
				glPointSize(width);
				break;
		}

		// Textures
		if (textures.length>1 && Probe.openGL(Probe.OpenGL.MULTITEXTURE))
		{	int length = min(textures.length, Probe.openGL(Probe.OpenGL.MAX_TEXTURE_UNITS));

			// Loop through all of Layer's textures up to the maximum allowed.
			for (int i=0; i<length; i++)
			{	int GL_TEXTUREI_ARB = GL_TEXTURE0_ARB+i;

				// Activate texture unit and enable texturing
				glActiveTextureARB(GL_TEXTUREI_ARB);
				glEnable(GL_TEXTURE_2D);
				glClientActiveTextureARB(GL_TEXTUREI_ARB);

				// Set texture coordinates
				IVertexBuffer texcoords = model.getTexCoords0();
				if (Probe.openGL(Probe.OpenGL.VBO))
				{	glBindBufferARB(GL_ARRAY_BUFFER, texcoords.getId());
					glTexCoordPointer(texcoords.getComponents(), GL_FLOAT, 0, null);
				} else
					glTexCoordPointer(texcoords.getComponents(), GL_FLOAT, 0, texcoords.ptr);

				// Bind and blend
				textures[i].bind();
			}
		}
		else if(textures.length == 1){
			glEnable(GL_TEXTURE_2D);
			textures[0].bind();
		}

		// Shader
		if (program != 0)
		{	glUseProgramObjectARB(program);
			current_program = program;

			// Try to light and fog variables?
			try {	// bad for performance?
				setUniform("light_number", lights.length);
			} catch{}
			try {
				setUniform("fog_enabled", cast(float)Render.getCurrentCamera().getScene().getFogEnabled());
			} catch{}

			// Enable
			for (int i=0; i<textures.length; i++)
			{	if (textures[i].name.length)
				{	char[256] cname = 0;
					cname[0..textures[i].name.length]= textures[i].name;
					int location = glGetUniformLocationARB(program, cname.ptr);
					if (location == -1)
					{}//	throw new Exception("Warning:  Unable to set texture sampler: " ~ textures[i].name);
					else
						glUniform1iARB(location, i);
			}	}
/*
			// Attributes
			foreach (name, attrib; model.getAttributes())
			{	int location = glGetAttribLocation(program, toStringz(name));
				if (location != -1)
				{


					if (model.getCached())
					{	// This works as is, don't yet know why
						//int vbo;
						//glBindBufferARB(GL_ARRAY_BUFFER, vbo);

						glEnableVertexAttribArray(location);
						glBindBuffer(GL_ARRAY_BUFFER_ARB, attrib.index);
						glVertexAttribPointer(location, 4, GL_FLOAT, false, 0, null);

						writefln(1);
						void **values;
						glGetVertexAttribPointerARB(location, program, values);
						writefln(2);
						//writefln(values[0..attrib.values.length]);
					}
					else
					{	glEnableVertexAttribArray(location);
						glVertexAttribPointer(location, 4, GL_FLOAT, false, 0, &attrib.values[0]);
					}
				}

			}
*/
			/*
			//glBufferDataARB(GL_ARRAY_BUFFER, values.length*Vec3f.sizeof, values.ptr, GL_STATIC_DRAW);
			//glBindBufferARB( GL_ARRAY_BUFFER_ARB, vbo);
			//glVertexAttribPointerARB(location, 4, GL_FLOAT, 0, 0, null);

			// Attributes
			// Apparently attributes have to be used as vbo's if vertices are also
			foreach (name, values; model.getAttributes())
			{	int location = glGetAttribLocation(program, toStringz(name));

				if (location != -1)
				{	int vbo;
					glBindBufferARB(GL_ARRAY_BUFFER, vbo);
					glEnableVertexAttribArray(location);
					glVertexAttribPointer(location, 4, 0x1406, false, 0, &values[0]);
				}
			}
			*/
		}
	}

	/*
	 * Reset the OpenGL state to the defaults.
	 * This function is used internally by the engine and doesn't normally need to be called. */
	void unbind()
	{
		// Material
		float s=0;
		glMaterialfv(GL_FRONT, GL_AMBIENT, Vec4f().v.ptr);
		glMaterialfv(GL_FRONT, GL_DIFFUSE, Vec4f(1).v.ptr);
		glMaterialfv(GL_FRONT, GL_SPECULAR, Vec4f().v.ptr);
		glMaterialfv(GL_FRONT, GL_EMISSION, Vec4f().v.ptr);
		glMaterialfv(GL_FRONT, GL_SHININESS, &s);

		// Blend
		if (blend != BLEND_NONE)
		{	glDisable(GL_BLEND);
			glDepthMask(true);
		}else
			glDisable(GL_ALPHA_TEST);


		// Cull, polygon
		glCullFace(GL_BACK);
		glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);

		// Textures
		if (textures.length>1 && Probe.openGL(Probe.OpenGL.VBO))
		{	int length = min(textures.length, Probe.openGL(Probe.OpenGL.MAX_TEXTURE_UNITS));

			for (int i=length-1; i>=0; i--)
			{	glActiveTextureARB(GL_TEXTURE0_ARB+i);
				glDisable(GL_TEXTURE_2D);

				if (textures[i].reflective)
				{	glDisable(GL_TEXTURE_GEN_S);
					glDisable(GL_TEXTURE_GEN_T);
				}
				glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
				textures[i].unbind();
			}
			glClientActiveTextureARB(GL_TEXTURE0_ARB);
		}
		else if(textures.length == 1){	textures[0].unbind();
			glDisable(GL_TEXTURE_2D);
			//glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
		}

		// Shader
		if (program != 0)
		{	glUseProgramObjectARB(0);
			current_program = 0;

			// Attributes
			/*
			glDisableVertexAttribArrayARB(0);
			glDisableVertexAttribArrayARB(1);
			glDisableVertexAttribArrayARB(2);
			glDisableVertexAttribArrayARB(3);
			glDisableVertexAttribArrayARB(4);
			*/
		}
	}

	// Helper function for the public setUniform() functions.
	protected void setUniform(char[] name, int width, float[] values)
	{	if (!Probe.openGL(Probe.OpenGL.SHADER))
			throw new ResourceManagerException("Layer.setUniform() is only supported on hardware that supports shaders.");

		// Bind this program
		if (current_program != program)
			glUseProgramObjectARB(program);

		// Get the location of name
		if (program == 0)
			throw new ResourceManagerException("Cannot set uniform variable for a layer with no shader program.");
		char[256] cname = 0;
		cname[0..name.length] = name;
		int location = glGetUniformLocationARB(program, cname.ptr);
		if (location == -1)
			throw new ResourceManagerException("Unable to set uniform variable: " ~ name);

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
