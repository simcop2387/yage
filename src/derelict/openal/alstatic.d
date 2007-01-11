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
module derelict.openal.alstatic;

version(DerelictAL_Static)
{

    private
    {
        import derelict.openal.altypes;
        import derelict.openal.alctypes;
		import derelict.util.loader;
    }

	GenericStaticLoader DerelictAL;
	GenericStaticLoader DerelictALU;

	static this() {
		DerelictAL.setup();
		DerelictALU.setup();
	}

/*    version(Windows)
        extern(Windows):
    else
*/        extern(C):

        void alEnable(ALenum);
        void alDisable(ALenum);
        ALboolean alIsEnabled(ALenum);
        void alGetBooleanv(ALenum, ALboolean*);
        void alGetIntegerv(ALenum, ALint*);
        void alGetFloatv(ALenum, ALfloat*);
        void alGetDoublev(ALenum, ALdouble*);
        char* alGetString(ALenum);
        ALboolean alGetBoolean(ALenum);
        ALint alGetInteger(ALenum);
        ALfloat alGetFloat(ALenum);
        ALdouble alGetDouble(ALenum);
        ALenum alGetError();

        ALboolean alIsExtensionPresent(char*);
        ALboolean alGetProcAddress(char*);
        ALenum alGetEnumValue(char*);

        void alListenerf(ALenum, ALfloat);
        void alListeneri(ALenum, ALint);
        void alListener3f(ALenum, ALfloat, ALfloat, ALfloat);
        void alListenerfv(ALenum, ALfloat*);
        void alGetListeneri(ALenum, ALint*);
        void alGetListenerf(ALenum, ALfloat*);
        void alGetListenerfv(ALenum, ALfloat*);
        void alGetListener3f(ALenum, ALfloat*, ALfloat*, ALfloat*);

        void alGenSources(ALsizei, ALuint*);
        void alDeleteSource(ALsizei, ALuint*);
        void alIsSource(ALuint);
        void alSourcei(ALuint, ALenum, ALint);
        void alSourcef(ALuint, ALenum, ALfloat);
        void alSource3f(ALuint, ALenum, ALfloat, ALfloat, ALfloat);
        void alSourcefv(ALuint, ALenum, ALfloat*);
        void alGetSourcei(ALuint, ALenum, ALint*);
        void alGetSourcef(ALuint, ALenum, ALfloat*);
        void alGetSourcefv(ALuint, ALenum, ALfloat*);
        void alGetSource3f(ALuint, ALenum, ALfloat*, ALfloat*, ALfloat*);

        void alSourcePlayv(ALsizei, ALuint*);
        void alSourceStopv(ALsizei, ALuint*);
        void alSourceRewindv(ALsizei, ALuint*);
        void alSourcePausev(ALsizei, ALuint*);
        void alSourcePlay(ALuint);
        void alSourcePause(ALuint);
        void alSourceRewind(ALuint);
        void alSourceStop(ALuint);

        void alGenBuffers(ALsizei, ALuint*);
        void alDeleteBuffers(ALsizei, ALuint*);
        ALboolean alIsBuffer(ALuint);
        void alBufferData(ALuint, ALenum, ALvoid*, ALsizei, ALsizei);
        void alGetBufferi(ALuint, ALenum, ALint*);
        void alGetBufferf(ALuint, ALenum, ALfloat*);

        void alSourceQueueBuffers(ALuint, ALsizei, ALuint*);
        void alSourceUnqueueBuffers(ALuint, ALsizei, ALuint*);

        void alDopplerFactor(ALfloat);
        void alDopplerVelocity(ALfloat);
        void alDistanceModel(ALenum);
        
        // ALC
        char* alcGetString(ALCdevice*, ALCenum);
        ALCvoid alcGetIntegerv(ALCdevice*, ALCenum, ALCsizei, ALCint*);
        
        ALCdevice* alcOpenDevice(char*);
        ALCvoid alcCloseDevice(ALCdevice*);
        
        ALCcontext* alcCreateContext(ALCdevice*);
        ALCboolean alcMakeContextCurrent(ALCcontext*);
        ALCvoid alcProcessContext(ALCcontext*);
        ALCcontext* alcGetCurrentContext();
        ALCdevice* alcGetContextsDevice(ALCcontext*);
        ALCvoid alcSuspendContext(ALCcontext*);
        ALCvoid alcDestroyContext(ALCcontext*);
        
        ALCenum alcGetError(ALCdevice*);
        
        ALCboolean alcIsExtensionPresent(ALCdevice*, char*);
        ALCvoid* alcGetProcAddress(ALCdevice*, char*);
        ALCenum* alcGetEnumValue(ALCdevice*, char*);

        version(linux)
        {
            extern(C) void alGetBufferiv(ALuint, ALenum, ALint*);
            extern(C) void alGetBufferfv(ALuint, ALenum, ALfloat*);
        }

        version(Windows)
        {
          //  extern(Windows):
          	extern(C):
          	
                ALint aluF2L(ALfloat);
                ALshort aluF2S(ALfloat);
                ALvoid aluCrossproduct(ALfloat*, ALfloat*, ALfloat*);
                ALfloat aluDotproduct(ALfloat*, ALfloat*);
                ALvoid aluNormalize(ALfloat*);
                ALvoid aluMatrixVector(ALfloat*, ALfloat[3][3]);
                ALvoid aluCalculateSourceParameters(ALuint, ALuint, ALfloat*, ALfloat*, ALfloat*);
                ALvoid aluMixData(ALvoid*, ALvoid*, ALsizei, ALenum);
                ALvoid aluSetReverb(ALvoid*, ALuint);
                ALvoid aluReverb(ALvoid*, ALfloat[][2], ALsizei);
        }
} // version(DerelictAL_Static)
