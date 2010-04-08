/**
 * Authors:    Eric Poggel
 * License:    public domain
 *
 * This shader re-invents the fixed-function OpenGL vertex and fragment
 * pipeline except with per-pixel lighting.  It suports fog and up to 2
 * lights of type point, spot, or directional.
 */
 #version 110
 
#define NUM_LIGHTS 1
#define HAS_DIRECTIONAL_LIGHT;
#define HAS_SPOTLIGHT;
#define HAS_SPECULAR;
#define HAS_FOG;

#pragma optimize(off)
#pragma debug(on)

varying vec3 normal, eye_direction;
#ifdef HAS_SPOTLIGHT
	varying vec3 eye_position;
#endif

#ifdef HAS_FOG
varying float fog;
#endif

void main()
{	// Vertex normal, eye position, and eye direction
	normal = (gl_NormalMatrix * gl_Normal) * gl_NormalScale;
#ifdef HAS_SPOTLIGHT
	vec4 eyePositionTemp = gl_ModelViewMatrix * gl_Vertex;
	eye_position = vec3(eyePositionTemp) / eyePositionTemp.w;
#endif
	eye_direction = -normalize(eye_position);

#ifdef HAS_FOG
	fog = clamp(exp(-gl_Fog.density * abs(eye_position.z)), 0.0, 1.0);
#endif

	gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	gl_Position = ftransform();
}
