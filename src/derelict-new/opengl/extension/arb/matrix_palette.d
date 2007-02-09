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
module derelict.opengl.extension.arb.matrix_palette;

private
{
    import derelict.opengl.gltypes;
    import derelict.opengl.gl;
    import derelict.opengl.extension.loader;
    import std.string;
}

private bool enabled = false;

struct ARBMatrixPalette
{
    static bool load(char[] extString)
    {
        if(extString.find("GL_ARB_matrix_palette") == -1)
            return false;
        if(!glBindExtFunc(cast(void**)&glCurrentPaletteMatrixARB, "glCurrentPaletteMatrixARB"))
            return false;
        if(!glBindExtFunc(cast(void**)&glMatrixIndexubvARB, "glMatrixIndexubvARB"))
            return false;
        if(!glBindExtFunc(cast(void**)&glMatrixIndexusvARB, "glMatrixIndexusvARB"))
            return false;
        if(!glBindExtFunc(cast(void**)&glMatrixIndexuivARB, "glMatrixIndexuivARB"))
            return false;
        if(!glBindExtFunc(cast(void**)&glMatrixIndexPointerARB, "glMatrixIndexPointerARB"))
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
        DerelictGL.registerExtensionLoader(&ARBMatrixPalette.load);
    }
}

const GLenum GL_MATRIX_PALETTE_ARB             		= 0x8840;
const GLenum GL_MAX_MATRIX_PALETTE_STACK_DEPTH_ARB 	= 0x8841;
const GLenum GL_MAX_PALETTE_MATRICES_ARB       		= 0x8842;
const GLenum GL_CURRENT_PALETTE_MATRIX_ARB     		= 0x8843;
const GLenum GL_MATRIX_INDEX_ARRAY_ARB         		= 0x8844;
const GLenum GL_CURRENT_MATRIX_INDEX_ARB       		= 0x8845;
const GLenum GL_MATRIX_INDEX_ARRAY_SIZE_ARB    		= 0x8846;
const GLenum GL_MATRIX_INDEX_ARRAY_TYPE_ARB    		= 0x8847;
const GLenum GL_MATRIX_INDEX_ARRAY_STRIDE_ARB  		= 0x8848;
const GLenum GL_MATRIX_INDEX_ARRAY_POINTER_ARB 		= 0x8849;

version(Windows)
	extern(Windows):
else
	extern(C):
typedef void function(GLint) pfglCurrentPaletteMatrixARB;
typedef void function(GLint, GLubyte*) pfglMatrixIndexubvARB;
typedef void function(GLint, GLushort*) pfglMatrixIndexusvARB;
typedef void function(GLint, GLuint*) pfglMatrixIndexuivARB;
typedef void function(GLint, GLenum, GLsizei, GLvoid*) pfglMatrixIndexPointerARB;
pfglCurrentPaletteMatrixARB			glCurrentPaletteMatrixARB;
pfglMatrixIndexubvARB				glMatrixIndexubvARB;
pfglMatrixIndexusvARB				glMatrixIndexusvARB;
pfglMatrixIndexuivARB				glMatrixIndexuivARB;
pfglMatrixIndexPointerARB			glMatrixIndexPointerARB;