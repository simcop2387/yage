/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Either LGPL or zlib/libpng
 * 
 * Same as diffuse.frag except with max_brightness to allow materials to be
 * brighter than 100%.  This probably requires floating point textures and a
 * few other tricks to be true HDR.
 */

uniform sampler2D tex;
uniform float light_number;

varying vec3 normal, eye_direction, eye_position;
varying float fog;

vec4 ambient, diffuse, specular;
vec3 n;	// renormalized normal

const float max_brightness = 2.5;

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
	float ndotl = max(0.0, dot(n, mix(light.position.xyz, light_direction, light.position.w)));
	float ndothv = max(0.0, dot(n, half_vector));	
	
	// Accumulate brightness
	ambient += light.ambient * attenuation;
	diffuse += light.diffuse * attenuation * ndotl;
	specular += light.specular * attenuation * pow(ndothv, gl_FrontMaterial.shininess);
}

void main()
{	// Start with black
	ambient = vec4(0.0);
	diffuse = vec4(0.0);
	specular= vec4(0.0);
	
	// Renormalize the normal and also get the fragment brightness via dot product
	n = normalize(normal);	
	
	// If Shader runs in software due to not enough temp registers, try commenting out more lights.
	if (light_number >= 1.0)
		applyLight(gl_LightSource[0]);
	if (light_number >= 2.0)
		applyLight(gl_LightSource[1]);
	//if (light_number >= 3.0)
	//	applyLight(gl_LightSource[1]);
	//if (light_number >= 4.0)
	//	applyLight(gl_LightSource[1]);
	
	// Accumulate brigthness
	vec4 color = min(gl_FrontLightModelProduct.sceneColor + ambient*gl_FrontMaterial.ambient + diffuse*gl_FrontMaterial.diffuse, max_brightness);
	color = texture2D(tex, gl_TexCoord[0].st)*color + specular*gl_FrontMaterial.specular;
	
	// Fog
	color = vec4(mix(vec3(gl_Fog.color), vec3(color), fog), color.a);
	
	gl_FragColor = color;
}
