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
 * * Neither the names 'Derelict', 'DerelictGLU', nor the names of its contributors
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
module derelict.opengl.glu;

private
{
    import derelict.opengl.gltypes;
    import derelict.util.loader;
}

version(Windows)
    private import std.c.windows.windows;

private void load(SharedLib lib)
{
    //  bindFunc(gluBuild1DMipmapLevels)("gluBuild1DMipmapLevels", lib);
    bindFunc(gluBuild1DMipmaps)("gluBuild1DMipmaps", lib);
//  bindFunc(gluBuild2DMipmapLevels)("gluBuild2DMipmapLevels", lib);
    bindFunc(gluBuild2DMipmaps)("gluBuild2DMipmaps", lib);
//  bindFunc(gluBuild3DMipmapLevels)("gluBuild3DMipmapLevels", lib);
//  bindFunc(gluBuild3DMipmaps)("gluBuild3DMipmaps", lib);
//  bindFunc(gluCheckExtension)("gluCheckExtension", lib);
    bindFunc(gluErrorString)("gluErrorString", lib);
    bindFunc(gluGetString)("gluGetString", lib);
    bindFunc(gluCylinder)("gluCylinder", lib);
    bindFunc(gluDisk)("gluDisk", lib);
    bindFunc(gluPartialDisk)("gluPartialDisk", lib);
    bindFunc(gluSphere)("gluSphere", lib);
    bindFunc(gluBeginCurve)("gluBeginCurve", lib);
    bindFunc(gluBeginPolygon)("gluBeginPolygon", lib);
    bindFunc(gluBeginSurface)("gluBeginSurface", lib);
    bindFunc(gluBeginTrim)("gluBeginTrim", lib);
    bindFunc(gluEndCurve)("gluEndCurve", lib);
    bindFunc(gluEndPolygon)("gluEndPolygon", lib);
    bindFunc(gluEndSurface)("gluEndSurface", lib);
    bindFunc(gluEndTrim)("gluEndTrim", lib);
    bindFunc(gluDeleteNurbsRenderer)("gluDeleteNurbsRenderer", lib);
    bindFunc(gluDeleteQuadric)("gluDeleteQuadric", lib);
    bindFunc(gluDeleteTess)("gluDeleteTess", lib);
    bindFunc(gluGetNurbsProperty)("gluGetNurbsProperty", lib);
    bindFunc(gluGetTessProperty)("gluGetTessProperty", lib);
    bindFunc(gluLoadSamplingMatrices)("gluLoadSamplingMatrices", lib);
    bindFunc(gluNewNurbsRenderer)("gluNewNurbsRenderer", lib);
    bindFunc(gluNewQuadric)("gluNewQuadric", lib);
    bindFunc(gluNewTess)("gluNewTess", lib);
    bindFunc(gluNextContour)("gluNextContour", lib);
    bindFunc(gluNurbsCallback)("gluNurbsCallback", lib);
//  bindFunc(gluNurbsCallbackData)("gluNurbsCallbackData", lib);
//  bindFunc(gluNurbsCallbackDataEXT)("gluNurbsCallbackDataEXT", lib);
    bindFunc(gluNurbsCurve)("gluNurbsCurve", lib);
    bindFunc(gluNurbsProperty)("gluNurbsProperty", lib);
    bindFunc(gluNurbsSurface)("gluNurbsSurface", lib);
    bindFunc(gluPwlCurve)("gluPwlCurve", lib);
    bindFunc(gluQuadricCallback)("gluQuadricCallback", lib);
    bindFunc(gluQuadricDrawStyle)("gluQuadricDrawStyle", lib);
    bindFunc(gluQuadricNormals)("gluQuadricNormals", lib);
    bindFunc(gluQuadricOrientation)("gluQuadricOrientation", lib);
    bindFunc(gluQuadricTexture)("gluQuadricTexture", lib);
    bindFunc(gluTessBeginContour)("gluTessBeginContour", lib);
    bindFunc(gluTessBeginPolygon)("gluTessBeginPolygon", lib);
    bindFunc(gluTessCallback)("gluTessCallback", lib);
    bindFunc(gluTessEndContour)("gluTessEndContour", lib);
    bindFunc(gluTessEndPolygon)("gluTessEndPolygon", lib);
    bindFunc(gluTessNormal)("gluTessNormal", lib);
    bindFunc(gluTessProperty)("gluTessProperty", lib);
    bindFunc(gluTessVertex)("gluTessVertex", lib);
    bindFunc(gluLookAt)("gluLookAt", lib);
    bindFunc(gluOrtho2D)("gluOrtho2D", lib);
    bindFunc(gluPerspective)("gluPerspective", lib);
    bindFunc(gluPickMatrix)("gluPickMatrix", lib);
    bindFunc(gluProject)("gluProject", lib);
    bindFunc(gluScaleImage)("gluScaleImage", lib);
    bindFunc(gluUnProject)("gluUnProject", lib);
//  bindFunc(gluUnProject4)("gluUnProject4", lib);
}


