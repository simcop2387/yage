/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.material;

import tango.util.Convert;
import tango.text.convert.Format;
import tango.io.device.File;
import yage.core.all;
import yage.core.object2;
import yage.resource.texture;
import yage.resource.manager;
import yage.resource.resource;
import yage.resource.shader;
import yage.scene.light;
import yage.system.system;
import yage.system.graphics.probe;
import yage.system.log;

///
class Material
{
	MaterialTechnique[] techniques; ///
	
	///
	this() {};
	
	/**
	 * This is a convenience function to set the value for the first pass of the first technique.
	 * A MaterialTechnique is created and added if none exist. */
	void setPass(MaterialPass pass)
	{	if (!techniques.length)
			techniques ~= new MaterialTechnique();
		if (!techniques[0].passes.length)
			techniques[0].passes ~= pass;
		else
			techniques[0].passes[0] = pass;
	}
	
	/**
	 * Get the first pass of the first technique if it exists, otherwise return null. */
	MaterialPass getPass()
	{	if (techniques.length)
			if (techniques[0].passes.length)
				return techniques[0].passes[0];
		return null;
	}	
}

///
class MaterialTechnique
{	MaterialPass[] passes; ///
}

///
class MaterialPass
{	
	///
	enum Blend {
		NONE,		/// Draw a layer or texture as completely opaque.
		ADD,		/// Add the color values of a layer or texture to those behind it.
		AVERAGE,	/// Average the color values of a layer or texture with those behind it.
		MULTIPLY,	/// Mutiply the color values of a lyer or texture with those behind it.
	}
	
	///
	enum Cull {
		BACK,		/// Cull the back faces of a layer and render the front.
		FRONT,		/// Cull the front faces of a layer and render the back.
		NONE		/// Draw both back and front faces
	}
	
	/// How to draw polygons
	enum Draw {
		FILL,		/// Draw a layer as complete filled-in polygons.
		LINES,		/// Draw a layer as Lines (a wireframe).
		POINTS		/// Draw a layer as a series of points.
	}
	
	/// Type of shader to generate, if the shader property is null
	enum AutoShader
	{	NONE,	/// Used fixed-function rendering or the Pass's Shader property if set.
		PHONG,	/// Per pixel lighting, and if there's a second texture, use it as a normal map
		DETAIL,	/// Per pixel lighting, and if there's a second texture, use it as a detail texture
		// CELL_SHADED
	}
	
	Color diffuse = {r:255, g:255, b:255, a:255};
	Color ambient;
	Color specular;
	Color emissive;
	float shininess = 0;
	bool reflective;		/// Use environment mapping for the texture
	bool lighting = true; 	/// If false, diffuse is used as the color.
	bool flat = false;		/// If true, use flat shading
	float lineWidth = 1;	/// Thickness in pixels of lines and points. 
	Texture[] textures;
	
	Blend blend; /// Loaded from Collada's transparent property.
	Cull cull;
	Draw draw;
		
	Shader shader;
	ShaderUniform[] shaderUniforms;
	AutoShader autoShader = AutoShader.NONE;
	
	void setDiffuseTexture(Texture texture)
	{	if (textures.length < 1)
			textures.length = 1;
		textures[0] = texture;
	}
	
	void setNormalSpecularTexture(Texture texture)
	{	if (textures.length < 2)
			textures.length = 2;
		textures[1] = texture;
	}
}
