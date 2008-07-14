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
module derelict.sdl.joystick;

private import derelict.sdl.types;

//==============================================================================
// TYPES
//==============================================================================
struct SDL_Joystick {}

enum : Uint8
{
    SDL_HAT_CENTERED            = 0x00,
    SDL_HAT_UP                  = 0x01,
    SDL_HAT_RIGHT               = 0x02,
    SDL_HAT_DOWN                = 0x04,
    SDL_HAT_LEFT                = 0x08,
    SDL_HAT_RIGHTUP             = SDL_HAT_RIGHT | SDL_HAT_UP,
    SDL_HAT_RIGHTDOWN           = SDL_HAT_RIGHT | SDL_HAT_DOWN,
    SDL_HAT_LEFTUP              = SDL_HAT_LEFT | SDL_HAT_UP,
    SDL_HAT_LEFTDOWN            = SDL_HAT_LEFT | SDL_HAT_DOWN,
}

//==============================================================================
// FUNCTIONS
//==============================================================================
extern(C):

typedef int function() pfSDL_NumJoysticks;
typedef char* function(int) pfSDL_JoystickName;
typedef SDL_Joystick* function(int) pfSDL_JoystickOpen;
typedef int function(int) pfSDL_JoystickOpened;
typedef int function(SDL_Joystick*) pfSDL_JoystickIndex;
typedef int function(SDL_Joystick*) pfSDL_JoystickNumAxes;
typedef int function(SDL_Joystick*) pfSDL_JoystickNumBalls;
typedef int function(SDL_Joystick*) pfSDL_JoystickNumHats;
typedef int function(SDL_Joystick*) pfSDL_JoystickNumButtons;
typedef void function() pfSDL_JoystickUpdate;
typedef int function(int) pfSDL_JoystickEventState;
typedef Sint16 function(SDL_Joystick*,int) pfSDL_JoystickGetAxis;
typedef Uint8 function(SDL_Joystick*,int) pfSDL_JoystickGetHat;
typedef int function(SDL_Joystick*,int,int*,int*) pfSDL_JoystickGetBall;
typedef Uint8 function(SDL_Joystick*,int) pfSDL_JoystickGetButton;
typedef void function(SDL_Joystick*) pfSDL_JoystickClose;
pfSDL_NumJoysticks              SDL_NumJoysticks;
pfSDL_JoystickName              SDL_JoystickName;
pfSDL_JoystickOpen              SDL_JoystickOpen;
pfSDL_JoystickOpened            SDL_JoystickOpened;
pfSDL_JoystickIndex             SDL_JoystickIndex;
pfSDL_JoystickNumAxes           SDL_JoystickNumAxes;
pfSDL_JoystickNumBalls          SDL_JoystickNumBalls;
pfSDL_JoystickNumHats           SDL_JoystickNumHats;
pfSDL_JoystickNumButtons        SDL_JoystickNumButtons;
pfSDL_JoystickUpdate            SDL_JoystickUpdate;
pfSDL_JoystickEventState        SDL_JoystickEventState;
pfSDL_JoystickGetAxis           SDL_JoystickGetAxis;
pfSDL_JoystickGetHat            SDL_JoystickGetHat;
pfSDL_JoystickGetBall           SDL_JoystickGetBall;
pfSDL_JoystickGetButton         SDL_JoystickGetButton;
pfSDL_JoystickClose             SDL_JoystickClose;