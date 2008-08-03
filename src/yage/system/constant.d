/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * Constants used as parameters to various functions throughout the engine.
 * TODO: Define these as enums in the places where they are used?
 */
	
module yage.system.constant;
enum {
	DEVICE_FBO,					/// Hardware support for rendering directly to a texture (Frame Buffer Object)
	DEVICE_MULTITEXTURE,		/// Hardware support for using multiple textures in a single rendering pass
	DEVICE_NON_2_TEXTURE,		/// Hardware support for textures of arbitrary size
	DEVICE_SHADER,				/// Hardware support for openGl vertex and fragment shaders
	DEVICE_VBO,					/// Hardware support for caching vertex data in video memory (Vertex Buffer Object)
	DEVICE_BLEND_COLOR,

	DEVICE_MAX_LIGHTS,			/// Maximum number of lights that can be used at one time
	DEVICE_MAX_TEXTURE_SIZE,	/// Maximum allowed size for a texture
	DEVICE_MAX_TEXTURES,		/// Maximum number of textures that can be used in multitexturing

	LIGHT_DIRECTIONAL,			/// A light that shines in one direction through the entire scene
	LIGHT_POINT,				/// A light that shines outward in all directions
	LIGHT_SPOT,					/// A light that emits light outward from a point in a single direction

	TEXTURE_FILTER_DEFAULT,		///
	TEXTURE_FILTER_NONE,		///
	TEXTURE_FILTER_BILINEAR,	///
	TEXTURE_FILTER_TRILINEAR,	///
	TEXTURE_FILTER_ANISOTROPIC_2,	// Unsupported
	TEXTURE_FILTER_ANISOTROPIC_4,	// Unsupported
	TEXTURE_FILTER_ANISOTROPIC_8,	// Unsupported
	TEXTURE_FILTER_ANISOTROPIC_16,	// Unsupported

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