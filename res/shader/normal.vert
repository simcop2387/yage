/**
 * Authors:    Eric Poggel
 * License:    public domain
 */

attribute vec4 tangent;
uniform float light_number;

varying vec3 cam_position;
varying vec3 cam_direction;

varying vec3 light_position[3];
varying vec3 light_direction[3];
varying vec3 light_hv[3];

void main()
{
	// Create Matrix to convert from world to texture space
	vec3 normal		= gl_NormalMatrix * gl_Normal * gl_NormalScale;
	vec3 tangent2	= normalize(gl_NormalMatrix * tangent.xyz);
	vec3 binormal	= normalize(cross(normal, tangent2));
	mat3 tsm = (mat3(tangent2.x, binormal.x, normal.x, tangent2.y, binormal.y, normal.y, tangent2.z, binormal.z, normal.z));

	// Calculate light direction for each light in tangent space
	vec4 vertex_position = gl_ModelViewMatrix*gl_Vertex;
	if (light_number >= 1.0)
	{	light_direction[0]	= tsm * (gl_LightSource[0].position.xyz - vertex_position.xyz);
		light_hv[0]			= tsm * gl_LightSource[0].halfVector.xyz;
	}
	if (light_number >= 2.0)
	{	light_direction[1]	= tsm * (gl_LightSource[1].position.xyz - vertex_position.xyz);
		light_hv[1]			= tsm * gl_LightSource[0].halfVector.xyz;
	}

	//light_hv[0] = tangent.xyz;

	// Calculate camera variables, transformed into tangent space
	cam_position	= tsm * (gl_ModelViewMatrix * gl_Vertex).xyz;
	cam_direction	= tsm * -normalize(cam_position);

	// Standard output
	gl_Position = ftransform();
	gl_TexCoord[0].st = gl_MultiTexCoord0.st;
}
