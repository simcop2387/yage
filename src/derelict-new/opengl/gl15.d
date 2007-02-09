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
module derelict.opengl.gl15;

private
{
    import derelict.util.loader;
    import derelict.util.exception;
    import derelict.opengl.gltypes;
    import derelict.opengl.gl13;
    import derelict.opengl.gl14;
    version(Windows)
        import derelict.opengl.wgl;
}

package void loadGL15(SharedLib lib)
{
    version(Windows)
    {
        wglBindFunc(cast(void**)&glGenQueries, "glGenQueries", lib);
        wglBindFunc(cast(void**)&glDeleteQueries, "glDeleteQueries", lib);
        wglBindFunc(cast(void**)&glIsQuery, "glIsQuery", lib);
        wglBindFunc(cast(void**)&glBeginQuery, "glBeginQuery", lib);
        wglBindFunc(cast(void**)&glEndQuery, "glEndQuery", lib);
        wglBindFunc(cast(void**)&glGetQueryiv, "glGetQueryiv", lib);
        wglBindFunc(cast(void**)&glGetQueryObjectiv, "glGetQueryObjectiv", lib);
        wglBindFunc(cast(void**)&glGetQueryObjectuiv, "glGetQueryObjectuiv", lib);
        wglBindFunc(cast(void**)&glBindBuffer, "glBindBuffer", lib);
        wglBindFunc(cast(void**)&glDeleteBuffers, "glDeleteBuffers", lib);
        wglBindFunc(cast(void**)&glGenBuffers, "glGenBuffers", lib);
        wglBindFunc(cast(void**)&glIsBuffer, "glIsBuffer", lib);
        wglBindFunc(cast(void**)&glBufferData, "glBufferData", lib);
        wglBindFunc(cast(void**)&glBufferSubData, "glBufferSubData", lib);
        wglBindFunc(cast(void**)&glGetBufferSubData, "glGetBufferSubData", lib);
        wglBindFunc(cast(void**)&glMapBuffer, "glMapBuffer", lib);
        wglBindFunc(cast(void**)&glUnmapBuffer, "glUnmapBuffer", lib);
        wglBindFunc(cast(void**)&glGetBufferParameteriv, "glGetBufferParameteriv", lib);
        wglBindFunc(cast(void**)&glGetBufferPointerv, "glGetBufferPointerv", lib);
    }
    else
    {
        bindFunc(glGenQueries)("glGenQueries", lib);
        bindFunc(glDeleteQueries)("glDeleteQueries", lib);
        bindFunc(glIsQuery)("glIsQuery", lib);
        bindFunc(glBeginQuery)("glBeginQuery", lib);
        bindFunc(glEndQuery)("glEndQuery", lib);
        bindFunc(glGetQueryiv)("glGetQueryiv", lib);
        bindFunc(glGetQueryObjectiv)("glGetQueryObjectiv", lib);
        bindFunc(glGetQueryObjectuiv)("glGetQueryObjectuiv", lib);
        bindFunc(glBindBuffer)("glBindBuffer", lib);
        bindFunc(glDeleteBuffers)("glDeleteBuffers", lib);
        bindFunc(glGenBuffers)("glGenBuffers", lib);
        bindFunc(glIsBuffer)("glIsBuffer", lib);
        bindFunc(glBufferData)("glBufferData", lib);
        bindFunc(glBufferSubData)("glBufferSubData", lib);
        bindFunc(glGetBufferSubData)("glGetBufferSubData", lib);
        bindFunc(glMapBuffer)("glMapBuffer", lib);
        bindFunc(glUnmapBuffer)("glUnmapBuffer", lib);
        bindFunc(glGetBufferParameteriv)("glGetBufferParameteriv", lib);
        bindFunc(glGetBufferPointerv)("glGetBufferPointerv", lib);
    }
}

