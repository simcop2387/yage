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
module derelict.opengl.extension.arb.texture_float;

private
{
    import derelict.opengl.gltypes;
    import derelict.opengl.gl;
    import std.string;
}

private bool enabled = false;

struct ARBTextureFloat
{
    static bool load(char[] extString)
    {
        if(extString.find("GL_ARB_texture_float") != -1)
        {
            enabled = true;
            return true;
        }
        return false;
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
        DerelictGL.registerExtensionLoader(&ARBTextureFloat.load);
    }
}

const GLenum GL_TEXTURE_RED_TYPE_ARB           = 0x8C10;
const GLenum GL_TEXTURE_GREEN_TYPE_ARB         = 0x8C11;
const GLenum GL_TEXTURE_BLUE_TYPE_ARB          = 0x8C12;
const GLenum GL_TEXTURE_ALPHA_TYPE_ARB         = 0x8C13;
const GLenum GL_TEXTURE_LUMINANCE_TYPE_ARB     = 0x8C14;
const GLenum GL_TEXTURE_INTENSITY_TYPE_ARB     = 0x8C15;
const GLenum GL_TEXTURE_DEPTH_TYPE_ARB         = 0x8C16;
const GLenum GL_UNSIGNED_NORMALIZED_ARB        = 0x8C17;
const GLenum GL_RGBA32F_ARB                    = 0x8814;
const GLenum GL_RGB32F_ARB                     = 0x8815;
const GLenum GL_ALPHA32F_ARB                   = 0x8816;
const GLenum GL_INTENSITY32F_ARB               = 0x8817;
const GLenum GL_LUMINANCE32F_ARB               = 0x8818;
const GLenum GL_LUMINANCE_ALPHA32F_ARB         = 0x8819;
const GLenum GL_RGBA16F_ARB                    = 0x881A;
const GLenum GL_RGB16F_ARB                     = 0x881B;
const GLenum GL_ALPHA16F_ARB                   = 0x881C;
const GLenum GL_INTENSITY16F_ARB               = 0x881D;
const GLenum GL_LUMINANCE16F_ARB               = 0x881E;
const GLenum GL_LUMINANCE_ALPHA16F_ARB         = 0x881F;