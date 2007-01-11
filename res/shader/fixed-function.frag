/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Either LGPL or zlib/libpng
 * 
 * See documentation for fixed-function.vert
 */

uniform sampler2D tex;

varying float fog;

void main (void) 
{
    vec4 color = gl_Color * texture2D(tex, gl_TexCoord[0].st) + gl_SecondaryColor;
    color = vec4(mix(vec3(gl_Fog.color), vec3(color), fog), color.a);
    gl_FragColor = clamp(color, 0.0, 1.0);
}
