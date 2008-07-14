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
module derelict.sdl.keyboard;

private import derelict.sdl.types;
private import derelict.sdl.keysym;

//==============================================================================
// TYPES
//==============================================================================
struct SDL_keysym
{
    Uint8 scancode;
    SDLKey sym;
    SDLMod mod;
    Uint16 unicode;
}

enum : uint { SDL_ALL_HOTKEYS = 0xFFFFFFFF }

enum
{
    SDL_DEFAULT_REPEAT_DELAY      = 500,
    SDL_DEFAULT_REPEAT_INTERVAL   = 30,
}

//==============================================================================
// FUNCTIONS
//==============================================================================
extern(C):

typedef int function(int) pfSDL_EnableUNICODE;
typedef int function(int,int) pfSDL_EnableKeyRepeat;
typedef void function(int*,int*) pfSDL_GetKeyRepeat;
typedef Uint8* function(int*) pfSDL_GetKeyState;
typedef SDLMod function() pfSDL_GetModState;
typedef void function(SDLMod) pfSDL_SetModState;
typedef char* function(SDLKey key) pfSDL_GetKeyName;
pfSDL_EnableUNICODE         SDL_EnableUNICODE;
pfSDL_EnableKeyRepeat       SDL_EnableKeyRepeat;
pfSDL_GetKeyRepeat          SDL_GetKeyRepeat;
pfSDL_GetKeyState           SDL_GetKeyState;
pfSDL_GetModState           SDL_GetModState;
pfSDL_SetModState           SDL_SetModState;
pfSDL_GetKeyName            SDL_GetKeyName;