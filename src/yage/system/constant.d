/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * Constants used as parameters to various functions throughout the engine.
 */

module yage.system.constant;

const int DEVICE_FBO					= 100;	/// Hardware support for rendering directly to a texture (Frame Buffer Object)
const int DEVICE_MULTITEXTURE			= 101;	/// Hardware support for using multiple textures in a single rendering pass
const int DEVICE_NON_2_TEXTURE			= 102;	/// Hardware support for textures of arbitrary size
const int DEVICE_SHADER					= 103;	/// Hardware support for openGl vertex and fragment shaders
const int DEVICE_VBO					= 104;	/// Hardware support for caching vertex data in video memory (Vertex Buffer Object)

const int DEVICE_MAX_LIGHTS				= 200;	/// Maximum number of lights that can be used at one time
const int DEVICE_MAX_TEXTURE_SIZE		= 201;	/// Maximum allowed size for a texture
const int DEVICE_MAX_TEXTURES 			= 202;	/// Maximum number of textures that can be used in multitexturing

const int LIGHT_DIRECTIONAL				= 0;	/// A light that shines in one direction through the entire scene
const int LIGHT_POINT					= 1;	/// A light that shines outward in all directions
const int LIGHT_SPOT					= 2;	/// A light that emits light outward from a point in a single direction

const int TEXTURE_FILTER_DEFAULT		= 300;	///
const int TEXTURE_FILTER_NONE			= 301;	///
const int TEXTURE_FILTER_BILINEAR		= 302;	///
const int TEXTURE_FILTER_TRILINEAR		= 303;	///
const int TEXTURE_FILTER_ANISOTROPIC_2	= 304;	// Unsupported
const int TEXTURE_FILTER_ANISOTROPIC_4	= 305;	// Unsupported
const int TEXTURE_FILTER_ANISOTROPIC_8	= 306;	// Unsupported
const int TEXTURE_FILTER_ANISOTROPIC_16	= 307;	// Unsupported

// Must also be the bytes per pixel
const int IMAGE_FORMAT_GRAYSCALE		= 1;	/// A grayscale image
const int IMAGE_FORMAT_RGB				= 3;	/// An image with red, green, and blue color channels
const int IMAGE_FORMAT_RGBA				= 4;	/// An image with Red, green, blue, and alpha color channels

// Settings for blending layers or textures
const int BLEND_NONE					= 400;	/// Draw a layer or texture as completely opaque.
const int BLEND_ADD						= 401;	/// Add the color values of a layer or texture to those behind it.
const int BLEND_AVERAGE					= 402;	/// Average the color values of a layer or texture with those behind it.
const int BLEND_MULTIPLY				= 403;	/// Mutiply the color values of a lyer or texture with those behind it.

// Settings for material layers
const int LAYER_CULL_BACK				= 451;	/// Cull the back faces of a layer and render the front.
const int LAYER_CULL_FRONT				= 452;	/// Cull the front faces of a layer and render the back.

const int LAYER_DRAW_DEFAULT			= 460;	// Unsupported
const int LAYER_DRAW_FILL				= 461;	/// Draw a layer as complete filled-in polygons.
const int LAYER_DRAW_LINES				= 462;	/// Draw a layer as Lines (a wireframe).
const int LAYER_DRAW_POINTS				= 463;	/// Draw a layer as a series of points.
