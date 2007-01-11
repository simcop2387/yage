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
module derelict.opengl.gltypes;

alias uint      GLenum;
alias ubyte     GLboolean;
alias uint      GLbitfield;
alias void      GLvoid;
alias byte      GLbyte;
alias short     GLshort;
alias int       GLint;
alias ubyte     GLubyte;
alias ushort    GLushort;
alias uint      GLuint;
alias int       GLsizei;
alias float     GLfloat;
alias float     GLclampf;
alias double    GLdouble;
alias double    GLclampd;
alias char      GLchar;
alias ptrdiff_t GLintptr;
alias ptrdiff_t GLsizeiptr;

// Boolean values
const ubyte GL_FALSE                                = 0x0;
const ubyte GL_TRUE                                 = 0x1;

// Data types
const GLenum GL_BYTE                                = 0x1400;
const GLenum GL_UNSIGNED_BYTE                       = 0x1401;
const GLenum GL_SHORT                               = 0x1402;
const GLenum GL_UNSIGNED_SHORT                      = 0x1403;
const GLenum GL_INT                                 = 0x1404;
const GLenum GL_UNSIGNED_INT                        = 0x1405;
const GLenum GL_FLOAT                               = 0x1406;
const GLenum GL_DOUBLE                              = 0x140A;
const GLenum GL_2_BYTES                             = 0x1407;
const GLenum GL_3_BYTES                             = 0x1408;
const GLenum GL_4_BYTES                             = 0x1409;

// Primitives
const GLenum GL_POINTS                              = 0x0000;
const GLenum GL_LINES                               = 0x0001;
const GLenum GL_LINE_LOOP                           = 0x0002;
const GLenum GL_LINE_STRIP                          = 0x0003;
const GLenum GL_TRIANGLES                           = 0x0004;
const GLenum GL_TRIANGLE_STRIP                      = 0x0005;
const GLenum GL_TRIANGLE_FAN                        = 0x0006;
const GLenum GL_QUADS                               = 0x0007;
const GLenum GL_QUAD_STRIP                          = 0x0008;
const GLenum GL_POLYGON                             = 0x0009;

// Vertex Arrays
const GLenum GL_VERTEX_ARRAY                        = 0x8074;
const GLenum GL_NORMAL_ARRAY                        = 0x8075;
const GLenum GL_COLOR_ARRAY                         = 0x8076;
const GLenum GL_INDEX_ARRAY                         = 0x8077;
const GLenum GL_TEXTURE_COORD_ARRAY                 = 0x8078;
const GLenum GL_EDGE_FLAG_ARRAY                     = 0x8079;
const GLenum GL_VERTEX_ARRAY_SIZE                   = 0x807A;
const GLenum GL_VERTEX_ARRAY_TYPE                   = 0x807B;
const GLenum GL_VERTEX_ARRAY_STRIDE                 = 0x807C;
const GLenum GL_NORMAL_ARRAY_TYPE                   = 0x807E;
const GLenum GL_NORMAL_ARRAY_STRIDE                 = 0x807F;
const GLenum GL_COLOR_ARRAY_SIZE                    = 0x8081;
const GLenum GL_COLOR_ARRAY_TYPE                    = 0x8082;
const GLenum GL_COLOR_ARRAY_STRIDE                  = 0x8083;
const GLenum GL_INDEX_ARRAY_TYPE                    = 0x8085;
const GLenum GL_INDEX_ARRAY_STRIDE                  = 0x8086;
const GLenum GL_TEXTURE_COORD_ARRAY_SIZE            = 0x8088;
const GLenum GL_TEXTURE_COORD_ARRAY_TYPE            = 0x8089;
const GLenum GL_TEXTURE_COORD_ARRAY_STRIDE          = 0x808A;
const GLenum GL_EDGE_FLAG_ARRAY_STRIDE              = 0x808C;
const GLenum GL_VERTEX_ARRAY_POINTER                = 0x808E;
const GLenum GL_NORMAL_ARRAY_POINTER                = 0x808F;
const GLenum GL_COLOR_ARRAY_POINTER                 = 0x8090;
const GLenum GL_INDEX_ARRAY_POINTER                 = 0x8091;
const GLenum GL_TEXTURE_COORD_ARRAY_POINTER         = 0x8092;
const GLenum GL_EDGE_FLAG_ARRAY_POINTER             = 0x8093;
const GLenum GL_V2F                                 = 0x2A20;
const GLenum GL_V3F                                 = 0x2A21;
const GLenum GL_C4UB_V2F                            = 0x2A22;
const GLenum GL_C4UB_V3F                            = 0x2A23;
const GLenum GL_C3F_V3F                             = 0x2A24;
const GLenum GL_N3F_V3F                             = 0x2A25;
const GLenum GL_C4F_N3F_V3F                         = 0x2A26;
const GLenum GL_T2F_V3F                             = 0x2A27;
const GLenum GL_T4F_V4F                             = 0x2A28;
const GLenum GL_T2F_C4UB_V3F                        = 0x2A29;
const GLenum GL_T2F_C3F_V3F                         = 0x2A2A;
const GLenum GL_T2F_N3F_V3F                         = 0x2A2B;
const GLenum GL_T2F_C4F_N3F_V3F                     = 0x2A2C;
const GLenum GL_T4F_C4F_N3F_V4F                     = 0x2A2D;

