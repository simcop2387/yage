/*
 * Copyright (c) 2004-2006 Derelict Developers
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 * * Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 *
 * * Neither the names 'Derelict', 'DerelictGL', nor the names of its contributors
 *   may be used to endorse or promote products derived from this software
 *   without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
module derelict.opengl.extension.nv.texture_shader;

private
{
    import derelict.opengl.gltypes;
    import derelict.opengl.gl;
    import std.string;
}

private bool enabled = false;

struct NVTextureShader
{
    static bool load(char[] extString)
    {
        if(extString.find("GL_NV_texture_shader") == -1)
            return false;

        enabled = true;
        return true;
    }

    static bool isEnabled()
    {
        return enabled;
    }
}

version(DerelictGL_NoExtensionLoaders)
{
}
else
{
    static this()
    {
        DerelictGL.registerExtensionLoader(&NVTextureShader.load);
    }
}

const GLenum GL_OFFSET_TEXTURE_RECTANGLE_NV             = 0x864C;
const GLenum GL_OFFSET_TEXTURE_RECTANGLE_SCALE_NV       = 0x864D;
const GLenum GL_DOT_PRODUCT_TEXTURE_RECTANGLE_NV        = 0x864E;
const GLenum GL_RGBA_UNSIGNED_DOT_PRODUCT_MAPPING_NV    = 0x86D9;
const GLenum GL_UNSIGNED_INT_S8_S8_8_8_NV               = 0x86DA;
const GLenum GL_UNSIGNED_INT_8_8_S8_S8_REV_NV           = 0x86DB;
const GLenum GL_DSDT_MAG_INTENSITY_NV                   = 0x86DC;
const GLenum GL_SHADER_CONSISTENT_NV                    = 0x86DD;
const GLenum GL_TEXTURE_SHADER_NV                       = 0x86DE;
const GLenum GL_SHADER_OPERATION_NV                     = 0x86DF;
const GLenum GL_CULL_MODES_NV                           = 0x86E0;
const GLenum GL_OFFSET_TEXTURE_MATRIX_NV                = 0x86E1;
const GLenum GL_OFFSET_TEXTURE_SCALE_NV                 = 0x86E2;
const GLenum GL_OFFSET_TEXTURE_BIAS_NV                  = 0x86E3;
const GLenum GL_OFFSET_TEXTURE_2D_MATRIX_NV             = GL_OFFSET_TEXTURE_MATRIX_NV;
const GLenum GL_OFFSET_TEXTURE_2D_SCALE_NV              = GL_OFFSET_TEXTURE_SCALE_NV;
const GLenum GL_OFFSET_TEXTURE_2D_BIAS_NV               = GL_OFFSET_TEXTURE_BIAS_NV;
const GLenum GL_PREVIOUS_TEXTURE_INPUT_NV               = 0x86E4;
const GLenum GL_CONST_EYE_NV                            = 0x86E5;
const GLenum GL_PASS_THROUGH_NV                         = 0x86E6;
const GLenum GL_CULL_FRAGMENT_NV                        = 0x86E7;
const GLenum GL_OFFSET_TEXTURE_2D_NV                    = 0x86E8;
const GLenum GL_DEPENDENT_AR_TEXTURE_2D_NV              = 0x86E9;
const GLenum GL_DEPENDENT_GB_TEXTURE_2D_NV              = 0x86EA;
const GLenum GL_DOT_PRODUCT_NV                          = 0x86EC;
const GLenum GL_DOT_PRODUCT_DEPTH_REPLACE_NV            = 0x86ED;
const GLenum GL_DOT_PRODUCT_TEXTURE_2D_NV               = 0x86EE;
const GLenum GL_DOT_PRODUCT_TEXTURE_CUBE_MAP_NV         = 0x86F0;
const GLenum GL_DOT_PRODUCT_DIFFUSE_CUBE_MAP_NV         = 0x86F1;
const GLenum GL_DOT_PRODUCT_REFLECT_CUBE_MAP_NV         = 0x86F2;
const GLenum GL_DOT_PRODUCT_CONST_EYE_REFLECT_CUBE_MAP_NV = 0x86F3;
const GLenum GL_HILO_NV                                 = 0x86F4;
const GLenum GL_DSDT_NV                                 = 0x86F5;
const GLenum GL_DSDT_MAG_NV                             = 0x86F6;
const GLenum GL_DSDT_MAG_VIB_NV                         = 0x86F7;
const GLenum GL_HILO16_NV                               = 0x86F8;
const GLenum GL_SIGNED_HILO_NV                          = 0x86F9;
const GLenum GL_SIGNED_HILO16_NV                        = 0x86FA;
const GLenum GL_SIGNED_RGBA_NV                          = 0x86FB;
const GLenum GL_SIGNED_RGBA8_NV                         = 0x86FC;
const GLenum GL_SIGNED_RGB_NV                           = 0x86FE;
const GLenum GL_SIGNED_RGB8_NV                          = 0x86FF;
const GLenum GL_SIGNED_LUMINANCE_NV                     = 0x8701;
const GLenum GL_SIGNED_LUMINANCE8_NV                    = 0x8702;
const GLenum GL_SIGNED_LUMINANCE_ALPHA_NV               = 0x8703;
const GLenum GL_SIGNED_LUMINANCE8_ALPHA8_NV             = 0x8704;
const GLenum GL_SIGNED_ALPHA_NV                         = 0x8705;
const GLenum GL_SIGNED_ALPHA8_NV                        = 0x8706;
const GLenum GL_SIGNED_INTENSITY_NV                     = 0x8707;
const GLenum GL_SIGNED_INTENSITY8_NV                    = 0x8708;
const GLenum GL_DSDT8_NV                                = 0x8709;
const GLenum GL_DSDT8_MAG8_NV                           = 0x870A;
const GLenum GL_DSDT8_MAG8_INTENSITY8_NV                = 0x870B;
const GLenum GL_SIGNED_RGB_UNSIGNED_ALPHA_NV            = 0x870C;
const GLenum GL_SIGNED_RGB8_UNSIGNED_ALPHA8_NV          = 0x870D;
const GLenum GL_HI_SCALE_NV                             = 0x870E;
const GLenum GL_LO_SCALE_NV                             = 0x870F;
const GLenum GL_DS_SCALE_NV                             = 0x8710;
const GLenum GL_DT_SCALE_NV                             = 0x8711;
const GLenum GL_MAGNITUDE_SCALE_NV                      = 0x8712;
const GLenum GL_VIBRANCE_SCALE_NV                       = 0x8713;
const GLenum GL_HI_BIAS_NV                              = 0x8714;
const GLenum GL_LO_BIAS_NV                              = 0x8715;
const GLenum GL_DS_BIAS_NV                              = 0x8716;
const GLenum GL_DT_BIAS_NV                              = 0x8717;
const GLenum GL_MAGNITUDE_BIAS_NV                       = 0x8718;
const GLenum GL_VIBRANCE_BIAS_NV                        = 0x8719;
const GLenum GL_TEXTURE_BORDER_VALUES_NV                = 0x871A;
const GLenum GL_TEXTURE_HI_SIZE_NV                      = 0x871B;
const GLenum GL_TEXTURE_LO_SIZE_NV                      = 0x871C;
const GLenum GL_TEXTURE_DS_SIZE_NV                      = 0x871D;
const GLenum GL_TEXTURE_DT_SIZE_NV                      = 0x871E;
const GLenum GL_TEXTURE_MAG_SIZE_NV                     = 0x871F;