GenericLoader DerelictGLU;
static this() {
	DerelictGLU.setup(
		"glu32.dll",
		"libGLU.so",
		"",
		&load
	);
}

//==============================================================================
// CONSTANTS
//==============================================================================
// StringName
const uint GLU_VERSION                      = 100800;
const uint GLU_EXTENSIONS                   = 100801;
// ErrorCode
const uint GLU_INVALID_ENUM                 = 100900;
const uint GLU_INVALID_VALUE                = 100901;
const uint GLU_OUT_OF_MEMORY                = 100902;
const uint GLU_INVALID_OPERATION            = 100904;
// NurbsDisplay
const uint GLU_OUTLINE_POLYGON              = 100240;
const uint GLU_OUTLINE_PATCH                = 100241;
// NurbsCallback
const uint GLU_NURBS_ERROR                  = 100103;
const uint GLU_ERROR                        = 100103;
const uint GLU_NURBS_BEGIN                  = 100164;
const uint GLU_NURBS_BEGIN_EXT              = 100164;
const uint GLU_NURBS_VERTEX                 = 100165;
const uint GLU_NURBS_VERTEX_EXT             = 100165;
const uint GLU_NURBS_NORMAL                 = 100166;
const uint GLU_NURBS_NORMAL_EXT             = 100166;
const uint GLU_NURBS_COLOR                  = 100167;
const uint GLU_NURBS_COLOR_EXT              = 100167;
const uint GLU_NURBS_TEXTURE_COORD          = 100168;
const uint GLU_NURBS_TEX_COORD_EXT          = 100168;
const uint GLU_NURBS_END                    = 100169;
const uint GLU_NURBS_END_EXT                = 100169;
const uint GLU_NURBS_BEGIN_DATA             = 100170;
const uint GLU_NURBS_BEGIN_DATA_EXT         = 100170;
const uint GLU_NURBS_VERTEX_DATA            = 100171;
const uint GLU_NURBS_VERTEX_DATA_EXT        = 100171;
const uint GLU_NURBS_NORMAL_DATA            = 100172;
const uint GLU_NURBS_NORMAL_DATA_EXT        = 100172;
const uint GLU_NURBS_COLOR_DATA             = 100173;
const uint GLU_NURBS_COLOR_DATA_EXT         = 100173;
const uint GLU_NURBS_TEXTURE_COORD_DATA     = 100174;
const uint GLU_NURBS_TEX_COORD_DATA_EXT     = 100174;
const uint GLU_NURBS_END_DATA               = 100175;
const uint GLU_NURBS_END_DATA_EXT           = 100175;
// NurbsError
const uint GLU_NURBS_ERROR1                 = 100251;
const uint GLU_NURBS_ERROR2                 = 100252;
const uint GLU_NURBS_ERROR3                 = 100253;
const uint GLU_NURBS_ERROR4                 = 100254;
const uint GLU_NURBS_ERROR5                 = 100255;
const uint GLU_NURBS_ERROR6                 = 100256;
const uint GLU_NURBS_ERROR7                 = 100257;
const uint GLU_NURBS_ERROR8                 = 100258;
const uint GLU_NURBS_ERROR9                 = 100259;
const uint GLU_NURBS_ERROR10                = 100260;
const uint GLU_NURBS_ERROR11                = 100261;
const uint GLU_NURBS_ERROR12                = 100262;
const uint GLU_NURBS_ERROR13                = 100263;
const uint GLU_NURBS_ERROR14                = 100264;
const uint GLU_NURBS_ERROR15                = 100265;
const uint GLU_NURBS_ERROR16                = 100266;
const uint GLU_NURBS_ERROR17                = 100267;
const uint GLU_NURBS_ERROR18                = 100268;
const uint GLU_NURBS_ERROR19                = 100269;
const uint GLU_NURBS_ERROR20                = 100270;
const uint GLU_NURBS_ERROR21                = 100271;
const uint GLU_NURBS_ERROR22                = 100272;
const uint GLU_NURBS_ERROR23                = 100273;
const uint GLU_NURBS_ERROR24                = 100274;
const uint GLU_NURBS_ERROR25                = 100275;
const uint GLU_NURBS_ERROR26                = 100276;
const uint GLU_NURBS_ERROR27                = 100277;
const uint GLU_NURBS_ERROR28                = 100278;
const uint GLU_NURBS_ERROR29                = 100279;
const uint GLU_NURBS_ERROR30                = 100280;
const uint GLU_NURBS_ERROR31                = 100281;
const uint GLU_NURBS_ERROR32                = 100282;
const uint GLU_NURBS_ERROR33                = 100283;
const uint GLU_NURBS_ERROR34                = 100284;
const uint GLU_NURBS_ERROR35                = 100285;
const uint GLU_NURBS_ERROR36                = 100286;
const uint GLU_NURBS_ERROR37                = 100287;
// NurbsProperty
const uint GLU_AUTO_LOAD_MATRIX             = 100200;
const uint GLU_CULLING                      = 100201;
const uint GLU_SAMPLING_TOLERANCE           = 100203;
const uint GLU_DISPLAY_MODE                 = 100204;
const uint GLU_PARAMETRIC_TOLERANCE         = 100202;
const uint GLU_SAMPLING_METHOD              = 100205;
const uint GLU_U_STEP                       = 100206;
const uint GLU_V_STEP                       = 100207;
const uint GLU_NURBS_MODE                   = 100160;
const uint GLU_NURBS_MODE_EXT               = 100160;
const uint GLU_NURBS_TESSELLATOR            = 100161;
const uint GLU_NURBS_TESSELLATOR_EXT        = 100161;
const uint GLU_NURBS_RENDERER               = 100162;
const uint GLU_NURBS_RENDERER_EXT           = 100162;
// NurbsSampling
const uint GLU_OBJECT_PARAMETRIC_ERROR      = 100208;
const uint GLU_OBJECT_PARAMETRIC_ERROR_EXT  = 100208;
const uint GLU_OBJECT_PATH_LENGTH           = 100209;
const uint GLU_OBJECT_PATH_LENGTH_EXT       = 100209;
const uint GLU_PATH_LENGTH                  = 100215;
const uint GLU_PARAMETRIC_ERROR             = 100216;
const uint GLU_DOMAIN_DISTANCE              = 100217;
// NurbsTrim
const uint GLU_MAP1_TRIM_2                  = 100210;
const uint GLU_MAP2_TRIM_3                  = 100211;
// QuadricDrawStyle
const uint GLU_POINT                        = 100010;
const uint GLU_LINE                         = 100011;
const uint GLU_FILL                         = 100012;
const uint GLU_SILHOUETTE                   = 100013;
// QuadricNormal
const uint GLU_SMOOTH                       = 100000;
const uint GLU_FLAT                         = 100001;
const uint GLU_NONE                         = 100002;
// QuadricOrientation
const uint GLU_OUTSITE                      = 100020;
const uint GLU_INSIDE                       = 100021;
// TessCallback
const uint GLU_TESS_BEGIN                   = 100100;
const uint GLU_BEGIN                        = 100100;
const uint GLU_TESS_VERTEX                  = 100101;
const uint GLU_VERTEX                       = 100101;
const uint GLU_TESS_END                     = 100102;
const uint GLU_END                          = 100102;
const uint GLU_TESS_ERROR                   = 100103;
const uint GLU_TESS_EDGE_FLAG               = 100104;
const uint GLU_EDGE_FLAG                    = 100104;
const uint GLU_TESS_COMBINE                 = 100105;
const uint GLU_TESS_BEGIN_DATA              = 100106;
const uint GLU_TESS_VERTEX_DATA             = 100107;
const uint GLU_TESS_END_DATA                = 100108;
const uint GLU_TESS_ERROR_DATA              = 100109;
const uint GLU_TESS_EDGE_FLAG_DATA          = 100110;
const uint GLU_TESS_COMBINE_DATA            = 100111;
// TessContour
const uint GLU_CW                           = 100120;
const uint GLU_CCW                          = 100121;
const uint GLU_INTERIOR                     = 100122;
const uint GLU_EXTERIOR                     = 100123;
const uint GLU_UNKNOWN                      = 100124;
// TessProperty
const uint GLU_TESS_WINDING_RULE            = 100140;
const uint GLU_TESS_BOUNDARY_ONLY           = 100141;
const uint GLU_TESS_TOLERANCE               = 100142;
// TessError
const uint GLU_TESS_ERROR1                  = 100151;
const uint GLU_TESS_ERROR2                  = 100152;
const uint GLU_TESS_ERROR3                  = 100153;
const uint GLU_TESS_ERROR4                  = 100154;
const uint GLU_TESS_ERROR5                  = 100155;
const uint GLU_TESS_ERROR6                  = 100156;
const uint GLU_TESS_ERROR7                  = 100157;
const uint GLU_TESS_ERROR8                  = 100158;
const uint GLU_TESS_MISSING_BEGIN_POLYGON   = 100151;
const uint GLU_TESS_MISSING_BEGIN_COUNTER   = 100152;
const uint GLU_TESS_MISSING_END_POLYGON     = 100153;
const uint GLU_TESS_MISSING_END_COUNTER     = 100154;
const uint GLU_TESS_COORD_TOO_LARGE         = 100155;
const uint GLU_TESS_NEED_COMBINE_CALLBACK   = 100156;
// TessWinding
const uint GLU_TESS_WINDING_ODD             = 100130;
const uint GLU_TESS_WINDING_NONZERO         = 100131;
const uint GLU_TESS_WINDING_POSITIVE        = 100132;
const uint GLU_TESS_WINDING_NEGATIVE        = 100133;
const uint GLU_TESS_WINDING_ABS_GEQ_TWO     = 100134;

