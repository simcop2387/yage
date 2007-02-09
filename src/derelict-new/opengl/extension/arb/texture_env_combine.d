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
module derelict.opengl.extension.arb.texture_env_combine;

private
{
    import derelict.opengl.gltypes;
    import derelict.opengl.gl;
    import std.string;
}

private bool enabled = false;

struct ARBTextureEnvCombine
{
    static bool load(char[] extString)
    {
        if(extString.find("GL_ARB_texture_env_combine") != -1)
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
        DerelictGL.registerExtensionLoader(&ARBTextureEnvCombine.load);
    }
}

const GLenum GL_COMBINE_ARB                    = 0x8570;
const GLenum GL_COMBINE_RGB_ARB                = 0x8571;
const GLenum GL_COMBINE_ALPHA_ARB              = 0x8572;
const GLenum GL_SOURCE0_RGB_ARB                = 0x8580;
const GLenum GL_SOURCE1_RGB_ARB                = 0x8581;
const GLenum GL_SOURCE2_RGB_ARB                = 0x8582;
const GLenum GL_SOURCE0_ALPHA_ARB              = 0x8588;
const GLenum GL_SOURCE1_ALPHA_ARB              = 0x8589;
const GLenum GL_SOURCE2_ALPHA_ARB              = 0x858A;
const GLenum GL_OPERAND0_RGB_ARB               = 0x8590;
const GLenum GL_OPERAND1_RGB_ARB               = 0x8591;
const GLenum GL_OPERAND2_RGB_ARB               = 0x8592;
const GLenum GL_OPERAND0_ALPHA_ARB             = 0x8598;
const GLenum GL_OPERAND1_ALPHA_ARB             = 0x8599;
const GLenum GL_OPERAND2_ALPHA_ARB             = 0x859A;
const GLenum GL_RGB_SCALE_ARB                  = 0x8573;
const GLenum GL_ADD_SIGNED_ARB                 = 0x8574;
const GLenum GL_INTERPOLATE_ARB                = 0x8575;
const GLenum GL_SUBTRACT_ARB                   = 0x84E7;
const GLenum GL_CONSTANT_ARB                   = 0x8576;
const GLenum GL_PRIMARY_COLOR_ARB              = 0x8577;
const GLenum GL_PREVIOUS_ARB                   = 0x8578;