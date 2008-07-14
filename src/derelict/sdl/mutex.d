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
module derelict.sdl.mutex;

private import derelict.sdl.types;

//==============================================================================
// TYPES
//==============================================================================
enum { SDL_MUTEX_TIMEOUT = 1 }

enum : Uint32 { SDL_MUTEX_MAXWAIT = (~(cast(Uint32)0)) }

struct SDL_mutex {}

struct SDL_sem {}

struct SDL_cond {}

//==============================================================================
// MACROS
//==============================================================================
int SDL_LockMutex(SDL_mutex *mutex)
{
    return SDL_mutexP(mutex);
}

int SDL_UnlockMutex(SDL_mutex *mutex)
{
    return SDL_mutexV(mutex);
}

//==============================================================================
// FUNCTIONS
//==============================================================================
extern(C):

typedef SDL_mutex* function() pfSDL_CreateMutex;
typedef int function(SDL_mutex*) pfSDL_mutexP;
typedef int function(SDL_mutex*) pfSDL_mutexV;
typedef void function(SDL_mutex*) pfSDL_DestroyMutex;
pfSDL_CreateMutex           SDL_CreateMutex;
pfSDL_mutexP                SDL_mutexP;
pfSDL_mutexV                SDL_mutexV;
pfSDL_DestroyMutex          SDL_DestroyMutex;

typedef SDL_sem* function(Uint32) pfSDL_CreateSemaphore;
typedef void function(SDL_sem*) pfSDL_DestroySemaphore;
typedef int function(SDL_sem*) pfSDL_SemWait;
typedef int function(SDL_sem*) pfSDL_SemTryWait;
typedef int function(SDL_sem*,Uint32) pfSDL_SemWaitTimeout;
typedef int function(SDL_sem*) pfSDL_SemPost;
typedef Uint32 function(SDL_sem*) pfSDL_SemValue;
pfSDL_CreateSemaphore       SDL_CreateSemaphore;
pfSDL_DestroySemaphore      SDL_DestroySemaphore;
pfSDL_SemWait               SDL_SemWait;
pfSDL_SemTryWait            SDL_SemTryWait;
pfSDL_SemWaitTimeout        SDL_SemWaitTimeout;
pfSDL_SemPost               SDL_SemPost;
pfSDL_SemValue              SDL_SemValue;

typedef SDL_cond* function() pfSDL_CreateCond;
typedef void function(SDL_cond*) pfSDL_DestroyCond;
typedef int function(SDL_cond*) pfSDL_CondSignal;
typedef int function(SDL_cond*) pfSDL_CondBroadcast;
typedef int function(SDL_cond*,SDL_mutex*) pfSDL_CondWait;
typedef int function(SDL_cond*,SDL_mutex*,Uint32) pfSDL_CondWaitTimeout;
pfSDL_CreateCond            SDL_CreateCond;
pfSDL_DestroyCond           SDL_DestroyCond;
pfSDL_CondSignal            SDL_CondSignal;
pfSDL_CondBroadcast         SDL_CondBroadcast;
pfSDL_CondWait              SDL_CondWait;
pfSDL_CondWaitTimeout       SDL_CondWaitTimeout;