const GLdouble GLU_TESS_MAX_COORD           = 1.0e150;

//==============================================================================
// TYPES
//==============================================================================
struct GLUnurbs;
struct GLUquadric;
struct GLUtesselator;

typedef GLUnurbs GLUnurbsObj;
typedef GLUquadric GLUquadricObj;
typedef GLUtesselator GLUtesselatorObj;
typedef GLUtesselator GLUtriangulatorObj;

typedef void function() _GLUfuncptr;

//==============================================================================
// DLL FUNCTIONS
//==============================================================================
version(Windows)
    extern(Windows):
else
    extern(C):

typedef GLint function(GLenum,GLint,GLsizei,GLenum,GLenum,GLint,GLint,GLint,void*) pfgluBuild1DMipmapLevels;
typedef GLint function(GLenum,GLint,GLsizei,GLenum,GLenum,void*) pfgluBuild1DMipmaps;
typedef GLint function(GLenum,GLint,GLsizei,GLsizei,GLenum,GLenum,GLint,GLint,GLint,void*) pfgluBuild2DMipmapLevels;
typedef GLint function(GLenum,GLint,GLsizei,GLsizei,GLenum,GLenum,void*) pfgluBuild2DMipmaps;
typedef GLint function(GLenum,GLint,GLsizei,GLsizei,GLsizei,GLenum,GLenum,GLint,GLint,GLint,void*) pfgluBuild3DMipmapLevels;
typedef GLint function(GLenum,GLint,GLsizei,GLsizei,GLsizei,GLenum,GLenum,void*) pfgluBuild3DMipmaps;
//pfgluBuild1DMipmapLevels  gluBuild1DMipmapLevels;
pfgluBuild1DMipmaps         gluBuild1DMipmaps;
//pfgluBuild2DMipmapLevels  gluBuild2DMipmapLevels;
pfgluBuild2DMipmaps         gluBuild2DMipmaps;
//pfgluBuild3DMipmapLevels  gluBuild3DMipmapLevels;
//pfgluBuild3DMipmaps           gluBuild3DMipmaps;

