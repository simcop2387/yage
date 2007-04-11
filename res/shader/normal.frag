/**
 * Authors:    Eric Poggel
 * License:    public domain
 */

uniform sampler2D tex_diffuse, tex_normal;
uniform float light_number;

varying vec3 cam_position;
varying vec3 cam_direction;

varying vec3 light_position[3];
varying vec3 light_direction[3];
varying vec3 light_hv[3];

void main()
{
	// Attenuation
	float light_dist = length(light_direction[0]);
	float attenuation= 1.0/(gl_LightSource[0].constantAttenuation +
							gl_LightSource[0].linearAttenuation * light_dist +
							gl_LightSource[0].quadraticAttenuation * light_dist * light_dist);

	// Get normal from normal map
	vec3 normal = normalize(texture2D(tex_normal, gl_TexCoord[0].st).xyz);

	// Dot products
	float ndotl = max(0.0, dot(normal, normalize(light_direction[0])));
	float ndothv= max(0.0, dot(normal, normalize(light_hv[0])));

	// Material lighting components
	vec4 ambient	= attenuation * gl_LightSource[0].ambient;
	vec4 diffuse	= attenuation * gl_LightSource[0].diffuse * ndotl;
	vec4 specular	= attenuation * gl_LightSource[0].specular * pow(ndothv, gl_FrontMaterial.shininess);

	vec4 texture = texture2D(tex_diffuse, gl_TexCoord[0].st);
	vec4 brightness = gl_FrontLightModelProduct.sceneColor + ambient*gl_FrontMaterial.ambient + diffuse*gl_FrontMaterial.diffuse;


	gl_FragColor = vec4((texture*brightness + specular*gl_FrontMaterial.specular).rgb, texture.a);
	//gl_FragColor = vec4(light_hv[0], 1.0);

}
