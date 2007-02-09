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
module derelict.opengl.extension.nv.register_combiners;

private
{
    import derelict.opengl.gltypes;
    import derelict.opengl.gl;
    import derelict.opengl.extension.loader;
    import std.string;
}

private bool enabled = false;

struct NVRegisterCombiners
{
    static bool load(char[] extString)
    {
        if(extString.find("GL_NV_register_combiners") == -1)
            return false;

        if(!glBindExtFunc(cast(void**)&glCombinerParameterfvNV, "glCombinerParameterfvNV"))
            return false;
        if(!glBindExtFunc(cast(void**)&glCombinerParameterfNV, "glCombinerParameterfNV"))
            return false;
        if(!glBindExtFunc(cast(void**)&glCombinerParameterivNV, "glCombinerParameterivNV"))
            return false;
        if(!glBindExtFunc(cast(void**)&glCombinerParameteriNV, "glCombinerParameteriNV"))
            return false;
        if(!glBindExtFunc(cast(void**)&glCombinerInputNV, "glCombinerInputNV"))
            return false;
        if(!glBindExtFunc(cast(void**)&glCombinerOutputNV, "glCombinerOutputNV"))
            return false;
        if(!glBindExtFunc(cast(void**)&glFinalCombinerInputNV, "glFinalCombinerInputNV"))
            return false;
        if(!glBindExtFunc(cast(void**)&glGetCombinerInputParameterfvNV, "glGetCombinerInputParameterfvNV"))
            return false;
        if(!glBindExtFunc(cast(void**)&glGetCombinerInputParameterivNV, "glGetCombinerInputParameterivNV"))
            return false;
        if(!glBindExtFunc(cast(void**)&glGetCombinerOutputParameterfvNV, "glGetCombinerOutputParameterfvNV"))
            return false;
        if(!glBindExtFunc(cast(void**)&glGetCombinerOutputParameterivNV, "glGetCombinerOutputParameterivNV"))
            return false;
        if(!glBindExtFunc(cast(void**)&glGetFinalCombinerInputParameterfvNV, "glGetFinalCombinerInputParameterfvNV"))
            return false;
        if(!glBindExtFunc(cast(void**)&glGetFinalCombinerInputParameterivNV, "glGetFinalCombinerInputParameterivNV"))
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
        DerelictGL.registerExtensionLoader(&NVRegisterCombiners.load);
    }
}

const GLenum GL_REGISTER_COMBINERS_NV          = 0x8522;
const GLenum GL_VARIABLE_A_NV                  = 0x8523;
const GLenum GL_VARIABLE_B_NV                  = 0x8524;
const GLenum GL_VARIABLE_C_NV                  = 0x8525;
const GLenum GL_VARIABLE_D_NV                  = 0x8526;
const GLenum GL_VARIABLE_E_NV                  = 0x8527;
const GLenum GL_VARIABLE_F_NV                  = 0x8528;
const GLenum GL_VARIABLE_G_NV                  = 0x8529;
const GLenum GL_CONSTANT_COLOR0_NV             = 0x852A;
const GLenum GL_CONSTANT_COLOR1_NV             = 0x852B;
const GLenum GL_PRIMARY_COLOR_NV               = 0x852C;
const GLenum GL_SECONDARY_COLOR_NV             = 0x852D;
const GLenum GL_SPARE0_NV                      = 0x852E;
const GLenum GL_SPARE1_NV                      = 0x852F;
const GLenum GL_DISCARD_NV                     = 0x8530;
const GLenum GL_E_TIMES_F_NV                   = 0x8531;
const GLenum GL_SPARE0_PLUS_SECONDARY_COLOR_NV = 0x8532;
const GLenum GL_UNSIGNED_IDENTITY_NV           = 0x8536;
const GLenum GL_UNSIGNED_INVERT_NV             = 0x8537;
const GLenum GL_EXPAND_NORMAL_NV               = 0x8538;
const GLenum GL_EXPAND_NEGATE_NV               = 0x8539;
const GLenum GL_HALF_BIAS_NORMAL_NV            = 0x853A;
const GLenum GL_HALF_BIAS_NEGATE_NV            = 0x853B;
const GLenum GL_SIGNED_IDENTITY_NV             = 0x853C;
const GLenum GL_SIGNED_NEGATE_NV               = 0x853D;
const GLenum GL_SCALE_BY_TWO_NV                = 0x853E;
const GLenum GL_SCALE_BY_FOUR_NV               = 0x853F;
const GLenum GL_SCALE_BY_ONE_HALF_NV           = 0x8540;
const GLenum GL_BIAS_BY_NEGATIVE_ONE_HALF_NV   = 0x8541;
const GLenum GL_COMBINER_INPUT_NV              = 0x8542;
const GLenum GL_COMBINER_MAPPING_NV            = 0x8543;
const GLenum GL_COMBINER_COMPONENT_USAGE_NV    = 0x8544;
const GLenum GL_COMBINER_AB_DOT_PRODUCT_NV     = 0x8545;
const GLenum GL_COMBINER_CD_DOT_PRODUCT_NV     = 0x8546;
const GLenum GL_COMBINER_MUX_SUM_NV            = 0x8547;
const GLenum GL_COMBINER_SCALE_NV              = 0x8548;
const GLenum GL_COMBINER_BIAS_NV               = 0x8549;
const GLenum GL_COMBINER_AB_OUTPUT_NV          = 0x854A;
const GLenum GL_COMBINER_CD_OUTPUT_NV          = 0x854B;
const GLenum GL_COMBINER_SUM_OUTPUT_NV         = 0x854C;
const GLenum GL_MAX_GENERAL_COMBINERS_NV       = 0x854D;
const GLenum GL_NUM_GENERAL_COMBINERS_NV       = 0x854E;
const GLenum GL_COLOR_SUM_CLAMP_NV             = 0x854F;
const GLenum GL_COMBINER0_NV                   = 0x8550;
const GLenum GL_COMBINER1_NV                   = 0x8551;
const GLenum GL_COMBINER2_NV                   = 0x8552;
const GLenum GL_COMBINER3_NV                   = 0x8553;
const GLenum GL_COMBINER4_NV                   = 0x8554;
const GLenum GL_COMBINER5_NV                   = 0x8555;
const GLenum GL_COMBINER6_NV                   = 0x8556;
const GLenum GL_COMBINER7_NV                   = 0x8557;