typedef GLboolean function(GLubyte*,GLubyte*) pfgluCheckExtension;
typedef GLubyte* function(GLenum) pfgluErrorString;
typedef GLubyte* function(GLenum) pfgluGetString;
//pfgluCheckExtension           gluCheckExtension;
pfgluErrorString            gluErrorString;
pfgluGetString              gluGetString;

typedef void function(GLUquadric*,GLdouble,GLdouble,GLdouble,GLint,GLint) pfgluCylinder;
typedef void function(GLUquadric*,GLdouble,GLdouble,GLint,GLint) pfgluDisk;
typedef void function(GLUquadric*,GLdouble,GLdouble,GLint,GLint,GLdouble,GLdouble) pfgluPartialDisk;
typedef void function(GLUquadric*,GLdouble,GLint,GLint) pfgluSphere;
pfgluCylinder               gluCylinder;
pfgluDisk                   gluDisk;
pfgluPartialDisk            gluPartialDisk;
pfgluSphere                 gluSphere;

typedef void function(GLUnurbs*) pfgluBeginCurve;
typedef void function(GLUtesselator*) pfgluBeginPolygon;
typedef void function(GLUnurbs*) pfgluBeginSurface;
typedef void function(GLUnurbs*) pfgluBeginTrim;
typedef void function(GLUnurbs*) pfgluEndCurve;
typedef void function(GLUtesselator*) pfgluEndPolygon;
typedef void function(GLUnurbs*) pfgluEndSurface;
typedef void function(GLUnurbs*) pfgluEndTrim;
pfgluBeginCurve             gluBeginCurve;
pfgluBeginPolygon           gluBeginPolygon;
pfgluBeginSurface           gluBeginSurface;
pfgluBeginTrim              gluBeginTrim;
pfgluEndCurve               gluEndCurve;
pfgluEndPolygon             gluEndPolygon;
pfgluEndSurface             gluEndSurface;
pfgluEndTrim                gluEndTrim;

