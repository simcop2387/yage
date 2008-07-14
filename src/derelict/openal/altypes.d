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
 * * Neither the names 'Derelict', 'DerelictAL', nor the names of its contributors
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
module derelict.openal.altypes;

alias byte ALboolean;
alias byte ALbyte;
alias ubyte ALubyte;
alias short ALshort;
alias ushort ALushort;
alias uint ALuint;
alias int ALint;
alias float ALfloat;
alias double ALdouble;

version(linux)
{
    alias int ALsizei;
}
else
{
    alias uint ALsizei;
}

alias void ALvoid;
alias int ALenum;
alias uint ALbitfield;
alias ALfloat ALclampf;
alias ALdouble ALclampd;

enum : ALboolean
{
	AL_FALSE               = 0,
    AL_TRUE                = 1,
}

enum : ALenum
{
    AL_INVALD              = -1,
    AL_NONE                = 0,    

    AL_SOURCE_TYPE         = 0x200,
    AL_SOURCE_ABSOLUTE     = 0x201,
    AL_SOURCE_RELATIVE     = 0x202,

    AL_CONE_INNER_ANGLE    = 0x1001,
    AL_CONE_OUTER_ANGLE    = 0x1002,

    AL_PITCH               = 0x1003,
    AL_POSITION            = 0x1004,
    AL_DIRECTION           = 0x1005,
    AL_VELOCITY            = 0x1006,
    AL_LOOPING             = 0x1007,
    AL_BUFFER              = 0x1009,
    AL_GAIN                = 0x100A,
    AL_MIN_GAIN            = 0x100D,
    AL_MAX_GAIN            = 0x100E,
    AL_ORIENTATION         = 0x100F,

    AL_CHANNEL_MASK        = 0x3000,

    AL_SOURCE_STATE        = 0x1010,
    AL_INITIAL             = 0x1011,
    AL_PLAYING             = 0x1012,
    AL_PAUSED              = 0x1013,
    AL_STOPPED             = 0x1014,

    AL_BUFFERS_QUEUED      = 0x1015,
    AL_BUFFERS_PROCESSED   = 0x1016,

    AL_FORMAT_MONO8        = 0x1100,
    AL_FORMAT_MONO16       = 0x1101,
    AL_FORMAT_STEREO8      = 0x1102,
    AL_FORMAT_STEREO16     = 0x1103,

    AL_REFERENCE_DISTANCE  = 0x1020,
    AL_ROLLOFF_FACTOR      = 0x1021,
    AL_CONE_OUTER_GAIN     = 0x1022,
    AL_MAX_DISTANCE        = 0x1023,


    AL_FREQUENCEY          = 0x2001,
    AL_BITS                = 0x2002,
    AL_CHANNELS            = 0x2003,
    AL_SIZE                = 0x2004,
    AL_DATA                = 0x2005,

    AL_UNUSED              = 0x2010,
    AL_PENDING             = 0x2011,
    AL_PROCESSID           = 0x2012,

    AL_NO_ERROR            = AL_FALSE,

    AL_INVALID_NAME        = 0xA001,
    AL_ILLEGAL_ENUM        = 0xA002,
    AL_INVALID_ENUM        = 0xA002,
    AL_INVALID_VALUE       = 0xA003,
    AL_ILLEGAL_COMMAND     = 0xA004,
    AL_INVALID_OPERATION   = 0xA004,
    AL_OUT_OF_MEMORY       = 0xA005,

    AL_VENDOR              = 0xB001,
    AL_VERSION             = 0xB002,
    AL_RENDERER            = 0xB003,
    AL_EXTENSIONS          = 0xB004,

    AL_DOPPLER_FACTOR      = 0xC001,

    AL_DISTANCE_MODEL              = 0xD000,
    AL_INVERSE_DISTANCE            = 0xD001,
    AL_INVERSE_DISTANCE_CLAMPED    = 0xD002,
}

version(linux)
{
    enum : ALenum
    {
        AL_DISTANCE_SCALE   = 0xC002,
        AL_STREAMING        = 0x1008,
        AL_BYTE_LOKI        = 0x100C,
    }
}



