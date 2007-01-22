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
module derelict.opengl.extension.ati.draw_buffers;

private
{
    import derelict.opengl.gltypes;
    import derelict.opengl.gl;
    import derelict.opengl.extension.loader;
    import std.string;
}

private bool enabled = false;

struct ATIDrawBuffers
{
    static bool load(char[] extString)
    {
        if(extString.find("GL_ATI_draw_buffers") == -1)
            return false;

        if(!glBindExtFunc(cast(void**)&glDrawBuffersATI, "glDrawBuffersATI"))
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
        DerelictGL.registerExtensionLoader(&ATIDrawBuffers.load);
    }
}

const GL_MAX_DRAW_BUFFERS_ATI          = 0x8824;
const GL_DRAW_BUFFER0_ATI              = 0x8825;
const GL_DRAW_BUFFER1_ATI              = 0x8826;
const GL_DRAW_BUFFER2_ATI              = 0x8827;
const GL_DRAW_BUFFER3_ATI              = 0x8828;
const GL_DRAW_BUFFER4_ATI              = 0x8829;
const GL_DRAW_BUFFER5_ATI              = 0x882A;
const GL_DRAW_BUFFER6_ATI              = 0x882B;
const GL_DRAW_BUFFER7_ATI              = 0x882C;
const GL_DRAW_BUFFER8_ATI              = 0x882D;
const GL_DRAW_BUFFER9_ATI              = 0x882E;
const GL_DRAW_BUFFER10_ATI             = 0x882F;
const GL_DRAW_BUFFER11_ATI             = 0x8830;
const GL_DRAW_BUFFER12_ATI             = 0x8831;
const GL_DRAW_BUFFER13_ATI             = 0x8832;
const GL_DRAW_BUFFER14_ATI             = 0x8833;
const GL_DRAW_BUFFER15_ATI             = 0x8834;

version(Windows)
    extern(Windows):
else
    extern(C):

typedef void function(GLsizei, GLenum *) pfglDrawBuffersATI;
pfglDrawBuffersATI     glDrawBuffersATI;

