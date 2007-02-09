/*
 * Copyright (c) 2004-2007 Derelict Developers
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
module derelict.opengl.extension.ati.fragment_shader;

private
{
    import derelict.opengl.gltypes;
    import derelict.opengl.gl;
    import derelict.opengl.extension.loader;
    import std.string;
}

private bool enabled = false;

struct ATIFragmentShader
{
    static bool load(char[] extString)
    {
        if(extString.find("GL_ATI_fragment_shader") == -1)
            return false;

        if(!glBindExtFunc(cast(void**)&glGenFragmentShadersATI, "glGenFragmentShadersATI"))
            return false;
        if(!glBindExtFunc(cast(void**)&glBindFragmentShaderATI, "glBindFragmentShaderATI"))
            return false;
        if(!glBindExtFunc(cast(void**)&glDeleteFragmentShaderATI, "glDeleteFragmentShaderATI"))
            return false;
        if(!glBindExtFunc(cast(void**)&glBeginFragmentShaderATI, "glBeginFragmentShaderATI"))
            return false;
        if(!glBindExtFunc(cast(void**)&glEndFragmentShaderATI, "glEndFragmentShaderATI"))
            return false;
        if(!glBindExtFunc(cast(void**)&glPassTexCoordATI, "glPassTexCoordATI"))
            return false;
        if(!glBindExtFunc(cast(void**)&glSampleMapATI, "glSampleMapATI"))
            return false;
        if(!glBindExtFunc(cast(void**)&glColorFragmentOp1ATI, "glColorFragmentOp1ATI"))
            return false;
        if(!glBindExtFunc(cast(void**)&glColorFragmentOp2ATI, "glColorFragmentOp2ATI"))
            return false;
        if(!glBindExtFunc(cast(void**)&glColorFragmentOp3ATI, "glColorFragmentOp3ATI"))
            return false;
        if(!glBindExtFunc(cast(void**)&glAlphaFragmentOp1ATI, "glAlphaFragmentOp1ATI"))
            return false;
        if(!glBindExtFunc(cast(void**)&glAlphaFragmentOp2ATI, "glAlphaFragmentOp2ATI"))
            return false;
        if(!glBindExtFunc(cast(void**)&glAlphaFragmentOp3ATI, "glAlphaFragmentOp3ATI"))
            return false;
        if(!glBindExtFunc(cast(void**)&glSetFragmentShaderConstantATI, "glSetFragmentShaderConstantATI"))
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
        DerelictGL.registerExtensionLoader(&ATIFragmentShader.load);
    }
}

const GL_FRAGMENT_SHADER_ATI                      = 0x8920;
const GL_REG_0_ATI                                = 0x8921;
const GL_REG_1_ATI                                = 0x8922;
const GL_REG_2_ATI                                = 0x8923;
const GL_REG_3_ATI                                = 0x8924;
const GL_REG_4_ATI                                = 0x8925;
const GL_REG_5_ATI                                = 0x8926;
const GL_REG_6_ATI                                = 0x8927;
const GL_REG_7_ATI                                = 0x8928;
const GL_REG_8_ATI                                = 0x8929;
const GL_REG_9_ATI                                = 0x892A;
const GL_REG_10_ATI                               = 0x892B;
const GL_REG_11_ATI                               = 0x892C;
const GL_REG_12_ATI                               = 0x892D;
const GL_REG_13_ATI                               = 0x892E;
const GL_REG_14_ATI                               = 0x892F;
const GL_REG_15_ATI                               = 0x8930;
const GL_REG_16_ATI                               = 0x8931;
const GL_REG_17_ATI                               = 0x8932;
const GL_REG_18_ATI                               = 0x8933;
const GL_REG_19_ATI                               = 0x8934;
const GL_REG_20_ATI                               = 0x8935;
const GL_REG_21_ATI                               = 0x8936;
const GL_REG_22_ATI                               = 0x8937;
const GL_REG_23_ATI                               = 0x8938;
const GL_REG_24_ATI                               = 0x8939;
const GL_REG_25_ATI                               = 0x893A;
const GL_REG_26_ATI                               = 0x893B;
const GL_REG_27_ATI                               = 0x893C;
const GL_REG_28_ATI                               = 0x893D;
const GL_REG_29_ATI                               = 0x893E;
const GL_REG_30_ATI                               = 0x893F;
const GL_REG_31_ATI                               = 0x8940;
const GL_CON_0_ATI                                = 0x8941;
const GL_CON_1_ATI                                = 0x8942;
const GL_CON_2_ATI                                = 0x8943;
const GL_CON_3_ATI                                = 0x8944;
const GL_CON_4_ATI                                = 0x8945;
const GL_CON_5_ATI                                = 0x8946;
const GL_CON_6_ATI                                = 0x8947;
const GL_CON_7_ATI                                = 0x8948;
const GL_CON_8_ATI                                = 0x8949;
const GL_CON_9_ATI                                = 0x894A;
const GL_CON_10_ATI                               = 0x894B;
const GL_CON_11_ATI                               = 0x894C;
const GL_CON_12_ATI                               = 0x894D;
const GL_CON_13_ATI                               = 0x894E;
const GL_CON_14_ATI                               = 0x894F;
const GL_CON_15_ATI                               = 0x8950;
const GL_CON_16_ATI                               = 0x8951;
const GL_CON_17_ATI                               = 0x8952;
const GL_CON_18_ATI                               = 0x8953;
const GL_CON_19_ATI                               = 0x8954;
const GL_CON_20_ATI                               = 0x8955;
const GL_CON_21_ATI                               = 0x8956;
const GL_CON_22_ATI                               = 0x8957;
const GL_CON_23_ATI                               = 0x8958;
const GL_CON_24_ATI                               = 0x8959;
const GL_CON_25_ATI                               = 0x895A;
const GL_CON_26_ATI                               = 0x895B;
const GL_CON_27_ATI                               = 0x895C;
const GL_CON_28_ATI                               = 0x895D;
const GL_CON_29_ATI                               = 0x895E;
const GL_CON_30_ATI                               = 0x895F;
const GL_CON_31_ATI                               = 0x8960;
const GL_MOV_ATI                                  = 0x8961;
const GL_ADD_ATI                                  = 0x8963;
const GL_MUL_ATI                                  = 0x8964;
const GL_SUB_ATI                                  = 0x8965;
const GL_DOT3_ATI                                 = 0x8966;
const GL_DOT4_ATI                                 = 0x8967;
const GL_MAD_ATI                                  = 0x8968;
const GL_LERP_ATI                                 = 0x8969;
const GL_CND_ATI                                  = 0x896A;
const GL_CND0_ATI                                 = 0x896B;
const GL_DOT2_ADD_ATI                             = 0x896C;
const GL_SECONDARY_INTERPOLATOR_ATI               = 0x896D;
const GL_NUM_FRAGMENT_REGISTERS_ATI               = 0x896E;
const GL_NUM_FRAGMENT_CONSTANTS_ATI               = 0x896F;
const GL_NUM_PASSES_ATI                           = 0x8970;
const GL_NUM_INSTRUCTIONS_PER_PASS_ATI            = 0x8971;
const GL_NUM_INSTRUCTIONS_TOTAL_ATI               = 0x8972;
const GL_NUM_INPUT_INTERPOLATOR_COMPONENTS_ATI    = 0x8973;
const GL_NUM_LOOPBACK_COMPONENTS_ATI              = 0x8974;
const GL_COLOR_ALPHA_PAIRING_ATI                  = 0x8975;
const GL_SWIZZLE_STR_ATI                          = 0x8976;
const GL_SWIZZLE_STQ_ATI                          = 0x8977;
const GL_SWIZZLE_STR_DR_ATI                       = 0x8978;
const GL_SWIZZLE_STQ_DQ_ATI                       = 0x8979;
const GL_SWIZZLE_STRQ_ATI                         = 0x897A;
const GL_SWIZZLE_STRQ_DQ_ATI                      = 0x897B;
const GL_RED_BIT_ATI                              = 0x00000001;
const GL_GREEN_BIT_ATI                            = 0x00000002;
const GL_BLUE_BIT_ATI                             = 0x00000004;
const GL_2X_BIT_ATI                               = 0x00000001;
const GL_4X_BIT_ATI                               = 0x00000002;
const GL_8X_BIT_ATI                               = 0x00000004;
const GL_HALF_BIT_ATI                             = 0x00000008;
const GL_QUARTER_BIT_ATI                          = 0x00000010;
const GL_EIGHTH_BIT_ATI                           = 0x00000020;
const GL_SATURATE_BIT_ATI                         = 0x00000040;
const GL_COMP_BIT_ATI                             = 0x00000002;
const GL_NEGATE_BIT_ATI                           = 0x00000004;
const GL_BIAS_BIT_ATI                             = 0x00000008;

version(Windows)
    extern(Windows):
else
    extern(C):

typedef GLuint function(GLuint)                   pfglGenFragmentShadersATI;
typedef void function(GLuint)                     pfglBindFragmentShaderATI;
typedef void function(GLuint)                     pfglDeleteFragmentShaderATI;
typedef void function()                           pfglBeginFragmentShaderATI;
typedef void function()                           pfglEndFragmentShaderATI;
typedef void function(GLuint, GLuint, GLenum)     pfglPassTexCoordATI;
typedef void function(GLuint, GLuint, GLenum)     pfglSampleMapATI;
typedef void function(GLenum, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint) pfglColorFragmentOp1ATI;
typedef void function(GLenum, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint) pfglColorFragmentOp2ATI;
typedef void function(GLenum, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint) pfglColorFragmentOp3ATI;
typedef void function(GLenum, GLuint, GLuint, GLuint, GLuint, GLuint) pfglAlphaFragmentOp1ATI;
typedef void function(GLenum, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint) pfglAlphaFragmentOp2ATI;
typedef void function(GLenum, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint, GLuint) pfglAlphaFragmentOp3ATI;
typedef void function(GLuint, GLfloat *)          pfglSetFragmentShaderConstantATI;
pfglGenFragmentShadersATI           glGenFragmentShadersATI;
pfglBindFragmentShaderATI           glBindFragmentShaderATI;
pfglDeleteFragmentShaderATI         glDeleteFragmentShaderATI;
pfglBeginFragmentShaderATI          glBeginFragmentShaderATI;
pfglEndFragmentShaderATI            glEndFragmentShaderATI;
pfglPassTexCoordATI                 glPassTexCoordATI;
pfglSampleMapATI                    glSampleMapATI;
pfglColorFragmentOp1ATI             glColorFragmentOp1ATI;
pfglColorFragmentOp2ATI             glColorFragmentOp2ATI;
pfglColorFragmentOp3ATI             glColorFragmentOp3ATI;
pfglAlphaFragmentOp1ATI             glAlphaFragmentOp1ATI;
pfglAlphaFragmentOp2ATI             glAlphaFragmentOp2ATI;
pfglAlphaFragmentOp3ATI             glAlphaFragmentOp3ATI;
pfglSetFragmentShaderConstantATI    glSetFragmentShaderConstantATI;

