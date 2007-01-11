/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * Constants used throughout the entire engine.
 */

module yage.system.constant;


const int DEVICE_SHADER					= 100;
const int DEVICE_VBO					= 101;
const int DEVICE_NON_2_TEXTURE			= 102;

const int DEVICE_MAX_LIGHTS				= 200;
const int DEVICE_MAX_TEXTURE_SIZE		= 201;
const int DEVICE_MAX_TEXTURE_UNITS 		= 202;

const int LIGHT_DIRECTIONAL				= 0;	/// The light shines in one direction through the entire scene.
const int LIGHT_POINT					= 1;	/// The light shines outward in all directions.
const int LIGHT_SPOT					= 2;	/// The light emits light outward from a point in a single direction.

const int TEXTURE_FILTER_DEFAULT		= 300;
const int TEXTURE_FILTER_NONE			= 301;
const int TEXTURE_FILTER_BILINEAR		= 302;
const int TEXTURE_FILTER_TRILINEAR		= 303;
const int TEXTURE_FILTER_ANISOTROPIC_2	= 304;
const int TEXTURE_FILTER_ANISOTROPIC_4	= 305;
const int TEXTURE_FILTER_ANISOTROPIC_8	= 306;
const int TEXTURE_FILTER_ANISOTROPIC_16	= 307;

// Must also be the bytes per pixel
const int IMAGE_FORMAT_GRAYSCALE		= 1;
const int IMAGE_FORMAT_RGB				= 3;
const int IMAGE_FORMAT_RGBA				= 4;

const int LAYER_BLEND_NONE				= 400;	// default
const int LAYER_BLEND_ADD				= 401;
const int LAYER_BLEND_AVERAGE			= 402;
const int LAYER_BLEND_MULTIPLY			= 403;

const int LAYER_CULL_BACK				= 451;
const int LAYER_CULL_FRONT				= 452;

const int LAYER_DRAW_DEFAULT			= 460;
const int LAYER_DRAW_FILL				= 461;
const int LAYER_DRAW_LINES				= 462;
const int LAYER_DRAW_POINTS				= 463;