// Matrix Mode
const GLenum GL_MATRIX_MODE                         = 0x0BA0;
const GLenum GL_MODELVIEW                           = 0x1700;
const GLenum GL_PROJECTION                          = 0x1701;
const GLenum GL_TEXTURE                             = 0x1702;

// Points
const GLenum GL_POINT_SMOOTH                        = 0x0B10;
const GLenum GL_POINT_SIZE                          = 0x0B11;
const GLenum GL_POINT_SIZE_GRANULARITY              = 0x0B13;
const GLenum GL_POINT_SIZE_RANGE                    = 0x0B12;

// Lines
const GLenum GL_LINE_SMOOTH                         = 0x0B20;
const GLenum GL_LINE_STIPPLE                        = 0x0B24;
const GLenum GL_LINE_STIPPLE_PATTERN                = 0x0B25;
const GLenum GL_LINE_STIPPLE_REPEAT                 = 0x0B26;
const GLenum GL_LINE_WIDTH                          = 0x0B21;
const GLenum GL_LINE_WIDTH_GRANULARITY              = 0x0B23;
const GLenum GL_LINE_WIDTH_RANGE                    = 0x0B22;

// Polygons
const GLenum GL_POINT                               = 0x1B00;
const GLenum GL_LINE                                = 0x1B01;
const GLenum GL_FILL                                = 0x1B02;
const GLenum GL_CW                                  = 0x0900;
const GLenum GL_CCW                                 = 0x0901;
const GLenum GL_FRONT                               = 0x0404;
const GLenum GL_BACK                                = 0x0405;
const GLenum GL_POLYGON_MODE                        = 0x0B40;
const GLenum GL_POLYGON_SMOOTH                      = 0x0B41;
const GLenum GL_POLYGON_STIPPLE                     = 0x0B42;
const GLenum GL_EDGE_FLAG                           = 0x0B43;
const GLenum GL_CULL_FACE                           = 0x0B44;
const GLenum GL_CULL_FACE_MODE                      = 0x0B45;
const GLenum GL_FRONT_FACE                          = 0x0B46;
const GLenum GL_POLYGON_OFFSET_FACTOR               = 0x8038;
const GLenum GL_POLYGON_OFFSET_UNITS                = 0x2A00;
const GLenum GL_POLYGON_OFFSET_POINT                = 0x2A01;
const GLenum GL_POLYGON_OFFSET_LINE                 = 0x2A02;
const GLenum GL_POLYGON_OFFSET_FILL                 = 0x8037;

// Display Lists
const GLenum GL_COMPILE                             = 0x1300;
const GLenum GL_COMPILE_AND_EXECUTE                 = 0x1301;
const GLenum GL_LIST_BASE                           = 0x0B32;
const GLenum GL_LIST_INDEX                          = 0x0B33;
const GLenum GL_LIST_MODE                           = 0x0B30;

// Depth buffer
const GLenum GL_NEVER                               = 0x0200;
const GLenum GL_LESS                                = 0x0201;
const GLenum GL_EQUAL                               = 0x0202;
const GLenum GL_LEQUAL                              = 0x0203;
const GLenum GL_GREATER                             = 0x0204;
const GLenum GL_NOTEQUAL                            = 0x0205;
const GLenum GL_GEQUAL                              = 0x0206;
const GLenum GL_ALWAYS                              = 0x0207;
const GLenum GL_DEPTH_TEST                          = 0x0B71;
const GLenum GL_DEPTH_BITS                          = 0x0D56;
const GLenum GL_DEPTH_CLEAR_VALUE                   = 0x0B73;
const GLenum GL_DEPTH_FUNC                          = 0x0B74;
const GLenum GL_DEPTH_RANGE                         = 0x0B70;
const GLenum GL_DEPTH_WRITEMASK                     = 0x0B72;
const GLenum GL_DEPTH_COMPONENT                     = 0x1902;