const GLuint GL_BUFFER_SIZE                     = 0x8764;
const GLuint GL_BUFFER_USAGE                    = 0x8765;
const GLuint GL_QUERY_COUNTER_BITS              = 0x8864;
const GLuint GL_CURRENT_QUERY                   = 0x8865;
const GLuint GL_QUERY_RESULT                    = 0x8866;
const GLuint GL_QUERY_RESULT_AVAILABLE          = 0x8867;
const GLuint GL_ARRAY_BUFFER                    = 0x8892;
const GLuint GL_ELEMENT_ARRAY_BUFFER            = 0x8893;
const GLuint GL_ARRAY_BUFFER_BINDING            = 0x8894;
const GLuint GL_ELEMENT_ARRAY_BUFFER_BINDING    = 0x8895;
const GLuint GL_VERTEX_ARRAY_BUFFER_BINDING     = 0x8896;
const GLuint GL_NORMAL_ARRAY_BUFFER_BINDING     = 0x8897;
const GLuint GL_COLOR_ARRAY_BUFFER_BINDING      = 0x8898;
const GLuint GL_INDEX_ARRAY_BUFFER_BINDING      = 0x8899;
const GLuint GL_TEXTURE_COORD_ARRAY_BUFFER_BINDING = 0x889A;
const GLuint GL_EDGE_FLAG_ARRAY_BUFFER_BINDING  = 0x889B;
const GLuint GL_SECONDARY_COLOR_ARRAY_BUFFER_BINDING = 0x889C;
const GLuint GL_FOG_COORDINATE_ARRAY_BUFFER_BINDING = 0x889D;
const GLuint GL_WEIGHT_ARRAY_BUFFER_BINDING     = 0x889E;
const GLuint GL_VERTEX_ATTRIB_ARRAY_BUFFER_BINDING = 0x889F;
const GLuint GL_READ_ONLY                       = 0x88B8;
const GLuint GL_WRITE_ONLY                      = 0x88B9;
const GLuint GL_READ_WRITE                      = 0x88BA;
const GLuint GL_BUFFER_ACCESS                   = 0x88BB;
const GLuint GL_BUFFER_MAPPED                   = 0x88BC;
const GLuint GL_BUFFER_MAP_POINTER              = 0x88BD;
const GLuint GL_STREAM_DRAW                     = 0x88E0;
const GLuint GL_STREAM_READ                     = 0x88E1;
const GLuint GL_STREAM_COPY                     = 0x88E2;
const GLuint GL_STATIC_DRAW                     = 0x88E4;
const GLuint GL_STATIC_READ                     = 0x88E5;
const GLuint GL_STATIC_COPY                     = 0x88E6;
const GLuint GL_DYNAMIC_DRAW                    = 0x88E8;
const GLuint GL_DYNAMIC_READ                    = 0x88E9;
const GLuint GL_DYNAMIC_COPY                    = 0x88EA;
const GLuint GL_SAMPLES_PASSED                  = 0x8914;
const GLuint GL_FOG_COORD_SRC                   = GL_FOG_COORDINATE_SOURCE;
const GLuint GL_FOG_COORD                       = GL_FOG_COORDINATE;
const GLuint GL_CURRENT_FOG_COORD               = GL_CURRENT_FOG_COORDINATE;
const GLuint GL_FOG_COORD_ARRAY_TYPE            = GL_FOG_COORDINATE_ARRAY_TYPE;
const GLuint GL_FOG_COORD_ARRAY_STRIDE          = GL_FOG_COORDINATE_ARRAY_STRIDE;
const GLuint GL_FOG_COORD_ARRAY_POINTER         = GL_FOG_COORDINATE_ARRAY_POINTER;
const GLuint GL_FOG_COORD_ARRAY                 = GL_FOG_COORDINATE_ARRAY;
const GLuint GL_FOG_COORD_ARRAY_BUFFER_BINDING  = GL_FOG_COORDINATE_ARRAY_BUFFER_BINDING;
const GLuint GL_SRC0_RGB                        = GL_SOURCE0_RGB;
const GLuint GL_SRC1_RGB                        = GL_SOURCE1_RGB;
const GLuint GL_SRC2_RGB                        = GL_SOURCE2_RGB;
const GLuint GL_SRC0_ALPHA                      = GL_SOURCE0_ALPHA;
const GLuint GL_SRC1_ALPHA                      = GL_SOURCE1_ALPHA;
const GLuint GL_SRC2_ALPHA                      = GL_SOURCE2_ALPHA;

version(Windows)
    extern(Windows):
else
    extern(C):

typedef GLvoid function(GLsizei, GLuint*) pfglGenQueries;
typedef GLvoid function(GLsizei,GLuint*) pfglDeleteQueries;
typedef GLboolean function(GLuint) pfglIsQuery;
typedef GLvoid function(GLenum, GLuint) pfglBeginQuery;
typedef GLvoid function(GLenum) pfglEndQuery;
typedef GLvoid function(GLenum, GLenum, GLint*) pfglGetQueryiv;
typedef GLvoid function(GLuint, GLenum, GLint*) pfglGetQueryObjectiv;
typedef GLvoid function(GLuint, GLenum, GLuint*) pfglGetQueryObjectuiv;
typedef GLvoid function(GLenum, GLuint) pfglBindBuffer;
typedef GLvoid function(GLsizei, GLuint*) pfglDeleteBuffers;
typedef GLvoid function(GLsizei, GLuint*) pfglGenBuffers;
typedef GLboolean function(GLuint) pfglIsBuffer;
typedef GLvoid function(GLenum, GLsizeiptr, GLvoid*, GLenum) pfglBufferData;
typedef GLvoid function(GLenum, GLintptr, GLsizeiptr,GLvoid*) pfglBufferSubData;
typedef GLvoid function(GLenum, GLintptr, GLsizeiptr, GLvoid*) pfglGetBufferSubData;
typedef GLvoid* function(GLenum, GLenum) pfglMapBuffer;
typedef GLboolean function(GLenum) pfglUnmapBuffer;
typedef GLvoid function(GLenum, GLenum, GLint*) pfglGetBufferParameteriv;
typedef GLvoid function(GLenum, GLenum, GLvoid**) pfglGetBufferPointerv;

pfglGenQueries              glGenQueries;
pfglDeleteQueries           glDeleteQueries;
pfglIsQuery                 glIsQuery;
pfglBeginQuery              glBeginQuery;
pfglEndQuery                glEndQuery;
pfglGetQueryiv              glGetQueryiv;
pfglGetQueryObjectiv        glGetQueryObjectiv;
pfglGetQueryObjectuiv       glGetQueryObjectuiv;
pfglBindBuffer              glBindBuffer;
pfglDeleteBuffers           glDeleteBuffers;
pfglGenBuffers              glGenBuffers;
pfglIsBuffer                glIsBuffer;
pfglBufferData              glBufferData;
pfglBufferSubData           glBufferSubData;
pfglGetBufferSubData        glGetBufferSubData;
pfglMapBuffer               glMapBuffer;
pfglUnmapBuffer             glUnmapBuffer;
pfglGetBufferParameteriv    glGetBufferParameteriv;
pfglGetBufferPointerv       glGetBufferPointerv;
