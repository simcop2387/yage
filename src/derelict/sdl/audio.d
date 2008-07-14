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
module derelict.sdl.audio;

private import derelict.sdl.types;
private import derelict.sdl.rwops;

//==============================================================================
// TYPES
//==============================================================================
struct SDL_AudioSpec
{
    int freq;
    Uint16 format;
    Uint8 channels;
    Uint8 silence;
    Uint16 samples;
    Uint16 padding;
    Uint32 size;
    extern(C) void (*callback)(void *userdata, Uint8 *stream, int len);
    void *userdata;
}

enum : Uint16
{
    AUDIO_U8           = 0x0008,
    AUDIO_S8           = 0x8008,
    AUDIO_U16LSB       = 0x0010,
    AUDIO_S16LSB       = 0x8010,
    AUDIO_U16MSB       = 0x1010,
    AUDIO_S16MSB       = 0x9010,
    AUDIO_U16          = AUDIO_U16LSB,
    AUDIO_S16          = AUDIO_S16LSB,
}

version(LittleEndian)
{
    enum : Uint16
    {
        AUDIO_U16SYS   = AUDIO_U16LSB,
        AUDIO_S16SYS   = AUDIO_S16LSB,
    }
}
else
{
    enum : Uint16
    {
        AUDIO_U16SYS   = AUDIO_U16MSB,
        AUDIO_S16SYS   = AUDIO_S16MSB,
    }
}

struct SDL_AudioCVT
{
    int needed;
    Uint16 src_format;
    Uint16 dst_format;
    double rate_incr;
    Uint8 *buf;
    int len;
    int len_cvt;
    int len_mult;
    double len_ratio;
    void (*filters[10])(SDL_AudioCVT *cvt, Uint16 format);
    int filter_index;
}

alias int SDL_audiostatus;
enum
{
    SDL_AUDIO_STOPPED       = 0,
    SDL_AUDIO_PLAYING,
    SDL_AUDIO_PAUSED
}

enum { SDL_MIX_MAXVOLUME = 128 }

//==============================================================================
// MACROS
//==============================================================================
SDL_AudioSpec* SDL_LoadWAV(char *file, SDL_AudioSpec *spec, Uint8 **buf, Uint32 *len)
{
    return SDL_LoadWAV_RW(SDL_RWFromFile(file, "rb"), 1, spec, buf, len);
}

//==============================================================================
// FUNCTIONS
//==============================================================================
extern(C):

typedef int function(char*) pfSDL_AudioInit;
typedef void function() pfSDL_AudioQuit;
typedef char* function(char*,int) pfSDL_AudioDriverName;
typedef int function(SDL_AudioSpec*,SDL_AudioSpec*) pfSDL_OpenAudio;
typedef SDL_audiostatus function() pfSDL_GetAudioStatus;
typedef void function(int) pfSDL_PauseAudio;
typedef SDL_AudioSpec* function(SDL_RWops*,int,SDL_AudioSpec*,Uint8**,Uint32*) pfSDL_LoadWAV_RW;
typedef void function(Uint8*) pfSDL_FreeWAV;
typedef int function(SDL_AudioCVT*,Uint16,Uint8,int,Uint16,Uint8,int) pfSDL_BuildAudioCVT;
typedef int function(SDL_AudioCVT*) pfSDL_ConvertAudio;
typedef void function(Uint8*,Uint8*,Uint32,int) pfSDL_MixAudio;
typedef void function() pfSDL_LockAudio;
typedef void function() pfSDL_UnlockAudio;
typedef void function() pfSDL_CloseAudio;
pfSDL_AudioInit             SDL_AudioInit;
pfSDL_AudioQuit             SDL_AudioQuit;
pfSDL_AudioDriverName       SDL_AudioDriverName;
pfSDL_OpenAudio             SDL_OpenAudio;
pfSDL_GetAudioStatus        SDL_GetAudioStatus;
pfSDL_PauseAudio            SDL_PauseAudio;
pfSDL_LoadWAV_RW            SDL_LoadWAV_RW;
pfSDL_FreeWAV               SDL_FreeWAV;
pfSDL_BuildAudioCVT         SDL_BuildAudioCVT;
pfSDL_ConvertAudio          SDL_ConvertAudio;
pfSDL_MixAudio              SDL_MixAudio;
pfSDL_LockAudio             SDL_LockAudio;
pfSDL_UnlockAudio           SDL_UnlockAudio;
pfSDL_CloseAudio            SDL_CloseAudio;