// Lighting
const GLenum GL_LIGHTING                            = 0x0B50;
const GLenum GL_LIGHT0                              = 0x4000;
const GLenum GL_LIGHT1                              = 0x4001;
const GLenum GL_LIGHT2                              = 0x4002;
const GLenum GL_LIGHT3                              = 0x4003;
const GLenum GL_LIGHT4                              = 0x4004;
const GLenum GL_LIGHT5                              = 0x4005;
const GLenum GL_LIGHT6                              = 0x4006;
const GLenum GL_LIGHT7                              = 0x4007;
const GLenum GL_SPOT_EXPONENT                       = 0x1205;
const GLenum GL_SPOT_CUTOFF                         = 0x1206;
const GLenum GL_CONSTANT_ATTENUATION                = 0x1207;
const GLenum GL_LINEAR_ATTENUATION                  = 0x1208;
const GLenum GL_QUADRATIC_ATTENUATION               = 0x1209;
const GLenum GL_AMBIENT                             = 0x1200;
const GLenum GL_DIFFUSE                             = 0x1201;
const GLenum GL_SPECULAR                            = 0x1202;
const GLenum GL_SHININESS                           = 0x1601;
const GLenum GL_EMISSION                            = 0x1600;
const GLenum GL_POSITION                            = 0x1203;
const GLenum GL_SPOT_DIRECTION                      = 0x1204;
const GLenum GL_AMBIENT_AND_DIFFUSE                 = 0x1602;
const GLenum GL_COLOR_INDEXES                       = 0x1603;
const GLenum GL_LIGHT_MODEL_TWO_SIDE                = 0x0B52;
const GLenum GL_LIGHT_MODEL_LOCAL_VIEWER            = 0x0B51;
const GLenum GL_LIGHT_MODEL_AMBIENT                 = 0x0B53;
const GLenum GL_FRONT_AND_BACK                      = 0x0408;
const GLenum GL_SHADE_MODEL                         = 0x0B54;
const GLenum GL_FLAT                                = 0x1D00;
const GLenum GL_SMOOTH                              = 0x1D01;
const GLenum GL_COLOR_MATERIAL                      = 0x0B57;
const GLenum GL_COLOR_MATERIAL_FACE                 = 0x0B55;
const GLenum GL_COLOR_MATERIAL_PARAMETER            = 0x0B56;
const GLenum GL_NORMALIZE                           = 0x0BA1;

// User clipping planes
const GLenum GL_CLIP_PLANE0                         = 0x3000;
const GLenum GL_CLIP_PLANE1                         = 0x3001;
const GLenum GL_CLIP_PLANE2                         = 0x3002;
const GLenum GL_CLIP_PLANE3                         = 0x3003;
const GLenum GL_CLIP_PLANE4                         = 0x3004;
const GLenum GL_CLIP_PLANE5                         = 0x3005;

// Accumulation buffer
const GLenum GL_ACCUM_RED_BITS                      = 0x0D58;
const GLenum GL_ACCUM_GREEN_BITS                    = 0x0D59;
const GLenum GL_ACCUM_BLUE_BITS                     = 0x0D5A;
const GLenum GL_ACCUM_ALPHA_BITS                    = 0x0D5B;
const GLenum GL_ACCUM_CLEAR_VALUE                   = 0x0B80;
const GLenum GL_ACCUM                               = 0x0100;
const GLenum GL_ADD                                 = 0x0104;
const GLenum GL_LOAD                                = 0x0101;
const GLenum GL_MULT                                = 0x0103;
const GLenum GL_RETURN                              = 0x0102;

// Alpha testing
const GLenum GL_ALPHA_TEST                          = 0x0BC0;
const GLenum GL_ALPHA_TEST_REF                      = 0x0BC2;
const GLenum GL_ALPHA_TEST_FUNC                     = 0x0BC1;

// Blending
const GLenum GL_BLEND                               = 0x0BE2;
const GLenum GL_BLEND_SRC                           = 0x0BE1;
const GLenum GL_BLEND_DST                           = 0x0BE0;
const GLenum GL_ZERO                                = 0x0;
const GLenum GL_ONE                                 = 0x1;
const GLenum GL_SRC_COLOR                           = 0x0300;
const GLenum GL_ONE_MINUS_SRC_COLOR                 = 0x0301;
const GLenum GL_SRC_ALPHA                           = 0x0302;
const GLenum GL_ONE_MINUS_SRC_ALPHA                 = 0x0303;
const GLenum GL_DST_ALPHA                           = 0x0304;
const GLenum GL_ONE_MINUS_DST_ALPHA                 = 0x0305;
const GLenum GL_DST_COLOR                           = 0x0306;
const GLenum GL_ONE_MINUS_DST_COLOR                 = 0x0307;
const GLenum GL_SRC_ALPHA_SATURATE                  = 0x0308;
const GLenum GL_CONSTANT_COLOR                      = 0x8001;
const GLenum GL_ONE_MINUS_CONSTANT_COLOR            = 0x8002;
const GLenum GL_CONSTANT_ALPHA                      = 0x8003;
const GLenum GL_ONE_MINUS_CONSTANT_ALPHA            = 0x8004;

// Render Mode
const GLenum GL_FEEDBACK                            = 0x1C01;
const GLenum GL_RENDER                              = 0x1C00;
const GLenum GL_SELECT                              = 0x1C02;

