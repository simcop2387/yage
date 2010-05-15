/**
 * Authors:    Eric Poggel
 * License:    public domain
 *
 * This shader re-invents the fixed-function OpenGL vertex and fragment
 * pipeline except with per-pixel lighting.  It suports fog and up to 2
 * lights of type point, spot, or directional.
 */

varying vec3 normal, eye_direction, eye_position;

void main()
{	// Vertex normal, eye position, and eye direction
	normal = (gl_NormalMatrix * gl_Normal) * gl_NormalScale;

	vec4 eyePositionTemp = gl_ModelViewMatrix * gl_Vertex;
	eye_position = vec3(eyePositionTemp) / eyePositionTemp.w;
	eye_direction = -normalize(eye_position);

	gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	gl_Position = ftransform();
}