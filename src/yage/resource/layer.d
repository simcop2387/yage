/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.layer;

import tango.math.Math;
import tango.io.Stdout;

import yage.core.all;
import yage.system.system;
import yage.system.log;
import yage.system.graphics.probe;
import yage.system.graphics.render;
import yage.core.object2;
import yage.resource.geometry;
import yage.resource.model;
import yage.resource.manager;
import yage.resource.resource;
import yage.resource.shader;
import yage.resource.texture;
import yage.scene.light;

enum {
	// Must also be the bytes per pixel (no longer true?)

	// Settings for blending layers or textures
	BLEND_NONE,					/// Draw a layer or texture as completely opaque.
	BLEND_ADD,					/// Add the color values of a layer or texture to those behind it.
	BLEND_AVERAGE,				/// Average the color values of a layer or texture with those behind it.
	BLEND_MULTIPLY,				/// Mutiply the color values of a lyer or texture with those behind it.

	// Settings for material layers
	LAYER_CULL_BACK,			/// Cull the back faces of a layer and render the front.
	LAYER_CULL_FRONT,			/// Cull the front faces of a layer and render the back.

	LAYER_DRAW_DEFAULT,			// Unsupported
	LAYER_DRAW_FILL,			/// Draw a layer as complete filled-in polygons.
	LAYER_DRAW_LINES,			/// Draw a layer as Lines (a wireframe).
	LAYER_DRAW_POINTS			/// Draw a layer as a series of points.
}

/**
 * This is old code and will be replaced once Collada becomes the default model format.
 * 
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
	
	Color	color;					// necessary for materials with no lights.

	/// Property to set the blending for this Layer.
	int	blend = BLEND_NONE;

	/// Property to set whether the front or back faces of polygons are culled (invisible).
	int	cull = LAYER_CULL_BACK;

	/// Property to set whether the layer is drawn as polygons, lines or points.
	int	draw = LAYER_DRAW_DEFAULT;

	/// Property to set the width of lines and points when the layer is rendered as such.
	int	width = 1;

	public Texture[] textures;
	
	
	Shader shader;
	
	// Deprecated
	int program=0;

	/// Set layer properties to default values.
	this()
	{	ambient = Color("black");
		diffuse = Color("white");
		specular = Color("black");
		emissive = Color("black");
		color = Color("white");
	}

	/// Add a new texture to this layer and return it.
	int addTexture(GPUTexture texture, bool clamp=false, int filter=0)
	{
		return addTexture(Texture(texture, clamp, filter));
	}
	/// ditto
	int addTexture(Texture texture)
	{	textures ~= texture;
		return textures.length;
	}

	/// Return the shader object used by this layer.
	Shader getShader()
	{	return shader;
	}

	/// Get an array of all the textures of this layer.
	Texture[] getTextures()
	{	return textures;
	}

}