// Feedback
const GLenum GL_2D                                  = 0x0600;
const GLenum GL_3D                                  = 0x0601;
const GLenum GL_3D_COLOR                            = 0x0602;
const GLenum GL_3D_COLOR_TEXTURE                    = 0x0603;
const GLenum GL_4D_COLOR_TEXTURE                    = 0x0604;
const GLenum GL_POINT_TOKEN                         = 0x0701;
const GLenum GL_LINE_TOKEN                          = 0x0702;
const GLenum GL_LINE_RESET_TOKEN                    = 0x0707;
const GLenum GL_POLYGON_TOKEN                       = 0x0703;
const GLenum GL_BITMAP_TOKEN                        = 0x0704;
const GLenum GL_DRAW_PIXEL_TOKEN                    = 0x0705;
const GLenum GL_COPY_PIXEL_TOKEN                    = 0x0706;
const GLenum GL_PASS_THROUGH_TOKEN                  = 0x0700;
const GLenum GL_FEEDBACK_BUFFER_POINTER             = 0x0DF0;
const GLenum GL_FEEDBACK_BUFFER_SIZE                = 0x0DF1;
const GLenum GL_FEEDBACK_BUFFER_TYPE                = 0x0DF2;

// Selection
const GLenum GL_SELECTION_BUFFER_POINTER            = 0x0DF3;
const GLenum GL_SELECTION_BUFFER_SIZE               = 0x0DF4;

// Fog
const GLenum GL_FOG                                 = 0x0B60;
const GLenum GL_FOG_MODE                            = 0x0B65;
const GLenum GL_FOG_DENSITY                         = 0x0B62;
const GLenum GL_FOG_COLOR                           = 0x0B66;
const GLenum GL_FOG_INDEX                           = 0x0B61;
const GLenum GL_FOG_START                           = 0x0B63;
const GLenum GL_FOG_END                             = 0x0B64;
const GLenum GL_LINEAR                              = 0x2601;
const GLenum GL_EXP                                 = 0x0800;
const GLenum GL_EXP2                                = 0x0801;

// Logic Ops
const GLenum GL_LOGIC_OP                            = 0x0BF1;
const GLenum GL_INDEX_LOGIC_OP                      = 0x0BF1;
const GLenum GL_COLOR_LOGIC_OP                      = 0x0BF2;
const GLenum GL_LOGIC_OP_MODE                       = 0x0BF0;
const GLenum GL_CLEAR                               = 0x1500;
const GLenum GL_SET                                 = 0x150F;
const GLenum GL_COPY                                = 0x1503;
const GLenum GL_COPY_INVERTED                       = 0x150C;
const GLenum GL_NOOP                                = 0x1505;
const GLenum GL_INVERT                              = 0x150A;
const GLenum GL_AND                                 = 0x1501;
const GLenum GL_NAND                                = 0x150E;
const GLenum GL_OR                                  = 0x1507;
const GLenum GL_NOR                                 = 0x1508;
const GLenum GL_XOR                                 = 0x1506;
const GLenum GL_EQUIV                               = 0x1509;
const GLenum GL_AND_REVERSE                         = 0x1502;
const GLenum GL_AND_INVERTED                        = 0x1504;
const GLenum GL_OR_REVERSE                          = 0x150B;
const GLenum GL_OR_INVERTED                         = 0x150D;

// Stencil
const GLenum GL_STENCIL_TEST                        = 0x0B90;
const GLenum GL_STENCIL_WRITEMASK                   = 0x0B98;
const GLenum GL_STENCIL_BITS                        = 0x0D57;
const GLenum GL_STENCIL_FUNC                        = 0x0B92;
const GLenum GL_STENCIL_VALUE_MASK                  = 0x0B93;
const GLenum GL_STENCIL_REF                         = 0x0B97;
const GLenum GL_STENCIL_FAIL                        = 0x0B94;
const GLenum GL_STENCIL_PASS_DEPTH_PASS             = 0x0B96;
const GLenum GL_STENCIL_PASS_DEPTH_FAIL             = 0x0B95;
const GLenum GL_STENCIL_CLEAR_VALUE                 = 0x0B91;
const GLenum GL_STENCIL_INDEX                       = 0x1901;
const GLenum GL_KEEP                                = 0x1E00;
const GLenum GL_REPLACE                             = 0x1E01;
const GLenum GL_INCR                                = 0x1E02;
const GLenum GL_DECR                                = 0x1E03;

// Buffers, Pixel Drawing/Reading
const GLenum GL_NONE                                = 0x0;
const GLenum GL_LEFT                                = 0x0406;
const GLenum GL_RIGHT                               = 0x0407;
const GLenum GL_FRONT_LEFT                          = 0x0400;
const GLenum GL_FRONT_RIGHT                         = 0x0401;
const GLenum GL_BACK_LEFT                           = 0x0402;
const GLenum GL_BACK_RIGHT                          = 0x0403;
const GLenum GL_AUX0                                = 0x0409;
const GLenum GL_AUX1                                = 0x040A;
const GLenum GL_AUX2                                = 0x040B;
const GLenum GL_AUX3                                = 0x040C;
const GLenum GL_COLOR_INDEX                         = 0x1900;
const GLenum GL_RED                                 = 0x1903;
const GLenum GL_GREEN                               = 0x1904;
const GLenum GL_BLUE                                = 0x1905;
const GLenum GL_ALPHA                               = 0x1906;
const GLenum GL_LUMINANCE                           = 0x1909;
const GLenum GL_LUMINANCE_ALPHA                     = 0x190A;
const GLenum GL_ALPHA_BITS                          = 0x0D55;
const GLenum GL_RED_BITS                            = 0x0D52;
const GLenum GL_GREEN_BITS                          = 0x0D53;
const GLenum GL_BLUE_BITS                           = 0x0D54;
const GLenum GL_INDEX_BITS                          = 0x0D51;
const GLenum GL_SUBPIXEL_BITS                       = 0x0D50;
const GLenum GL_AUX_BUFFERS                         = 0x0C00;
const GLenum GL_READ_BUFFER                         = 0x0C02;
const GLenum GL_DRAW_BUFFER                         = 0x0C01;
const GLenum GL_DOUBLEBUFFER                        = 0x0C32;
const GLenum GL_STEREO                              = 0x0C33;
const GLenum GL_BITMAP                              = 0x1A00;
const GLenum GL_COLOR                               = 0x1800;
const GLenum GL_DEPTH                               = 0x1801;
const GLenum GL_STENCIL                             = 0x1802;
const GLenum GL_DITHER                              = 0x0BD0;
const GLenum GL_RGB                                 = 0x1907;
const GLenum GL_RGBA                                = 0x1908;

