/**
 * Copyright:  (c) 2006-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * Constants used as parameters to various functions throughout the engine.
 */

module yage.system.constant;

const int DEVICE_SHADER					= 100;	/// Hardware support for OpenGl Vertex and Fragment Shaders
const int DEVICE_VBO					= 101;	/// Hardware support for caching vertex data in video memory (Vertex Buffer Object)
const int DEVICE_NON_2_TEXTURE			= 102;	/// Hardware support for textures of arbitrary size.

const int DEVICE_MAX_LIGHTS				= 200;	///
const int DEVICE_MAX_TEXTURE_SIZE		= 201;	///
const int DEVICE_MAX_TEXTURE_UNITS 		= 202;	///

const int LIGHT_DIRECTIONAL				= 0;	/// A light that shines in one direction through the entire scene.
const int LIGHT_POINT					= 1;	/// A light that shines outward in all directions.
const int LIGHT_SPOT					= 2;	/// A light that emits light outward from a point in a single direction.

const int TEXTURE_FILTER_DEFAULT		= 300;	///
const int TEXTURE_FILTER_NONE			= 301;	///
const int TEXTURE_FILTER_BILINEAR		= 302;	///
const int TEXTURE_FILTER_TRILINEAR		= 303;	///
const int TEXTURE_FILTER_ANISOTROPIC_2	= 304;	//
const int TEXTURE_FILTER_ANISOTROPIC_4	= 305;	//
const int TEXTURE_FILTER_ANISOTROPIC_8	= 306;	//
const int TEXTURE_FILTER_ANISOTROPIC_16	= 307;	//

// Must also be the bytes per pixel
const int IMAGE_FORMAT_GRAYSCALE		= 1;	/// A grayscale image.
const int IMAGE_FORMAT_RGB				= 3;	/// An image with red, green, and blue color channels.
const int IMAGE_FORMAT_RGBA				= 4;	/// An image with Red, green, blue, and alpha color channels.

// Settings for material layers
const int LAYER_BLEND_NONE				= 400;	/// Draw a layer as completely opaque
const int LAYER_BLEND_ADD				= 401;	/// Add the color values of a Layer to those behind it.
const int LAYER_BLEND_AVERAGE			= 402;	/// Average the color values of a Layer with those behind it.
const int LAYER_BLEND_MULTIPLY			= 403;	/// Mutiply the color values of a Layer with those behind it.

const int LAYER_CULL_BACK				= 451;	/// Cull the back faces of a Layer and render the front.
const int LAYER_CULL_FRONT				= 452;	/// Cull the front faces of a Layer and render the back.

const int LAYER_DRAW_DEFAULT			= 460;	//
const int LAYER_DRAW_FILL				= 461;	/// Draw a Layer as complete filled-in polygons.
const int LAYER_DRAW_LINES				= 462;	/// Draw a Layer as Lines (a wireframe).
const int LAYER_DRAW_POINTS				= 463;	/// Draw a Layer as a series of points.
