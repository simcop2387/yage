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
module derelict.sdl.cdrom;

private import derelict.sdl.types;

//==============================================================================
// TYPES
//==============================================================================
enum : Sint32 { SDL_MAX_TRACKS = 99 }

enum : Uint8
{
    SDL_AUDIO_TRACK     = 0x00,
    SDL_DATA_TRACK      = 0x04,
}

alias int CDstatus;
enum
{
    CD_TRAYEMPTY,
    CD_STOPPED,
    CD_PLAYING,
    CD_PAUSED,
    CD_ERROR = -1
}

struct SDL_CDtrack
{
    Uint8 id;
    Uint8 type;
    Uint16 unused;
    Uint32 length;
    Uint32 offset;
}

struct SDL_CD
{
    int id;
    CDstatus status;
    int numtracks;
    int cur_track;
    int cur_frame;
    SDL_CDtrack track[SDL_MAX_TRACKS + 1];
}

enum { CD_FPS = 75 }

//==============================================================================
// MACROS
//==============================================================================
int CD_INDRIVE(int status)
{
    return (cast(int)status > 0);
}

void FRAMES_TO_MSF(int f, out int M, out int S, out int F)
{
    int value = f;
    F = value % CD_FPS;
    value /= CD_FPS;
    S = value % 60;
    value /= 60;
    M = value;
}

int MSF_TO_FRAMES(int M, int S, int F)
{
    return (M * 60 * CD_FPS + S * CD_FPS + F);
}

//==============================================================================
// FUNCTIONS
//==============================================================================
extern(C):

typedef int function() pfSDL_CDNumDrives;
typedef char* function(int) pfSDL_CDName;
typedef SDL_CD* function(int) pfSDL_CDOpen;
typedef CDstatus function(SDL_CD*) pfSDL_CDStatus;
typedef int function(SDL_CD*,int,int,int,int) pfSDL_CDPlayTracks;
typedef int function(SDL_CD*,int,int) pfSDL_CDPlay;
typedef int function(SDL_CD*) pfSDL_CDPause;
typedef int function(SDL_CD*) pfSDL_CDResume;
typedef int function(SDL_CD*) pfSDL_CDStop;
typedef int function(SDL_CD*) pfSDL_CDEject;
typedef int function(SDL_CD*) pfSDL_CDClose;
pfSDL_CDNumDrives           SDL_CDNumDrives;
pfSDL_CDName                SDL_CDName;
pfSDL_CDOpen                SDL_CDOpen;
pfSDL_CDStatus              SDL_CDStatus;
pfSDL_CDPlayTracks          SDL_CDPlayTracks;
pfSDL_CDPlay                SDL_CDPlay;
pfSDL_CDPause               SDL_CDPause;
pfSDL_CDResume              SDL_CDResume;
pfSDL_CDStop                SDL_CDStop;
pfSDL_CDEject               SDL_CDEject;
pfSDL_CDClose               SDL_CDClose;