// Implementation limits
const GLenum GL_MAX_LIST_NESTING                    = 0x0B31;
const GLenum GL_MAX_ATTRIB_STACK_DEPTH              = 0x0D35;
const GLenum GL_MAX_MODELVIEW_STACK_DEPTH           = 0x0D36;
const GLenum GL_MAX_NAME_STACK_DEPTH                = 0x0D37;
const GLenum GL_MAX_PROJECTION_STACK_DEPTH          = 0x0D38;
const GLenum GL_MAX_TEXTURE_STACK_DEPTH             = 0x0D39;
const GLenum GL_MAX_EVAL_ORDER                      = 0x0D30;
const GLenum GL_MAX_LIGHTS                          = 0x0D31;
const GLenum GL_MAX_CLIP_PLANES                     = 0x0D32;
const GLenum GL_MAX_TEXTURE_SIZE                    = 0x0D33;
const GLenum GL_MAX_PIXEL_MAP_TABLE                 = 0x0D34;
const GLenum GL_MAX_VIEWPORT_DIMS                   = 0x0D3A;
const GLenum GL_MAX_CLIENT_ATTRIB_STACK_DEPTH       = 0x0D3B;

// Gets
const GLenum GL_ATTRIB_STACK_DEPTH                  = 0x0BB0;
const GLenum GL_CLIENT_ATTRIB_STACK_DEPTH           = 0x0BB1;
const GLenum GL_COLOR_CLEAR_VALUE                   = 0x0C22;
const GLenum GL_COLOR_WRITEMASK                     = 0x0C23;
const GLenum GL_CURRENT_INDEX                       = 0x0B01;
const GLenum GL_CURRENT_COLOR                       = 0x0B00;
const GLenum GL_CURRENT_NORMAL                      = 0x0B02;
const GLenum GL_CURRENT_RASTER_COLOR                = 0x0B04;
const GLenum GL_CURRENT_RASTER_DISTANCE             = 0x0B09;
const GLenum GL_CURRENT_RASTER_INDEX                = 0x0B05;
const GLenum GL_CURRENT_RASTER_POSITION             = 0x0B07;
const GLenum GL_CURRENT_RASTER_TEXTURE_COORDS       = 0x0B06;
const GLenum GL_CURRENT_RASTER_POSITION_VALID       = 0x0B08;
const GLenum GL_CURRENT_TEXTURE_COORDS              = 0x0B03;
const GLenum GL_INDEX_CLEAR_VALUE                   = 0x0C20;
const GLenum GL_INDEX_MODE                          = 0x0C30;
const GLenum GL_INDEX_WRITEMASK                     = 0x0C21;
const GLenum GL_MODELVIEW_MATRIX                    = 0x0BA6;
const GLenum GL_MODELVIEW_STACK_DEPTH               = 0x0BA3;
const GLenum GL_NAME_STACK_DEPTH                    = 0x0D70;
const GLenum GL_PROJECTION_MATRIX                   = 0x0BA7;
const GLenum GL_PROJECTION_STACK_DEPTH              = 0x0BA4;
const GLenum GL_RENDER_MODE                         = 0x0C40;
const GLenum GL_RGBA_MODE                           = 0x0C31;
const GLenum GL_TEXTURE_MATRIX                      = 0x0BA8;
const GLenum GL_TEXTURE_STACK_DEPTH                 = 0x0BA5;
const GLenum GL_VIEWPORT                            = 0x0BA2;