typedef void function(GLUnurbs*) pfgluDeleteNurbsRenderer;
typedef void function(GLUquadric*) pfgluDeleteQuadric;
typedef void function(GLUtesselator*) pfgluDeleteTess;
typedef void function(GLUnurbs*,GLenum,GLfloat*) pfgluGetNurbsProperty;
typedef void function(GLUtesselator*,GLenum,GLdouble*) pfgluGetTessProperty;
typedef void function(GLUnurbs*,GLfloat*,GLfloat*,GLint*) pfgluLoadSamplingMatrices;
typedef GLUnurbs* function() pfgluNewNurbsRenderer;
typedef GLUquadric* function() pfgluNewQuadric;
typedef GLUtesselator* function() pfgluNewTess;
pfgluDeleteNurbsRenderer    gluDeleteNurbsRenderer;
pfgluDeleteQuadric          gluDeleteQuadric;
pfgluDeleteTess             gluDeleteTess;
pfgluGetNurbsProperty       gluGetNurbsProperty;
pfgluGetTessProperty        gluGetTessProperty;
pfgluLoadSamplingMatrices   gluLoadSamplingMatrices;
pfgluNewNurbsRenderer       gluNewNurbsRenderer;
pfgluNewQuadric             gluNewQuadric;
pfgluNewTess                gluNewTess;

typedef void function(GLUtesselator*,GLenum) pfgluNextContour;
typedef void function(GLUnurbs*,GLenum,_GLUfuncptr) pfgluNurbsCallback;
typedef void function(GLUnurbs*,GLvoid*) pfgluNurbsCallbackData;
typedef void function(GLUnurbs*,GLvoid*) pfgluNurbsCallbackDataEXT;
typedef void function(GLUnurbs*,GLint,GLfloat*,GLint,GLfloat*,GLint,GLenum) pfgluNurbsCurve;
typedef void function(GLUnurbs*,GLenum,GLfloat) pfgluNurbsProperty;
typedef void function(GLUnurbs*,GLint,GLfloat*,GLint,GLfloat*,GLint,GLint,GLfloat*,GLint,GLint,GLenum) pfgluNurbsSurface;
typedef void function(GLUnurbs*,GLint,GLfloat*,GLint,GLenum) pfgluPwlCurve;
pfgluNextContour            gluNextContour;
pfgluNurbsCallback          gluNurbsCallback;
//pfgluNurbsCallbackData        gluNurbsCallbackData;
//pfgluNurbsCallbackDataEXT gluNurbsCallbackDataEXT;
pfgluNurbsCurve             gluNurbsCurve;
pfgluNurbsProperty          gluNurbsProperty;
pfgluNurbsSurface           gluNurbsSurface;
pfgluPwlCurve               gluPwlCurve;

