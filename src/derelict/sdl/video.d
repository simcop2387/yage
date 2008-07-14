/*
 * Copyright (c) 2004-2008 Derelict Developers
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
 * * Neither the names 'Derelict', 'DerelictSDL', nor the names of its contributors
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
module derelict.sdl.video;

private import derelict.sdl.types;
private import derelict.sdl.mutex;
private import derelict.sdl.rwops;

//==============================================================================
// TYPES
//==============================================================================
enum : Uint8
{
    SDL_ALPHA_OPAQUE            = 255,
    SDL_ALPHA_TRANSPARENT       = 0,
}

struct SDL_Rect
{
    Sint16 x, y;
    Uint16 w, h;
}

struct SDL_Color
{
    Uint8 r;
    Uint8 g;
    Uint8 b;
    Uint8 unused;
}
alias SDL_Color SDL_Colour;

struct SDL_Palette
{
    int ncolors;
    SDL_Color *colors;
}

struct SDL_PixelFormat
{
    SDL_Palette *palette;
    Uint8 BitsPerPixel;
    Uint8 BytesPerPixel;
    Uint8 Rloss;
    Uint8 Gloss;
    Uint8 Bloss;
    Uint8 Aloss;
    Uint8 Rshift;
    Uint8 Gshift;
    Uint8 Bshift;
    Uint8 Ashift;
    Uint32 Rmask;
    Uint32 Gmask;
    Uint32 Bmask;
    Uint32 Amask;
    Uint32 colorkey;
    Uint8 alpha;
}

struct SDL_Surface
{
    Uint32 flags;
    SDL_PixelFormat *format;
    int w, h;
    Uint16 pitch;
    void *pixels;
    int offset;
    void *hwdata;
    SDL_Rect clip_rect;
    Uint32 unused1;
    Uint32 locked;
    void *map;
    uint format_version;
    int refcount;
}

enum : Uint32
{
    SDL_SWSURFACE                  = 0x00000000,
    SDL_HWSURFACE                  = 0x00000001,
    SDL_ASYNCBLIT                  = 0x00000004,
    SDL_ANYFORMAT                  = 0x10000000,
    SDL_HWPALETTE                  = 0x20000000,
    SDL_DOUBLEBUF                  = 0x40000000,
    SDL_FULLSCREEN                 = 0x80000000,
    SDL_OPENGL                     = 0x00000002,
    SDL_OPENGLBLIT                 = 0x0000000A,
    SDL_RESIZABLE                  = 0x00000010,
    SDL_NOFRAME                    = 0x00000020,
    SDL_HWACCEL                    = 0x00000100,
    SDL_SRCCOLORKEY                = 0x00001000,
    SDL_RLEACCELOK                 = 0x00002000,
    SDL_RLEACCEL                   = 0x00004000,
    SDL_SRCALPHA                   = 0x00010000,
    SDL_PREALLOC                   = 0x01000000,
}

struct SDL_VideoInfo
{
    Uint32 flags;
    Uint32 video_mem;
    SDL_PixelFormat *vfmt;
    int current_w;
    int current_h;
}

enum : Uint32
{
    SDL_YV12_OVERLAY               = 0x32315659,
    SDL_IYUV_OVERLAY               = 0x56555949,
    SDL_YUY2_OVERLAY               = 0x32595559,
    SDL_UYVY_OVERLAY               = 0x59565955,
    SDL_YUYU_OVERLAY               = 0x55595659,
}

struct SDL_Overlay
{
    Uint32 format;
    int w, h;
    int planes;
    Uint16 *pitches;
    Uint8 **pixels;
    void *hwfuncs;
    void *hwdata;
    Uint32 flags;
}

alias int SDL_GLattr;
enum
{
    SDL_GL_RED_SIZE,
    SDL_GL_GREEN_SIZE,
    SDL_GL_BLUE_SIZE,
    SDL_GL_ALPHA_SIZE,
    SDL_GL_BUFFER_SIZE,
    SDL_GL_DOUBLEBUFFER,
    SDL_GL_DEPTH_SIZE,
    SDL_GL_STENCIL_SIZE,
    SDL_GL_ACCUM_RED_SIZE,
    SDL_GL_ACCUM_GREEN_SIZE,
    SDL_GL_ACCUM_BLUE_SIZE,
    SDL_GL_ACCUM_ALPHA_SIZE,
    SDL_GL_STEREO,
    SDL_GL_MULTISAMPLEBUFFERS,
    SDL_GL_MULTISAMPLESAMPLES,
    SDL_GL_ACCELERATED_VISUAL,
    SDL_GL_SWAP_CONTROL
}

enum : Uint8
{
    SDL_LOGPAL          = 0x01,
    SDL_PHYSPAL         = 0x02,
}

alias int SDL_GrabMode;
enum
{
    SDL_GRAB_QUERY = -1,
    SDL_GRAB_OFF = 0,
    SDL_GRAB_ON = 1,
    SDL_GRAB_FULLSCREEN
}

//==============================================================================
// MACROS
//==============================================================================
bool SDL_MUSTLOCK(SDL_Surface* surface)
{
    return cast(bool)(surface.offset ||
        ((surface.flags & (SDL_HWSURFACE|SDL_ASYNCBLIT|SDL_RLEACCEL)) != 0));
}

SDL_Surface* SDL_LoadBMP(char *file)
{
    return SDL_LoadBMP_RW(SDL_RWFromFile(file, "rb"), 1);
}

int SDL_SaveBMP(SDL_Surface *surfave, char *file)
{
    return SDL_SaveBMP_RW(surfave, SDL_RWFromFile(file,"wb"), 1);
}

//==============================================================================
// FUNCTIONS
//==============================================================================
extern(C):

typedef int function(char*,Uint32) pfSDL_VideoInit;
typedef void function() pfSDL_VideoQuit;
typedef char* function(char*,int) pfSDL_VideoDriverName;
typedef SDL_Surface* function() pfSDL_GetVideoSurface;
typedef SDL_VideoInfo* function() pfSDL_GetVideoInfo;
typedef int function(int,int,int,Uint32) pfSDL_VideoModeOK;
typedef SDL_Rect** function(SDL_PixelFormat*,Uint32) pfSDL_ListModes;
typedef SDL_Surface* function(int,int,int,Uint32) pfSDL_SetVideoMode;
typedef void function(SDL_Surface*,int,SDL_Rect*) pfSDL_UpdateRects;
typedef void function(SDL_Surface*,Sint32,Sint32,Uint32,Uint32) pfSDL_UpdateRect;
typedef int function(SDL_Surface*) pfSDL_Flip;
typedef int function(float,float,float) pfSDL_SetGamma;
typedef int function(Uint16*,Uint16*,Uint16*) pfSDL_SetGammaRamp;
typedef int function(Uint16*,Uint16*,Uint16*) pfSDL_GetGammaRamp;
typedef int function(SDL_Surface*,SDL_Color*,int,int) pfSDL_SetColors;
typedef int function(SDL_Surface*,int,SDL_Color*,int,int) pfSDL_SetPalette;
typedef Uint32 function(SDL_PixelFormat*,Uint8,Uint8,Uint8) pfSDL_MapRGB;
typedef Uint32 function(SDL_PixelFormat*,Uint8,Uint8,Uint8,Uint8) pfSDL_MapRGBA;
typedef void function(Uint32,SDL_PixelFormat*,Uint8*,Uint8*,Uint8*) pfSDL_GetRGB;
typedef void function(Uint32,SDL_PixelFormat*,Uint8*,Uint8*,Uint8*,Uint8*) pfSDL_GetRGBA;
typedef SDL_Surface* function(Uint32,int,int,int,Uint32,Uint32,Uint32,Uint32) pfSDL_CreateRGBSurface;
typedef SDL_Surface* function(void*,int,int,int,int,Uint32,Uint32,Uint32,Uint32) pfSDL_CreateRGBSurfaceFrom;
typedef void function(SDL_Surface*) pfSDL_FreeSurface;
typedef int function(SDL_Surface*) pfSDL_LockSurface;
typedef void function(SDL_Surface*) pfSDL_UnlockSurface;
typedef SDL_Surface* function(SDL_RWops*,int) pfSDL_LoadBMP_RW;
typedef int function(SDL_Surface*,SDL_RWops*,int) pfSDL_SaveBMP_RW;
typedef int function(SDL_Surface*,Uint32,Uint32) pfSDL_SetColorKey;
typedef int function(SDL_Surface*,Uint32,Uint8) pfSDL_SetAlpha;
typedef SDL_bool function(SDL_Surface*,SDL_Rect*) pfSDL_SetClipRect;
typedef void function(SDL_Surface*,SDL_Rect*) pfSDL_GetClipRect;
typedef SDL_Surface* function(SDL_Surface*,SDL_PixelFormat*,Uint32) pfSDL_ConvertSurface;
typedef int function(SDL_Surface*,SDL_Rect*,SDL_Surface*,SDL_Rect*) pfSDL_UpperBlit;
typedef int function(SDL_Surface*,SDL_Rect*,SDL_Surface*,SDL_Rect*) pfSDL_LowerBlit;
typedef int function(SDL_Surface*,SDL_Rect*,Uint32) pfSDL_FillRect;
typedef SDL_Surface* function(SDL_Surface*) pfSDL_DisplayFormat;
typedef SDL_Surface* function(SDL_Surface*) pfSDL_DisplayFormatAlpha;
typedef SDL_Overlay* function(int,int,Uint32,SDL_Surface*) pfSDL_CreateYUVOverlay;
typedef int function(SDL_Overlay*) pfSDL_LockYUVOverlay;
typedef void function(SDL_Overlay*) pfSDL_UnlockYUVOverlay;
typedef int function(SDL_Overlay*,SDL_Rect*) pfSDL_DisplayYUVOverlay;
typedef void function(SDL_Overlay*) pfSDL_FreeYUVOverlay;
typedef int function(char*) pfSDL_GL_LoadLibrary;
typedef void* function(char*) pfSDL_GL_GetProcAddress;
typedef int function(SDL_GLattr,int) pfSDL_GL_SetAttribute;
typedef int function(SDL_GLattr,int*) pfSDL_GL_GetAttribute;
typedef void function() pfSDL_GL_SwapBuffers;
typedef void function(int,SDL_Rect*) pfSDL_GL_UpdateRects;
typedef void function() pfSDL_GL_Lock;
typedef void function() pfSDL_GL_Unlock;
typedef void function(char*,char*) pfSDL_WM_SetCaption;
typedef void function(char**,char**) pfSDL_WM_GetCaption;
typedef void function(SDL_Surface*,Uint8*) pfSDL_WM_SetIcon;
typedef int function() pfSDL_WM_IconifyWindow;
typedef int function(SDL_Surface*) pfSDL_WM_ToggleFullScreen;
typedef SDL_GrabMode function(SDL_GrabMode) pfSDL_WM_GrabInput;
//typedef int function(SDL_Surface*,SDL_Rect*,SDL_Surface*,SDL_Rect*) pfSDL_SoftStretch;
pfSDL_VideoInit             SDL_VideoInit;
pfSDL_VideoQuit             SDL_VideoQuit;
pfSDL_VideoDriverName       SDL_VideoDriverName;
pfSDL_GetVideoSurface       SDL_GetVideoSurface;
pfSDL_GetVideoInfo          SDL_GetVideoInfo;
pfSDL_VideoModeOK           SDL_VideoModeOK;
pfSDL_ListModes             SDL_ListModes;
pfSDL_SetVideoMode          SDL_SetVideoMode;
pfSDL_UpdateRects           SDL_UpdateRects;
pfSDL_UpdateRect            SDL_UpdateRect;
pfSDL_Flip                  SDL_Flip;
pfSDL_SetGamma              SDL_SetGamma;
pfSDL_SetGammaRamp          SDL_SetGammaRamp;
pfSDL_GetGammaRamp          SDL_GetGammaRamp;
pfSDL_SetColors             SDL_SetColors;
pfSDL_SetPalette            SDL_SetPalette;
pfSDL_MapRGB                SDL_MapRGB;
pfSDL_MapRGBA               SDL_MapRGBA;
pfSDL_GetRGB                SDL_GetRGB;
pfSDL_GetRGBA               SDL_GetRGBA;
pfSDL_CreateRGBSurface      SDL_AllocSurface;
pfSDL_CreateRGBSurface      SDL_CreateRGBSurface;
pfSDL_CreateRGBSurfaceFrom  SDL_CreateRGBSurfaceFrom;
pfSDL_FreeSurface           SDL_FreeSurface;
pfSDL_LockSurface           SDL_LockSurface;
pfSDL_UnlockSurface         SDL_UnlockSurface;
pfSDL_LoadBMP_RW            SDL_LoadBMP_RW;
pfSDL_SaveBMP_RW            SDL_SaveBMP_RW;
pfSDL_SetColorKey           SDL_SetColorKey;
pfSDL_SetAlpha              SDL_SetAlpha;
pfSDL_SetClipRect           SDL_SetClipRect;
pfSDL_GetClipRect           SDL_GetClipRect;
pfSDL_ConvertSurface        SDL_ConvertSurface;
pfSDL_UpperBlit             SDL_BlitSurface;
pfSDL_UpperBlit             SDL_UpperBlit;
pfSDL_LowerBlit             SDL_LowerBlit;
pfSDL_FillRect              SDL_FillRect;
pfSDL_DisplayFormat         SDL_DisplayFormat;
pfSDL_DisplayFormatAlpha    SDL_DisplayFormatAlpha;
pfSDL_CreateYUVOverlay      SDL_CreateYUVOverlay;
pfSDL_LockYUVOverlay        SDL_LockYUVOverlay;
pfSDL_UnlockYUVOverlay      SDL_UnlockYUVOverlay;
pfSDL_DisplayYUVOverlay     SDL_DisplayYUVOverlay;
pfSDL_FreeYUVOverlay        SDL_FreeYUVOverlay;
pfSDL_GL_LoadLibrary        SDL_GL_LoadLibrary;
pfSDL_GL_GetProcAddress     SDL_GL_GetProcAddress;
pfSDL_GL_SetAttribute       SDL_GL_SetAttribute;
pfSDL_GL_GetAttribute       SDL_GL_GetAttribute;
pfSDL_GL_SwapBuffers        SDL_GL_SwapBuffers;
pfSDL_GL_UpdateRects        SDL_GL_UpdateRects;
pfSDL_GL_Lock               SDL_GL_Lock;
pfSDL_GL_Unlock             SDL_GL_Unlock;
pfSDL_WM_SetCaption         SDL_WM_SetCaption;
pfSDL_WM_GetCaption         SDL_WM_GetCaption;
pfSDL_WM_SetIcon            SDL_WM_SetIcon;
pfSDL_WM_IconifyWindow      SDL_WM_IconifyWindow;
pfSDL_WM_ToggleFullScreen   SDL_WM_ToggleFullScreen;
pfSDL_WM_GrabInput          SDL_WM_GrabInput;