// Evaluators
const GLenum GL_AUTO_NORMAL                         = 0x0D80;
const GLenum GL_MAP1_COLOR_4                        = 0x0D90;
const GLenum GL_MAP1_GRID_DOMAIN                    = 0x0DD0;
const GLenum GL_MAP1_GRID_SEGMENTS                  = 0x0DD1;
const GLenum GL_MAP1_INDEX                          = 0x0D91;
const GLenum GL_MAP1_NORMAL                         = 0x0D92;
const GLenum GL_MAP1_TEXTURE_COORD_1                = 0x0D93;
const GLenum GL_MAP1_TEXTURE_COORD_2                = 0x0D94;
const GLenum GL_MAP1_TEXTURE_COORD_3                = 0x0D95;
const GLenum GL_MAP1_TEXTURE_COORD_4                = 0x0D96;
const GLenum GL_MAP1_VERTEX_3                       = 0x0D97;
const GLenum GL_MAP1_VERTEX_4                       = 0x0D98;
const GLenum GL_MAP2_COLOR_4                        = 0x0DB0;
const GLenum GL_MAP2_GRID_DOMAIN                    = 0x0DD2;
const GLenum GL_MAP2_GRID_SEGMENTS                  = 0x0DD3;
const GLenum GL_MAP2_INDEX                          = 0x0DB1;
const GLenum GL_MAP2_NORMAL                         = 0x0DB2;
const GLenum GL_MAP2_TEXTURE_COORD_1                = 0x0DB3;
const GLenum GL_MAP2_TEXTURE_COORD_2                = 0x0DB4;
const GLenum GL_MAP2_TEXTURE_COORD_3                = 0x0DB5;
const GLenum GL_MAP2_TEXTURE_COORD_4                = 0x0DB6;
const GLenum GL_MAP2_VERTEX_3                       = 0x0DB7;
const GLenum GL_MAP2_VERTEX_4                       = 0x0DB8;
const GLenum GL_COEFF                               = 0x0A00;
const GLenum GL_DOMAIN                              = 0x0A02;
const GLenum GL_ORDER                               = 0x0A01;

// Hints
const GLenum GL_FOG_HINT                            = 0x0C54;
const GLenum GL_LINE_SMOOTH_HINT                    = 0x0C52;
const GLenum GL_PERSPECTIVE_CORRECTION_HINT         = 0x0C50;
const GLenum GL_POINT_SMOOTH_HINT                   = 0x0C51;
const GLenum GL_POLYGON_SMOOTH_HINT                 = 0x0C53;
const GLenum GL_DONT_CARE                           = 0x1100;
const GLenum GL_FASTEST                             = 0x1101;
const GLenum GL_NICEST                              = 0x1102;

// Scissor box
const GLenum GL_SCISSOR_TEST                        = 0x0C11;
const GLenum GL_SCISSOR_BOX                         = 0x0C10;

// Pixel Mode / Transfer
const GLenum GL_MAP_COLOR                           = 0x0D10;
const GLenum GL_MAP_STENCIL                         = 0x0D11;
const GLenum GL_INDEX_SHIFT                         = 0x0D12;
const GLenum GL_INDEX_OFFSET                        = 0x0D13;
const GLenum GL_RED_SCALE                           = 0x0D14;
const GLenum GL_RED_BIAS                            = 0x0D15;
const GLenum GL_GREEN_SCALE                         = 0x0D18;
const GLenum GL_GREEN_BIAS                          = 0x0D19;
const GLenum GL_BLUE_SCALE                          = 0x0D1A;
const GLenum GL_BLUE_BIAS                           = 0x0D1B;
const GLenum GL_ALPHA_SCALE                         = 0x0D1C;
const GLenum GL_ALPHA_BIAS                          = 0x0D1D;
const GLenum GL_DEPTH_SCALE                         = 0x0D1E;
const GLenum GL_DEPTH_BIAS                          = 0x0D1F;
const GLenum GL_PIXEL_MAP_S_TO_S_SIZE               = 0x0CB1;
const GLenum GL_PIXEL_MAP_I_TO_I_SIZE               = 0x0CB0;
const GLenum GL_PIXEL_MAP_I_TO_R_SIZE               = 0x0CB2;
const GLenum GL_PIXEL_MAP_I_TO_G_SIZE               = 0x0CB3;
const GLenum GL_PIXEL_MAP_I_TO_B_SIZE               = 0x0CB4;
const GLenum GL_PIXEL_MAP_I_TO_A_SIZE               = 0x0CB5;
const GLenum GL_PIXEL_MAP_R_TO_R_SIZE               = 0x0CB6;
const GLenum GL_PIXEL_MAP_G_TO_G_SIZE               = 0x0CB7;
const GLenum GL_PIXEL_MAP_B_TO_B_SIZE               = 0x0CB8;
const GLenum GL_PIXEL_MAP_A_TO_A_SIZE               = 0x0CB9;
const GLenum GL_PIXEL_MAP_S_TO_S                    = 0x0C71;
const GLenum GL_PIXEL_MAP_I_TO_I                    = 0x0C70;
const GLenum GL_PIXEL_MAP_I_TO_R                    = 0x0C72;
const GLenum GL_PIXEL_MAP_I_TO_G                    = 0x0C73;
const GLenum GL_PIXEL_MAP_I_TO_B                    = 0x0C74;
const GLenum GL_PIXEL_MAP_I_TO_A                    = 0x0C75;
const GLenum GL_PIXEL_MAP_R_TO_R                    = 0x0C76;
const GLenum GL_PIXEL_MAP_G_TO_G                    = 0x0C77;
const GLenum GL_PIXEL_MAP_B_TO_B                    = 0x0C78;
const GLenum GL_PIXEL_MAP_A_TO_A                    = 0x0C79;
const GLenum GL_PACK_ALIGNMENT                      = 0x0D05;
const GLenum GL_PACK_LSB_FIRST                      = 0x0D01;
const GLenum GL_PACK_ROW_LENGTH                     = 0x0D02;
const GLenum GL_PACK_SKIP_PIXELS                    = 0x0D04;
const GLenum GL_PACK_SKIP_ROWS                      = 0x0D03;
const GLenum GL_PACK_SWAP_BYTES                     = 0x0D00;
const GLenum GL_UNPACK_ALIGNMENT                    = 0x0CF5;
const GLenum GL_UNPACK_LSB_FIRST                    = 0x0CF1;
const GLenum GL_UNPACK_ROW_LENGTH                   = 0x0CF2;
const GLenum GL_UNPACK_SKIP_PIXELS                  = 0x0CF4;
const GLenum GL_UNPACK_SKIP_ROWS                    = 0x0CF3;
const GLenum GL_UNPACK_SWAP_BYTES                   = 0x0CF0;
const GLenum GL_ZOOM_X                              = 0x0D16;
const GLenum GL_ZOOM_Y                              = 0x0D17;