typedef void function(GLUquadric*,GLenum,_GLUfuncptr) pfgluQuadricCallback;
typedef void function(GLUquadric*,GLenum) pfgluQuadricDrawStyle;
typedef void function(GLUquadric*,GLenum) pfgluQuadricNormals;
typedef void function(GLUquadric*,GLenum) pfgluQuadricOrientation;
typedef void function(GLUquadric*,GLboolean) pfgluQuadricTexture;
pfgluQuadricCallback        gluQuadricCallback;
pfgluQuadricDrawStyle       gluQuadricDrawStyle;
pfgluQuadricNormals         gluQuadricNormals;
pfgluQuadricOrientation     gluQuadricOrientation;
pfgluQuadricTexture         gluQuadricTexture;

typedef void function(GLUtesselator*) pfgluTessBeginContour;
typedef void function(GLUtesselator*,GLvoid*) pfgluTessBeginPolygon;
typedef void function(GLUtesselator*,GLenum,_GLUfuncptr) pfgluTessCallback;
typedef void function(GLUtesselator*) pfgluTessEndContour;
typedef void function(GLUtesselator*) pfgluTessEndPolygon;
typedef void function(GLUtesselator*,GLdouble,GLdouble,GLdouble) pfgluTessNormal;
typedef void function(GLUtesselator*,GLenum,GLdouble) pfgluTessProperty;
typedef void function(GLUtesselator*,GLdouble*,GLvoid*) pfgluTessVertex;
pfgluTessBeginContour       gluTessBeginContour;
pfgluTessBeginPolygon       gluTessBeginPolygon;
pfgluTessCallback           gluTessCallback;
pfgluTessEndContour         gluTessEndContour;
pfgluTessEndPolygon         gluTessEndPolygon;
pfgluTessProperty			gluTessProperty;
pfgluTessNormal             gluTessNormal;

pfgluTessVertex             gluTessVertex;

typedef void function(GLdouble,GLdouble,GLdouble,GLdouble,GLdouble,GLdouble,GLdouble,GLdouble,GLdouble) pfgluLookAt;
typedef void function(GLdouble,GLdouble,GLdouble,GLdouble) pfgluOrtho2D;
typedef void function(GLdouble,GLdouble,GLdouble,GLdouble) pfgluPerspective;
typedef void function(GLdouble,GLdouble,GLdouble,GLdouble,GLint*) pfgluPickMatrix;
typedef GLint function(GLdouble,GLdouble,GLdouble,GLdouble*,GLdouble*,GLint*,GLdouble*,GLdouble*,GLdouble*) pfgluProject;
typedef GLint function(GLenum,GLsizei,GLsizei,GLenum,void*,GLsizei,GLsizei,GLenum,GLvoid*) pfgluScaleImage;
typedef GLint function(GLdouble,GLdouble,GLdouble,GLdouble*,GLdouble*,GLint*,GLdouble*,GLdouble*,GLdouble*) pfgluUnProject;
typedef GLint function(GLdouble,GLdouble,GLdouble,GLdouble,GLdouble*,GLdouble*,GLint*,GLdouble,GLdouble,GLdouble*,GLdouble*,GLdouble*,GLdouble*) pfgluUnProject4;
pfgluLookAt                 gluLookAt;
pfgluOrtho2D                gluOrtho2D;
pfgluPerspective            gluPerspective;
pfgluPickMatrix             gluPickMatrix;
pfgluProject                gluProject;
pfgluScaleImage             gluScaleImage;
pfgluUnProject              gluUnProject;
//pfgluUnProject4               gluUnProject4;
