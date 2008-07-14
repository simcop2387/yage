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
module derelict.sdl.timer;

private import derelict.sdl.types;

//==============================================================================
// TYPES
//==============================================================================
enum : Uint32
{
    SDL_TIMESLICE          = 10,
    SDL_RESOLUTION         = 10,
}

extern(C)
{
	typedef Uint32 function(Uint32) SDL_TimerCallback;
	typedef Uint32 function(Uint32,void*) SDL_NewTimerCallback;
}

alias void *SDL_TimerID;

//==============================================================================
// FUNCTIONS
//==============================================================================
extern(C):

typedef Uint32 function() pfSDL_GetTicks;
typedef void function(Uint32) pfSDL_Delay;
typedef int function(Uint32,SDL_TimerCallback) pfSDL_SetTimer;
typedef SDL_TimerID function(Uint32,SDL_NewTimerCallback,void*) pfSDL_AddTimer;
typedef SDL_bool function(SDL_TimerID) pfSDL_RemoveTimer;
pfSDL_GetTicks          SDL_GetTicks;
pfSDL_Delay             SDL_Delay;
pfSDL_SetTimer          SDL_SetTimer;
pfSDL_AddTimer          SDL_AddTimer;
pfSDL_RemoveTimer       SDL_RemoveTimer;