// Texture mapping
const GLenum GL_TEXTURE_ENV                         = 0x2300;
const GLenum GL_TEXTURE_ENV_MODE                    = 0x2200;
const GLenum GL_TEXTURE_1D                          = 0x0DE0;
const GLenum GL_TEXTURE_2D                          = 0x0DE1;
const GLenum GL_TEXTURE_WRAP_S                      = 0x2802;
const GLenum GL_TEXTURE_WRAP_T                      = 0x2803;
const GLenum GL_TEXTURE_MAG_FILTER                  = 0x2800;
const GLenum GL_TEXTURE_MIN_FILTER                  = 0x2801;
const GLenum GL_TEXTURE_ENV_COLOR                   = 0x2201;
const GLenum GL_TEXTURE_GEN_S                       = 0x0C60;
const GLenum GL_TEXTURE_GEN_T                       = 0x0C61;
const GLenum GL_TEXTURE_GEN_MODE                    = 0x2500;
const GLenum GL_TEXTURE_BORDER_COLOR                = 0x1004;
const GLenum GL_TEXTURE_WIDTH                       = 0x1000;
const GLenum GL_TEXTURE_HEIGHT                      = 0x1001;
const GLenum GL_TEXTURE_BORDER                      = 0x1005;
const GLenum GL_TEXTURE_COMPONENTS                  = 0x1003;
const GLenum GL_TEXTURE_RED_SIZE                    = 0x805C;
const GLenum GL_TEXTURE_GREEN_SIZE                  = 0x805D;
const GLenum GL_TEXTURE_BLUE_SIZE                   = 0x805E;
const GLenum GL_TEXTURE_ALPHA_SIZE                  = 0x805F;
const GLenum GL_TEXTURE_LUMINANCE_SIZE              = 0x8060;
const GLenum GL_TEXTURE_INTENSITY_SIZE              = 0x8061;
const GLenum GL_NEAREST_MIPMAP_NEAREST              = 0x2700;
const GLenum GL_NEAREST_MIPMAP_LINEAR               = 0x2702;
const GLenum GL_LINEAR_MIPMAP_NEAREST               = 0x2701;
const GLenum GL_LINEAR_MIPMAP_LINEAR                = 0x2703;
const GLenum GL_OBJECT_LINEAR                       = 0x2401;
const GLenum GL_OBJECT_PLANE                        = 0x2501;
const GLenum GL_EYE_LINEAR                          = 0x2400;
const GLenum GL_EYE_PLANE                           = 0x2502;
const GLenum GL_SPHERE_MAP                          = 0x2402;
const GLenum GL_DECAL                               = 0x2101;
const GLenum GL_MODULATE                            = 0x2100;
const GLenum GL_NEAREST                             = 0x2600;
const GLenum GL_REPEAT                              = 0x2901;
const GLenum GL_CLAMP                               = 0x2900;
const GLenum GL_S                                   = 0x2000;
const GLenum GL_T                                   = 0x2001;
const GLenum GL_R                                   = 0x2002;
const GLenum GL_Q                                   = 0x2003;
const GLenum GL_TEXTURE_GEN_R                       = 0x0C62;
const GLenum GL_TEXTURE_GEN_Q                       = 0x0C63;

// Utility
const GLenum GL_VENDOR                              = 0x1F00;
const GLenum GL_RENDERER                            = 0x1F01;
const GLenum GL_VERSION                             = 0x1F02;
const GLenum GL_EXTENSIONS                          = 0x1F03;

