/**
 * Authors:    Eric Poggel
 * License:    public domain
 * 
 * This shader re-invents the fixed-function OpenGL vertex and fragment
 * pipeline except with per-pixel lighting.  It suports fog and up to 2
 * lights of type point, spot, or directional.
 */
 
uniform float fog_enabled;

varying vec3 normal, eye_direction, eye_position;
varying float fog;

void main()
{	// Vertex normal, eye position, and eye direction
	normal = (gl_NormalMatrix * gl_Normal) * gl_NormalScale;
	eye_position = (gl_ModelViewMatrix * gl_Vertex).xyz;
	eye_direction = -normalize(eye_position.xyz);

	// if (fog_enabled) then clamp(...), else 1.0
	fog = mix(1.0, clamp(exp(-gl_Fog.density * abs(eye_position.z)), 0.0, 1.0), fog_enabled);

	gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	gl_Position = ftransform();
} 