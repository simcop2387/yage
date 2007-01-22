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
module derelict.opengl.extension.ext.framebuffer_object;

private
{
    import derelict.opengl.gltypes;
    import derelict.opengl.gl;
    import derelict.opengl.extension.loader;
    import std.string;
}

private bool enabled = false;

struct EXTFramebufferObject
{
    static bool load(char[] extString)
    {
        if(extString.find("GL_EXT_framebuffer_object") == -1)
            return false;
        if(!glBindExtFunc(cast(void**)&glIsRenderbufferEXT, "glIsRenderbufferEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glBindRenderbufferEXT, "glBindRenderbufferEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glDeleteRenderbuffersEXT, "glDeleteRenderbuffersEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glGenRenderbuffersEXT, "glGenRenderbuffersEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glRenderbufferStorageEXT, "glRenderbufferStorageEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glGetRenderbufferParameterivEXT, "glGetRenderbufferParameterivEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glIsFramebufferEXT, "glIsFramebufferEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glBindFramebufferEXT, "glBindFramebufferEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glDeleteFramebuffersEXT, "glDeleteFramebuffersEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glGenFramebuffersEXT, "glGenFramebuffersEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glCheckFramebufferStatusEXT, "glCheckFramebufferStatusEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glFramebufferTexture1DEXT, "glFramebufferTexture1DEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glFramebufferTexture2DEXT, "glFramebufferTexture2DEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glFramebufferTexture3DEXT, "glFramebufferTexture3DEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glFramebufferRenderbufferEXT, "glFramebufferRenderbufferEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glGetFramebufferAttachmentParameterivEXT, "glGetFramebufferAttachmentParameterivEXT"))
            return false;
        if(!glBindExtFunc(cast(void**)&glGenerateMipmapEXT, "glGenerateMipmapEXT"))
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
        DerelictGL.registerExtensionLoader(&EXTFramebufferObject.load);
    }
}

const GLenum GL_FRAMEBUFFER_EXT                                     = 0x8D40;
const GLenum GL_RENDERBUFFER_EXT                                    = 0x8D41;
const GLenum GL_STENCIL_INDEX1_EXT                                  = 0x8D46;
const GLenum GL_STENCIL_INDEX4_EXT                                  = 0x8D47;
const GLenum GL_STENCIL_INDEX8_EXT                                  = 0x8D48;
const GLenum GL_STENCIL_INDEX16_EXT                                 = 0x8D49;
const GLenum GL_RENDERBUFFER_WIDTH_EXT                              = 0x8D42;
const GLenum GL_RENDERBUFFER_HEIGHT_EXT                             = 0x8D43;
const GLenum GL_RENDERBUFFER_INTERNAL_FORMAT_EXT                    = 0x8D44;
const GLenum GL_RENDERBUFFER_RED_SIZE_EXT                           = 0x8D50;
const GLenum GL_RENDERBUFFER_GREEN_SIZE_EXT                         = 0x8D51;
const GLenum GL_RENDERBUFFER_BLUE_SIZE_EXT                          = 0x8D52;
const GLenum GL_RENDERBUFFER_ALPHA_SIZE_EXT                         = 0x8D53;
const GLenum GL_RENDERBUFFER_DEPTH_SIZE_EXT                         = 0x8D54;
const GLenum GL_RENDERBUFFER_STENCIL_SIZE_EXT                       = 0x8D55;
const GLenum GL_FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE_EXT              = 0x8CD0;
const GLenum GL_FRAMEBUFFER_ATTACHMENT_OBJECT_NAME_EXT              = 0x8CD1;
const GLenum GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_LEVEL_EXT            = 0x8CD2;
const GLenum GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_CUBE_MAP_FACE_EXT    = 0x8CD3;
const GLenum GL_FRAMEBUFFER_ATTACHMENT_TEXTURE_3D_ZOFFSET_EXT       = 0x8CD4;
const GLenum GL_COLOR_ATTACHMENT0_EXT                               = 0x8CE0;
const GLenum GL_COLOR_ATTACHMENT1_EXT                               = 0x8CE1;
const GLenum GL_COLOR_ATTACHMENT2_EXT                               = 0x8CE2;
const GLenum GL_COLOR_ATTACHMENT3_EXT                               = 0x8CE3;
const GLenum GL_COLOR_ATTACHMENT4_EXT                               = 0x8CE4;
const GLenum GL_COLOR_ATTACHMENT5_EXT                               = 0x8CE5;
const GLenum GL_COLOR_ATTACHMENT6_EXT                               = 0x8CE6;
const GLenum GL_COLOR_ATTACHMENT7_EXT                               = 0x8CE7;
const GLenum GL_COLOR_ATTACHMENT8_EXT                               = 0x8CE8;
const GLenum GL_COLOR_ATTACHMENT9_EXT                               = 0x8CE9;
const GLenum GL_COLOR_ATTACHMENT10_EXT                              = 0x8CEA;
const GLenum GL_COLOR_ATTACHMENT11_EXT                              = 0x8CEB;
const GLenum GL_COLOR_ATTACHMENT12_EXT                              = 0x8CEC;
const GLenum GL_COLOR_ATTACHMENT13_EXT                              = 0x8CED;
const GLenum GL_COLOR_ATTACHMENT14_EXT                              = 0x8CEE;
const GLenum GL_COLOR_ATTACHMENT15_EXT                              = 0x8CEF;
const GLenum GL_DEPTH_ATTACHMENT_EXT                                = 0x8D00;
const GLenum GL_STENCIL_ATTACHMENT_EXT                              = 0x8D20;
const GLenum GL_FRAMEBUFFER_COMPLETE_EXT                            = 0x8CD5;
const GLenum GL_FRAMEBUFFER_INCOMPLETE_ATTACHMENT_EXT               = 0x8CD6;
const GLenum GL_FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT_EXT       = 0x8CD7;
const GLenum GL_FRAMEBUFFER_INCOMPLETE_DIMENSIONS_EXT               = 0x8CD9;
const GLenum GL_FRAMEBUFFER_INCOMPLETE_FORMATS_EXT                  = 0x8CDA;
const GLenum GL_FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER_EXT              = 0x8CDB;
const GLenum GL_FRAMEBUFFER_INCOMPLETE_READ_BUFFER_EXT              = 0x8CDC;
const GLenum GL_FRAMEBUFFER_UNSUPPORTED_EXT                         = 0x8CDD;
const GLenum GL_FRAMEBUFFER_BINDING_EXT                             = 0x8CA6;
const GLenum GL_RENDERBUFFER_BINDING_EXT                            = 0x8CA7;
const GLenum GL_MAX_COLOR_ATTACHMENTS_EXT                           = 0x8CDF;
const GLenum GL_MAX_RENDERBUFFER_SIZE_EXT                           = 0x84E8;
const GLenum GL_INVALID_FRAMEBUFFER_OPERATION_EXT                   = 0x0506;

version(Windows)
    extern(Windows):
else
    extern(C):

typedef GLboolean function(GLuint) pfglIsRenderbufferEXT;
typedef GLvoid function(GLenum, GLuint) pfglBindRenderbufferEXT;
typedef GLvoid function(GLsizei, GLuint*) pfglDeleteRenderbuffersEXT;
typedef GLvoid function(GLsizei, GLuint*) pfglGenRenderbuffersEXT;
typedef GLvoid function(GLenum, GLenum, GLsizei, GLsizei) pfglRenderbufferStorageEXT;
typedef GLvoid function(GLenum, GLenum, GLint*) pfglGetRenderbufferParameterivEXT;
typedef GLboolean function(GLuint) pfglIsFramebufferEXT;
typedef GLvoid function(GLenum, GLuint) pfglBindFramebufferEXT;
typedef GLvoid function(GLsizei, GLuint*) pfglDeleteFramebuffersEXT;
typedef GLvoid function(GLsizei, GLuint*) pfglGenFramebuffersEXT;
typedef GLenum function(GLenum) pfglCheckFramebufferStatusEXT;
typedef GLvoid function(GLenum, GLenum, GLenum, GLuint, GLint) pfglFramebufferTexture1DEXT;
typedef GLvoid function(GLenum, GLenum, GLenum, GLuint, GLint) pfglFramebufferTexture2DEXT;
typedef GLvoid function(GLenum, GLenum, GLenum, GLuint, GLint, GLint) pfglFramebufferTexture3DEXT;
typedef GLvoid function(GLenum, GLenum, GLenum, GLuint) pfglFramebufferRenderbufferEXT;
typedef GLvoid function(GLenum, GLenum, GLenum, GLint*) pfglGetFramebufferAttachmentParameterivEXT;
typedef GLvoid function(GLenum) pfglGenerateMipmapEXT;

pfglIsRenderbufferEXT                       glIsRenderbufferEXT;
pfglBindRenderbufferEXT                     glBindRenderbufferEXT;
pfglDeleteRenderbuffersEXT                  glDeleteRenderbuffersEXT;
pfglGenRenderbuffersEXT                     glGenRenderbuffersEXT;
pfglRenderbufferStorageEXT                  glRenderbufferStorageEXT;
pfglGetRenderbufferParameterivEXT           glGetRenderbufferParameterivEXT;
pfglIsFramebufferEXT                        glIsFramebufferEXT;
pfglBindFramebufferEXT                      glBindFramebufferEXT;
pfglDeleteFramebuffersEXT                   glDeleteFramebuffersEXT;
pfglGenFramebuffersEXT                      glGenFramebuffersEXT;
pfglCheckFramebufferStatusEXT               glCheckFramebufferStatusEXT;
pfglFramebufferTexture1DEXT                 glFramebufferTexture1DEXT;
pfglFramebufferTexture2DEXT                 glFramebufferTexture2DEXT;
pfglFramebufferTexture3DEXT                 glFramebufferTexture3DEXT;
pfglFramebufferRenderbufferEXT              glFramebufferRenderbufferEXT;
pfglGetFramebufferAttachmentParameterivEXT  glGetFramebufferAttachmentParameterivEXT;
pfglGenerateMipmapEXT                       glGenerateMipmapEXT;
