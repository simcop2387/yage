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
module derelict.opengl.extension.arb.vertex_blend;

private
{
    import derelict.opengl.gltypes;
    import derelict.opengl.gl;
    import derelict.opengl.extension.loader;
    import std.string;
}

private bool enabled = false;

struct ARBVertexBlend
{
    static bool load(char[] extString)
    {
        if(extString.find("GL_ARB_vertex_blend") == -1)
            return false;
        if(!glBindExtFunc(cast(void**)&glWeightbvARB, "glWeightbvARB"))
            return false;
        if(!glBindExtFunc(cast(void**)&glWeightsvARB, "glWeightsvARB"))
            return false;
        if(!glBindExtFunc(cast(void**)&glWeightivARB, "glWeightivARB"))
            return false;
        if(!glBindExtFunc(cast(void**)&glWeightfvARB, "glWeightfvARB"))
            return false;
        if(!glBindExtFunc(cast(void**)&glWeightdvARB, "glWeightdvARB"))
            return false;
        if(!glBindExtFunc(cast(void**)&glWeightubvARB, "glMatrixIndexPointerARB"))
            return false;
        if(!glBindExtFunc(cast(void**)&glWeightusvARB, "glWeightusvARB"))
            return false;
        if(!glBindExtFunc(cast(void**)&glWeightuivARB, "glWeightuivARB"))
            return false;
        if(!glBindExtFunc(cast(void**)&glWeightPointerARB, "glWeightPointerARB"))
            return false;
        if(!glBindExtFunc(cast(void**)&glVertexBlendARB, "glVertexBlendARB"))
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
        DerelictGL.registerExtensionLoader(&ARBVertexBlend.load);
    }
}

const GLenum GL_MAX_VERTEX_UNITS_ARB           = 0x86A4;
const GLenum GL_ACTIVE_VERTEX_UNITS_ARB        = 0x86A5;
const GLenum GL_WEIGHT_SUM_UNITY_ARB           = 0x86A6;
const GLenum GL_VERTEX_BLEND_ARB               = 0x86A7;
const GLenum GL_CURRENT_WEIGHT_ARB             = 0x86A8;
const GLenum GL_WEIGHT_ARRAY_TYPE_ARB          = 0x86A9;
const GLenum GL_WEIGHT_ARRAY_STRIDE_ARB        = 0x86AA;
const GLenum GL_WEIGHT_ARRAY_SIZE_ARB          = 0x86AB;
const GLenum GL_WEIGHT_ARRAY_POINTER_ARB       = 0x86AC;
const GLenum GL_WEIGHT_ARRAY_ARB               = 0x86AD;
const GLenum GL_MODELVIEW0_ARB                 = 0x1700;
const GLenum GL_MODELVIEW1_ARB                 = 0x850A;
const GLenum GL_MODELVIEW2_ARB                 = 0x8722;
const GLenum GL_MODELVIEW3_ARB                 = 0x8723;
const GLenum GL_MODELVIEW4_ARB                 = 0x8724;
const GLenum GL_MODELVIEW5_ARB                 = 0x8725;
const GLenum GL_MODELVIEW6_ARB                 = 0x8726;
const GLenum GL_MODELVIEW7_ARB                 = 0x8727;
const GLenum GL_MODELVIEW8_ARB                 = 0x8728;
const GLenum GL_MODELVIEW9_ARB                 = 0x8729;
const GLenum GL_MODELVIEW10_ARB                = 0x872A;
const GLenum GL_MODELVIEW11_ARB                = 0x872B;
const GLenum GL_MODELVIEW12_ARB                = 0x872C;
const GLenum GL_MODELVIEW13_ARB                = 0x872D;
const GLenum GL_MODELVIEW14_ARB                = 0x872E;
const GLenum GL_MODELVIEW15_ARB                = 0x872F;
const GLenum GL_MODELVIEW16_ARB                = 0x8730;
const GLenum GL_MODELVIEW17_ARB                = 0x8731;
const GLenum GL_MODELVIEW18_ARB                = 0x8732;
const GLenum GL_MODELVIEW19_ARB                = 0x8733;
const GLenum GL_MODELVIEW20_ARB                = 0x8734;
const GLenum GL_MODELVIEW21_ARB                = 0x8735;
const GLenum GL_MODELVIEW22_ARB                = 0x8736;
const GLenum GL_MODELVIEW23_ARB                = 0x8737;
const GLenum GL_MODELVIEW24_ARB                = 0x8738;
const GLenum GL_MODELVIEW25_ARB                = 0x8739;
const GLenum GL_MODELVIEW26_ARB                = 0x873A;
const GLenum GL_MODELVIEW27_ARB                = 0x873B;
const GLenum GL_MODELVIEW28_ARB                = 0x873C;
const GLenum GL_MODELVIEW29_ARB                = 0x873D;
const GLenum GL_MODELVIEW30_ARB                = 0x873E;
const GLenum GL_MODELVIEW31_ARB                = 0x873F;

version(Windows)
    extern(Windows):
else
    extern(C):

typedef void function(GLint, GLbyte*) pfglWeightbvARB;
typedef void function(GLint, GLshort*) pfglWeightsvARB;
typedef void function(GLint, GLint*) pfglWeightivARB;
typedef void function(GLint, GLfloat*) pfglWeightfvARB;
typedef void function(GLint, GLdouble*) pfglWeightdvARB;
typedef void function(GLint, GLubyte*) pfglWeightubvARB;
typedef void function(GLint, GLushort*) pfglWeightusvARB;
typedef void function(GLint, GLuint*) pfglWeightuivARB;
typedef void function(GLint, GLenum, GLsizei, GLvoid*) pfglWeightPointerARB;
typedef void function(GLint) pfglVertexBlendARB;
pfglWeightbvARB             glWeightbvARB;
pfglWeightsvARB             glWeightsvARB;
pfglWeightivARB             glWeightivARB;
pfglWeightfvARB             glWeightfvARB;
pfglWeightdvARB             glWeightdvARB;
pfglWeightubvARB            glWeightubvARB;
pfglWeightusvARB            glWeightusvARB;
pfglWeightuivARB            glWeightuivARB;
pfglWeightPointerARB        glWeightPointerARB;
pfglVertexBlendARB          glVertexBlendARB;