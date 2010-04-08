/**
 * Authors:    Eric Poggel
 * License:    public domain
 * 
 * See documentation for diffuse.vert
 */
#version 110
 
#define NUM_LIGHTS 1
#define HAS_DIRECTIONAL_LIGHT;
#define HAS_SPOTLIGHT;
#define HAS_SPECULAR;
#define HAS_FOG;

#pragma optimize(off)
#pragma debug(on)

// Values greater than 1 allow things to be brighter under bright lights
#define MAX_ATTENUATION 12.0

// properties not send by all video cards (buggy drivers?)
struct LightInput 
{	float quadraticAttenuation;
};
uniform LightInput lightInput[NUM_LIGHTS];
uniform sampler2D tex;

varying vec3 normal, eye_direction, eye_position;

#ifdef HAS_FOG
varying float fog;
#endif

vec3 n;	// renormalized normal

struct LightResult
{	vec4 ambient;
	vec4 diffuse;
	vec4 specular;
};

// conditionals:  point/directional/spotlight, HAS_SPECULAR
LightResult applyLight(gl_LightSourceParameters light, LightInput lightExtra)
{		
	//light.position.w = 0.0;
	//light.spotCosCutoff = 0.90;

	// Vector pointing from vertex to light and dist to light
	vec3 light_direction = light.position.xyz - eye_position;	
	float light_dist = length(light_direction);	
	light_direction = normalize(light_direction);

	// Attenuation
	float attenuation;
#ifdef HAS_DIRECTIONAL_LIGHT	
	if (light.position.w==0.0) // if directional
		attenuation = 1.0 + lightExtra.quadraticAttenuation/100000000000000000000000.0;
	else
#endif
		attenuation = 1.0 / (lightExtra.quadraticAttenuation * light_dist * light_dist);
	
	// Spotlight
#ifdef HAS_SPOTLIGHT
	//float spotdot = dot(-light_direction, normalize(light.spotDirection));
	float spotdot = dot(-normalize(light.position.xyz - eye_position), normalize(light.spotDirection));
	if (spotdot > light.spotCosCutoff)
		attenuation *= pow(spotdot, light.spotExponent);
	else
		attenuation = 0.0;
#endif

	attenuation = min(attenuation, MAX_ATTENUATION);
	
	// Half vector and dot products (is the half-vector incorrect for directional lights)?	
	float ndotl;
#ifdef HAS_DIRECTIONAL_LIGHT	
	if (light.position.w==0.0) // if directional
		ndotl = max(0.0, dot(n, normalize(light.position.xyz)));
	else
#endif
		ndotl = max(0.0, dot(n, light_direction));
	
	// Accumulate brightness
	LightResult result;
	result.ambient = light.ambient * attenuation;
	result.diffuse = light.diffuse * attenuation * ndotl;

#ifdef HAS_SPECULAR	
	vec3 half_vector; 
#ifdef HAS_DIRECTIONAL_LIGHT	
	if (light.position.w==0.0) // if directional 
		half_vector = normalize(light_direction + eye_direction);
	else
#endif
		half_vector = light.halfVector.xyz;
	float ndothv = max(0.0, dot(n, half_vector));
	result.specular = vec4(1) * attenuation * pow(ndothv, gl_FrontMaterial.shininess);
#endif
	return result;
}

void main()
{	
	// Start with black
	LightResult lighting;

#if NUM_LIGHTS>0
	n = normalize(normal);
	lighting = applyLight(gl_LightSource[0], lightInput[0]);
	
	for (int i=1; i<NUM_LIGHTS; i++)
	{	LightResult result = applyLight(gl_LightSource[i], lightInput[i]);
		lighting.ambient += result.ambient;
		lighting.diffuse += result.diffuse;
		lighting.specular += result.specular;
	}
#endif
	
	// Combine lighting components
	vec4 ambient  = lighting.ambient * gl_FrontMaterial.ambient;
	vec4 diffuse = lighting.diffuse * gl_FrontMaterial.diffuse;
	vec4 specular = lighting.specular* gl_FrontMaterial.specular;
	
	// gl_FrontLightModelProduct.sceneColor is material.emission + material.ambient * global.ambient
	vec4 color = gl_FrontLightModelProduct.sceneColor + ambient + diffuse;
	color = texture2D(tex, gl_TexCoord[0].st) * color + specular;

	color.a = gl_FrontMaterial.diffuse.a;
	gl_FragColor = color;
}
