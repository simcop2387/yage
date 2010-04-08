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
		PHONG,	/// Per pixel lighting, but no normal map.
		NORMAL,	/// Use the second texture as a normal map.
		DETAIL_MAP /// Use the second texture as a detail map.
		// CELL_SHADED
	}
	
	Color diffuse = {r:255, g:255, b:255, a:255};
	Color ambient;
	Color specular;
	Color emissive;
	float shininess = 0;
	bool reflective;		/// Use environment mapping for the texture
	bool lighting = true; 	/// If false, diffuse is used as the color.
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

class ShaderGenerator
{

	
	/// TODO: Create a cache to always return the same obect instance for the same shader.
	static Shader generate(MaterialPass pass, LightNode[] lights, bool fog=false)
	{
		// Use fixed function rendering, return null.
		if (pass.autoShader == MaterialPass.AutoShader.NONE)
			return null;
		
		
		bool hasDirectionalLight, hasSpotlight;
		foreach (light; lights)
		{	hasDirectionalLight = hasDirectionalLight ||  (light.type == LightNode.Type.DIRECTIONAL);
			hasSpotlight = hasSpotlight || (light.type == LightNode.Type.SPOT);
		}
		bool hasSpecular = pass.specular != Color("black"); // TODO need a way to ignore alpha in comparrison
		
		
		char[] vertex, fragment;
		
		if (pass.autoShader == MaterialPass.AutoShader.PHONG)
		{
			// Create vertex shader
			vertex =
				"varying vec3 normal, eye_direction, eye_position;\n";
			if (fog)
				vertex ~= "varying float fog;\n";
			vertex ~=
				"void main()\n" ~
				"{	normal = (gl_NormalMatrix * gl_Normal) * gl_NormalScale;\n" ~
				"	eye_position = (gl_ModelViewMatrix * gl_Vertex).xyz;\n" ~
				"	eye_direction = -normalize(eye_position);\n";
			if (fog)
				vertex ~= "fog = clamp(exp(-gl_Fog.density * abs(eye_position.z)), 0.0, 1.0);\n";
			vertex ~=
				"	gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;\n" ~
				"	gl_Position = ftransform();\n" ~
				"}";
			
			// Fragment shader
			
		}
		
		
		return new Shader(vertex, fragment);
	}
	
}

