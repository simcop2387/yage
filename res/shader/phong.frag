/**
 * Authors:    Eric Poggel
 * License:    public domain
 * 
 * See documentation for diffuse.vert
 */
 
// Values greater than 1 allow things to be brighter under bright lights
#define MAX_ATTENUATION 12.0

// properties not send by all video cards (buggy drivers?)
// We still rely on default values for light's diffuse and ambient
struct LightInput 
{	vec4 position; // w==0 for directional, w==1 for point light	
	float quadraticAttenuation;
#ifdef HAS_SPOTLIGHT
	vec3 spotDirection;
	float spotCutoff;
	float spotExponent;
#endif
};

// Inputs
#if NUM_LIGHTS > 0
	uniform LightInput lights[NUM_LIGHTS];
#endif
uniform sampler2D tex;
varying vec3 normal, eye_direction, eye_position;
vec3 n, eye_direction_normalized; // renormalized varyings

struct LightResult
{	vec4 ambient;
	vec4 diffuse;
	vec4 specular;
};

LightResult applyLight(gl_LightSourceParameters light, LightInput lightExtra)
{	
	// Vector pointing from vertex to light and dist to light
	vec3 light_direction = lightExtra.position.xyz - eye_position;	
	float light_dist = length(light_direction);	
	light_direction = normalize(light_direction);

	// Attenuation
	float attenuation;
#ifdef HAS_DIRECTIONAL	
	if (lightExtra.position.w==0.0) // if directional
		attenuation = 1.0;
	else
#endif
		attenuation = 1.0 / (lightExtra.quadraticAttenuation * light_dist * light_dist);

	// Spotlight
#ifdef HAS_SPOTLIGHT
	if (lightExtra.spotCutoff < 3.141592)
	{	float spotdot = dot(-light_direction, normalize(lightExtra.spotDirection));
		float cutoff = cos(lightExtra.spotCutoff);
		if (spotdot < cutoff)
			attenuation = 0.0;
		else 			
			attenuation *= pow(spotdot, lightExtra.spotExponent);
	}
#endif

	attenuation = min(attenuation, MAX_ATTENUATION);

	float ndotl;
#ifdef HAS_DIRECTIONAL	
	if (lightExtra.position.w==0.0) // if directional
		ndotl = max(0.0, dot(n, normalize(lightExtra.position.xyz)));
	else
#endif
		ndotl = max(0.0, dot(n, light_direction));
	
	// Accumulate brightness
	LightResult result;
	result.ambient = light.ambient * attenuation;
	result.diffuse = light.diffuse * attenuation * ndotl;

#ifdef HAS_SPECULAR	
	vec3 half_vector = normalize(light_direction + eye_direction_normalized); 
	float ndothv = max(0.0, dot(n, half_vector));
	result.specular = vec4(attenuation * pow(ndothv, gl_FrontMaterial.shininess));
#endif
	return result;
}

void main()
{	
	LightResult lighting;

#if NUM_LIGHTS>0
	n = normalize(normal);
#ifdef HAS_SPECULAR	
	eye_direction_normalized = normalize(eye_direction);
#endif	
	lighting = applyLight(gl_LightSource[0], lights[0]);
	
	for (int i=1; i<NUM_LIGHTS; i++)
	{	LightResult result = applyLight(gl_LightSource[i], lights[i]);
		lighting.ambient += result.ambient;
		lighting.diffuse += result.diffuse;
		lighting.specular += result.specular;
	}
#endif
	
	// Combine lighting and material components
	vec4 ambient  = lighting.ambient * gl_FrontMaterial.ambient;
	vec4 diffuse = lighting.diffuse * gl_FrontMaterial.diffuse;
	vec4 specular = lighting.specular* gl_FrontMaterial.specular;
	
	// gl_FrontLightModelProduct.sceneColor is material.emission + material.ambient * global.ambient
	vec4 color = gl_FrontLightModelProduct.sceneColor + ambient + diffuse;
	color = texture2D(tex, gl_TexCoord[0].st) * color + specular;
	color.a = gl_FrontMaterial.diffuse.a;

#ifdef HAS_FOG
	float fog = clamp(exp(-gl_Fog.density * abs(eye_position.z)), 0.0, 1.0);
	color.rgb = mix(gl_Fog.color.rgb, color.rgb, fog);
#endif

	gl_FragColor = color;
}