// Errors
const GLenum GL_NO_ERROR                            = 0x0;
const GLenum GL_INVALID_VALUE                       = 0x0501;
const GLenum GL_INVALID_ENUM                        = 0x0500;
const GLenum GL_INVALID_OPERATION                   = 0x0502;
const GLenum GL_STACK_OVERFLOW                      = 0x0503;
const GLenum GL_STACK_UNDERFLOW                     = 0x0504;
const GLenum GL_OUT_OF_MEMORY                       = 0x0505;

// glPush/PopAttrib bits
const GLuint GL_CURRENT_BIT                         = 0x00000001;
const GLuint GL_POINT_BIT                           = 0x00000002;
const GLuint GL_LINE_BIT                            = 0x00000004;
const GLuint GL_POLYGON_BIT                         = 0x00000008;
const GLuint GL_POLYGON_STIPPLE_BIT                 = 0x00000010;
const GLuint GL_PIXEL_MODE_BIT                      = 0x00000020;
const GLuint GL_LIGHTING_BIT                        = 0x00000040;
const GLuint GL_FOG_BIT                             = 0x00000080;
const GLuint GL_DEPTH_BUFFER_BIT                    = 0x00000100;
const GLuint GL_ACCUM_BUFFER_BIT                    = 0x00000200;
const GLuint GL_STENCIL_BUFFER_BIT                  = 0x00000400;
const GLuint GL_VIEWPORT_BIT                        = 0x00000800;
const GLuint GL_TRANSFORM_BIT                       = 0x00001000;
const GLuint GL_ENABLE_BIT                          = 0x00002000;
const GLuint GL_COLOR_BUFFER_BIT                    = 0x00004000;
const GLuint GL_HINT_BIT                            = 0x00008000;
const GLuint GL_EVAL_BIT                            = 0x00010000;
const GLuint GL_LIST_BIT                            = 0x00020000;
const GLuint GL_TEXTURE_BIT                         = 0x00040000;
const GLuint GL_SCISSOR_BIT                         = 0x00080000;
const GLuint GL_ALL_ATTRIB_BITS                     = 0x000FFFFF;

// gl 1.1
const GLenum GL_PROXY_TEXTURE_1D                    = 0x8063;
const GLenum GL_PROXY_TEXTURE_2D                    = 0x8064;
const GLenum GL_TEXTURE_PRIORITY                    = 0x8066;
const GLenum GL_TEXTURE_RESIDENT                    = 0x8067;
const GLenum GL_TEXTURE_BINDING_1D                  = 0x8068;
const GLenum GL_TEXTURE_BINDING_2D                  = 0x8069;
const GLenum GL_TEXTURE_INTERNAL_FORMAT             = 0x1003;
const GLenum GL_ALPHA4                              = 0x803B;
const GLenum GL_ALPHA8                              = 0x803C;
const GLenum GL_ALPHA12                             = 0x803D;
const GLenum GL_ALPHA16                             = 0x803E;
const GLenum GL_LUMINANCE4                          = 0x803F;
const GLenum GL_LUMINANCE8                          = 0x8040;
const GLenum GL_LUMINANCE12                         = 0x8041;
const GLenum GL_LUMINANCE16                         = 0x8042;
const GLenum GL_LUMINANCE4_ALPHA4                   = 0x8043;
const GLenum GL_LUMINANCE6_ALPHA2                   = 0x8044;
const GLenum GL_LUMINANCE8_ALPHA8                   = 0x8045;
const GLenum GL_LUMINANCE12_ALPHA4                  = 0x8046;
const GLenum GL_LUMINANCE12_ALPHA12                 = 0x8047;
const GLenum GL_LUMINANCE16_ALPHA16                 = 0x8048;
const GLenum GL_INTENSITY                           = 0x8049;
const GLenum GL_INTENSITY4                          = 0x804A;
const GLenum GL_INTENSITY8                          = 0x804B;
const GLenum GL_INTENSITY12                         = 0x804C;
const GLenum GL_INTENSITY16                         = 0x804D;
const GLenum GL_R3_G3_B2                            = 0x2A10;
const GLenum GL_RGB4                                = 0x804F;
const GLenum GL_RGB5                                = 0x8050;
const GLenum GL_RGB8                                = 0x8051;
const GLenum GL_RGB10                               = 0x8052;
const GLenum GL_RGB12                               = 0x8053;
const GLenum GL_RGB16                               = 0x8054;
const GLenum GL_RGBA2                               = 0x8055;
const GLenum GL_RGBA4                               = 0x8056;
const GLenum GL_RGB5_A1                             = 0x8057;
const GLenum GL_RGBA8                               = 0x8058;
const GLenum GL_RGB10_A2                            = 0x8059;
const GLenum GL_RGBA12                              = 0x805A;
const GLenum GL_RGBA16                              = 0x805B;
const GLuint GL_CLIENT_PIXEL_STORE_BIT              = 0x00000001;
const GLuint GL_CLIENT_VERTEX_ARRAY_BIT             = 0x00000002;
const GLuint GL_ALL_CLIENT_ATTRIB_BITS              = 0xFFFFFFFF;
const GLuint GL_CLIENT_ALL_ATTRIB_BITS              = 0xFFFFFFFF;