#line 1
/**
 * Authors:    Eric Poggel
 * License:    public domain
 *
 * This shader re-invents the fixed-function OpenGL vertex and fragment
 * pipeline except with per-pixel lighting.  It suports fog and up to 2
 * lights of type point, spot, or directional.
 */
 
// temporary, testing
#undef HAS_FOG
//#undef HAS_BUMP
//#undef HAS_SPECULAR	
//#pragma debug(on)
//#pragma optimize(off)

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

// Varying
#if NUM_LIGHTS > 0
	varying vec3 light_directions[NUM_LIGHTS];
#endif
varying vec3 normal; // only used if no bump?
varying vec3 eye_direction;
varying vec3 eye_position; // only needs to be a varying if bump or fog.

void main()
{	// Vertex normal, eye position, and eye direction
	normal = (gl_NormalMatrix * gl_Normal) * gl_NormalScale;

	vec4 eyePositionTemp = gl_ModelViewMatrix * gl_Vertex;
	eye_position = vec3(eyePositionTemp) / eyePositionTemp.w;

	gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
	gl_Position = ftransform();
	
#ifdef HAS_BUMP
		
	// Convert eye_direction and light_directions to tangent-space
	vec3 tangent = normalize(gl_NormalMatrix * gl_MultiTexCoord1.xyz); // tangent
	vec3 binormal = cross(normal, tangent);
	
	vec3 v;
	v.x = dot(eye_position, tangent);
	v.y = dot(eye_position, binormal);
	v.z = dot(eye_position, normal);	
	eye_direction = -normalize(v);
	
	// Put each light direction in tangent space
	for (int i=0; i<NUM_LIGHTS; i++)
	{	vec3 lightDirection = lights[i].position.xyz - eye_position;
		v.x = dot(lightDirection, tangent);
		v.y = dot(lightDirection, binormal);
		v.z = dot(lightDirection, normal);	
		light_directions[i] = (v);
	}
#else // keep eye_direction and light_directions in world space (or is it model space?)	
	eye_direction = -normalize(eye_position);
	for (int i=0; i<NUM_LIGHTS; i++)
		light_directions[i] = lights[i].position.xyz - eye_position;		
#endif
}