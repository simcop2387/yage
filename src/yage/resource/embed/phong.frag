#line 1
/**
 * Authors:    Eric Poggel
 * License:    public domain
 * 
 * See documentation for diffuse.vert
 */
 
// Values greater than 1 allow things to be brighter than their material color
#define MAX_ATTENUATION 4.0

// temporary, testing
//#undef HAS_FOG 
//#undef HAS_BUMP
//#undef HAS_SPECULAR
#pragma debug(on)
#pragma optimize(off)

// Light properties not send by all video cards (buggy drivers?)
// We still rely on default values for light's diffuse and ambient
struct Light 
{	vec4 position; // w==0 for directional, w==1 for point light	
	float quadraticAttenuation;
#ifdef HAS_SPOTLIGHT
	vec3 spotDirection;
	float spotCutoff;
	float spotExponent;
#endif
};

// Uniforms
#if NUM_LIGHTS > 0
	uniform Light lights[NUM_LIGHTS];
#endif
uniform sampler2D texture0;
uniform sampler2D texture1;

// Varying
#if NUM_LIGHTS > 0
	varying vec3 light_directions[NUM_LIGHTS];
#endif
varying vec3 normal;
varying vec3 eye_direction;
varying vec3 eye_position;

// Globals
vec3 normal2;
vec3 eye_direction_normalized; // renormalized varyings

struct LightResult
{	vec4 ambient;
	vec4 diffuse;
	vec4 specular;
};

/**
 * Get the ambient, diffuse, and specular contribution of this light to the current fragment.
 * @param light OpenGL lighting parameters.  Experimentation has shown that ony some of these are reliable on ATI.
 * @param lightExtra Additional lighting parameters to supplement the unreliable values of the first parameter.
 * @param lightDirection Un-normalized direction to the light. */
LightResult applyLight(in gl_LightSourceParameters light, in Light lightExtra, vec3 light_direction)
{	
	// Vector pointing from vertex to light and distance to light
	float light_distance = length(light_direction);	
	light_direction = light_direction / light_distance; // normalize

	// Attenuation
	float attenuation;
#ifdef HAS_DIRECTIONAL	
	if (lightExtra.position.w==0.0) // if directional
		attenuation = 1.0;
	else
#endif
		attenuation = 1.0 / (lightExtra.quadraticAttenuation * light_distance * light_distance);

	// Spotlight
#ifdef HAS_SPOTLIGHT
	if (lightExtra.spotCutoff < 3.141592)
	{	// we have to recalculate lightDirection because the other one is in tangent space.
		#ifdef HAS_BUMP
			vec3 lightDirection = normalize((lightExtra.position.xyz - eye_position));
		#else
			vec3 lightDirection = light_direction;
		#endif
		float spotdot = dot(-lightDirection, normalize(lightExtra.spotDirection));
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
		ndotl = max(0.0, dot(normal2, normalize(lightExtra.position.xyz)));
	else
#endif
		ndotl = max(0.0, dot(normal2, light_direction));
	
	// Accumulate brightness
	LightResult result;
	result.ambient = light.ambient * attenuation;
	result.diffuse = light.diffuse * attenuation * ndotl;

#ifdef HAS_SPECULAR	
	vec3 half_vector = normalize(light_direction + eye_direction_normalized); // light_direction is already normalized
	float ndothv = max(0.0, dot(normal2, half_vector));
	result.specular = vec4(attenuation * pow(ndothv, gl_FrontMaterial.shininess));
#endif

	return result;
}


void main()
{	
	LightResult lighting;

#if NUM_LIGHTS>0

#ifdef HAS_BUMP
	vec4 bumpNormal = texture2D(texture1, gl_TexCoord[0].st);
	bumpNormal.xyz = 2.0 * bumpNormal.xyz - 1.0;
	normal2 = normalize(bumpNormal.xyz); // since the lights are in tangent space, we can use this directly.
#else
	normal2 = normalize(normal);
#endif

#ifdef HAS_SPECULAR	
	eye_direction_normalized = normalize(eye_direction);
#endif	
	lighting = applyLight(gl_LightSource[0], lights[0], light_directions[0]);
	
	for (int i=1; i<NUM_LIGHTS; i++)
	{	LightResult result = applyLight(gl_LightSource[i], lights[i], light_directions[i]);
		lighting.ambient += result.ambient;
		lighting.diffuse += result.diffuse;
		#ifdef HAS_SPECULAR	
			lighting.specular += result.specular;
		#endif
	}
#endif
	
	// Combine lighting and material components
	vec4 ambient = lighting.ambient * gl_FrontMaterial.ambient;
	vec4 diffuse = lighting.diffuse * gl_FrontMaterial.diffuse;
#ifdef HAS_SPECULAR	
	vec4 specular = lighting.specular * gl_FrontMaterial.specular;
	#ifdef HAS_BUMP
		specular*= bumpNormal.a; // this fails for bump maps with no alpha channel, I probably need to redo the assets.
	#endif
#endif
	// gl_FrontLightModelProduct.sceneColor is material.emission + material.ambient * global.ambient
	vec4 color = texture2D(texture0, gl_TexCoord[0].st) * (gl_FrontLightModelProduct.sceneColor + ambient + diffuse);
#ifdef HAS_SPECULAR	
	color += specular;
#endif
	color.a = gl_FrontMaterial.diffuse.a;

#ifdef HAS_FOG
	float fog = clamp(exp(-gl_Fog.density * abs(eye_position.z)), 0.0, 1.0);
	color.rgb = mix(gl_Fog.color.rgb, color.rgb, fog);
#endif

	gl_FragColor = color;//*0.1 + vec4(eye_direction, 1.0);
}