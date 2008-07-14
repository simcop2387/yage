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
module derelict.sdl.rwops;

private
{
    import derelict.sdl.types;

    version(Tango)
    {
        import tango.stdc.stdio;
    }
    else
    {
        import std.c.stdio;
    }
}

//==============================================================================
// TYPES
//==============================================================================
enum
{
    RW_SEEK_SET       = 0,
    RW_SEEK_CUR       = 1,
    RW_SEEK_END       = 2,
}

struct SDL_RWops
{
	extern(C)
	{
	    int (*seek)(SDL_RWops *context, int offset, int whence);
	    int (*read)(SDL_RWops *context, void *ptr, int size, int maxnum);
	    int (*write)(SDL_RWops *context, void *ptr, int size, int num);
	    int (*close)(SDL_RWops *context);
    }
    
    Uint32 type;
    union Hidden
    {
        version(Windows)
        {
            struct Win32io
            {
                int append;
                void *h;
            }
            Win32io win32io;
        }

        struct Stdio
        {
            int autoclose;
            FILE *fp;
        }
        Stdio stdio;

        struct Mem
        {
            Uint8 *base;
            Uint8 *here;
            Uint8 *stop;
        }
        Mem mem;

        struct Unknown
        {
            void *data1;
        }
        Unknown unknown;
    }
    Hidden hidden;
}

//==============================================================================
// MACROS
//==============================================================================
int SDL_RWseek(SDL_RWops *context, int offset, int whence)
{
    return context.seek(context, offset, whence);
}

int SDL_RWtell(SDL_RWops *context)
{
    return context.seek(context, 0, RW_SEEK_CUR);
}

int SDL_RWread(SDL_RWops *context, void *ptr, int size, int maxnum)
{
    return context.read(context, ptr, size, maxnum);
}

int SDL_RWwrite(SDL_RWops *context, void *ptr, int size, int num)
{
    return context.write(context, ptr, size, num);
}

int SDL_RWclose(SDL_RWops *context)
{
    return context.close(context);
}

//==============================================================================
// FUNCTIONS
//==============================================================================
extern(C):

typedef SDL_RWops* function(char*,char*) pfSDL_RWFromFile;
typedef SDL_RWops* function(FILE*,int) pfSDL_RWFromFP;
typedef SDL_RWops* function(void*,int) pfSDL_RWFromMem;
typedef SDL_RWops* function(void*,int) pfSDL_RWFromConstMem;
typedef SDL_RWops* function() pfSDL_AllocRW;
typedef void function(SDL_RWops*) pfSDL_FreeRW;
pfSDL_RWFromFile            SDL_RWFromFile;
pfSDL_RWFromFP              SDL_RWFromFP;
pfSDL_RWFromMem             SDL_RWFromMem;
pfSDL_RWFromConstMem        SDL_RWFromConstMem;
pfSDL_AllocRW               SDL_AllocRW;
pfSDL_FreeRW                SDL_FreeRW;

typedef Uint16 function(SDL_RWops*) pfSDL_ReadLE16;
typedef Uint16 function(SDL_RWops*) pfSDL_ReadBE16;
typedef Uint32 function(SDL_RWops*) pfSDL_ReadLE32;
typedef Uint32 function(SDL_RWops*) pfSDL_ReadBE32;
typedef Uint64 function(SDL_RWops*) pfSDL_ReadLE64;
typedef Uint64 function(SDL_RWops*) pfSDL_ReadBE64;
typedef Uint16 function(SDL_RWops*,Uint16) pfSDL_WriteLE16;
typedef Uint16 function(SDL_RWops*,Uint16) pfSDL_WriteBE16;
typedef Uint32 function(SDL_RWops*,Uint32) pfSDL_WriteLE32;
typedef Uint32 function(SDL_RWops*,Uint32) pfSDL_WriteBE32;
typedef Uint64 function(SDL_RWops*,Uint64) pfSDL_WriteLE64;
typedef Uint64 function(SDL_RWops*,Uint64) pfSDL_WriteBE64;
pfSDL_ReadLE16          SDL_ReadLE16;
pfSDL_ReadBE16          SDL_ReadBE16;
pfSDL_ReadLE32          SDL_ReadLE32;
pfSDL_ReadBE32          SDL_ReadBE32;
pfSDL_ReadLE64          SDL_ReadLE64;
pfSDL_ReadBE64          SDL_ReadBE64;
pfSDL_WriteLE16         SDL_WriteLE16;
pfSDL_WriteBE16         SDL_WriteBE16;
pfSDL_WriteLE32         SDL_WriteLE32;
pfSDL_WriteBE32         SDL_WriteBE32;
pfSDL_WriteLE64         SDL_WriteLE64;
pfSDL_WriteBE64         SDL_WriteBE64;