version(Windows)
    extern(Windows):
else
    extern(C):

typedef void function(GLenum, GLfloat*) pfglCombinerParameterfvNV;
typedef void function(GLenum, GLfloat) pfglCombinerParameterfNV;
typedef void function(GLenum, GLint*) pfglCombinerParameterivNV;
typedef void function(GLenum, GLint) pfglCombinerParameteriNV;
typedef void function(GLenum, GLenum, GLenum, GLenum, GLenum, GLenum) pfglCombinerInputNV;
typedef void function(GLenum, GLenum, GLenum, GLenum, GLenum, GLenum, GLenum, GLboolean, GLboolean, GLboolean) pfglCombinerOutputNV;
typedef void function(GLenum, GLenum, GLenum, GLenum) pfglFinalCombinerInputNV;
typedef void function(GLenum, GLenum, GLenum, GLenum, GLfloat*) pfglGetCombinerInputParameterfvNV;
typedef void function(GLenum, GLenum, GLenum, GLenum, GLint*) pfglGetCombinerInputParameterivNV;
typedef void function(GLenum, GLenum, GLenum, GLfloat*) pfglGetCombinerOutputParameterfvNV;
typedef void function(GLenum, GLenum, GLenum, GLint*) pfglGetCombinerOutputParameterivNV;
typedef void function(GLenum, GLenum, GLfloat*) pfglGetFinalCombinerInputParameterfvNV;
typedef void function(GLenum, GLenum, GLint*) pfglGetFinalCombinerInputParameterivNV;
pfglCombinerParameterfvNV               glCombinerParameterfvNV;
pfglCombinerParameterfNV                glCombinerParameterfNV;
pfglCombinerParameterivNV               glCombinerParameterivNV;
pfglCombinerParameteriNV                glCombinerParameteriNV;
pfglCombinerInputNV                     glCombinerInputNV;
pfglCombinerOutputNV                    glCombinerOutputNV;
pfglFinalCombinerInputNV                glFinalCombinerInputNV;
pfglGetCombinerInputParameterfvNV       glGetCombinerInputParameterfvNV;
pfglGetCombinerInputParameterivNV       glGetCombinerInputParameterivNV;
pfglGetCombinerOutputParameterfvNV      glGetCombinerOutputParameterfvNV;
pfglGetCombinerOutputParameterivNV      glGetCombinerOutputParameterivNV;
pfglGetFinalCombinerInputParameterfvNV  glGetFinalCombinerInputParameterfvNV;
pfglGetFinalCombinerInputParameterivNV  glGetFinalCombinerInputParameterivNV;