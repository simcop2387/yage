/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Either LGPL or zlib/libpng
 * 
 * This shader re-invents the fixed-function OpenGL vertex and fragment
 * pipeline as closely as possible.  It does use a few odd hacks here and there
 * to get around shader limitations on older cards and only implements up to 5
 * lights for the same reason.  This shader doesn't really have a practical use
 * but can be used as a base to write more complex shaders and also as a
 * learning tool.
 */

uniform float light_number;
uniform float fog_enabled;

vec4 ambient;
vec4 diffuse;
vec4 specular;

varying float fog;

vec3 eye_direction, eye_position, normal;

/**
 * Apply light as either a point, spot, or directinal light depending on light.spotCutoff and light.position.w */
void applyLight(gl_LightSourceParameters light)
{
	// Vector pointing from vertex to light and dist to light
	vec3 light_direction = vec3(light.position) - eye_position;	
	float light_dist = length(light_direction);	
	light_direction = normalize(light_direction);

	// Attenuation
	float attenuation= 1.0/(light.constantAttenuation +
							light.linearAttenuation * light_dist +
							light.quadraticAttenuation * light_dist * light_dist);
	// No attenuation for directional lights
	attenuation = mix(1.0, attenuation, light.position.w);
	
	// Spotlight
	float spotdot = dot(-light_direction, normalize(light.spotDirection));
	attenuation = attenuation*pow(spotdot, light.spotExponent) * float(spotdot>=light.spotCosCutoff);
	
	// Half vector and dot products (is the half-vector incorrect for directional lights)?
	vec3 half_vector = mix(light.halfVector.xyz, normalize(light_direction + eye_direction), light.position.w);	
	float ndotl = max(0.0, dot(normal, mix(light.position.xyz, light_direction, light.position.w)));
	float ndothv = max(0.0, dot(normal, half_vector));	
	
	// Accumulate brightness
	ambient += light.ambient * attenuation;
	diffuse += light.diffuse * attenuation * ndotl;
	specular += light.specular * attenuation * pow(ndothv, gl_FrontMaterial.shininess);
}

void main()
{
	// Vertex normal and eye position
	normal = (gl_NormalMatrix * gl_Normal) * gl_NormalScale;
	eye_position = vec3(gl_ModelViewMatrix * gl_Vertex);
	eye_direction = -normalize(eye_position.xyz);
	
	// Start with black
	ambient = vec4(0.0);
	diffuse = vec4(0.0);
	specular= vec4(0.0);

	// If Shader runs in software due to not enough temp registers, try commenting out more lights.
	if (light_number >= 1.0)
		applyLight(gl_LightSource[0]);
	if (light_number >= 2.0)		
		applyLight(gl_LightSource[1]);
	if (light_number >= 3.0)
		applyLight(gl_LightSource[2]);
	if (light_number >= 4.0)
		applyLight(gl_LightSource[3]);
	if (light_number >= 5.0)
		applyLight(gl_LightSource[4]);
	//if (light_number >= 6.0)
	//	applyLight(gl_LightSource[5]);		
		
	// Color
	gl_FrontColor = min(gl_FrontLightModelProduct.sceneColor + ambient*gl_FrontMaterial.ambient + diffuse*gl_FrontMaterial.diffuse, 1.0);
	gl_FrontSecondaryColor = vec4(specular.rgb * gl_FrontMaterial.specular.rgb, 1.0); // SEPARATE_SPECULAR_COLOR_EXT from OpenGL 1.2
	
	// if (fog_enabled) then clamp(...), else 1.0
	fog = mix(1.0, clamp(exp(-gl_Fog.density * abs(eye_position.z)), 0.0, 1.0), fog_enabled);
	
	// Vertex texture and position coordinates
	gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	gl_Position = ftransform();		// same as gl_ModelViewProjectionMatrix * gl_Vertex
	

}