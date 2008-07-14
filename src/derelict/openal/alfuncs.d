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
module derelict.openal.alfuncs;


private
{
    import derelict.openal.altypes;
    import derelict.openal.alctypes;
    import derelict.util.loader;
}

private void loadAL(SharedLib lib)
{
    // al functions
    bindFunc(alEnable)("alEnable", lib);
    bindFunc(alDisable)("alDisable", lib);
    bindFunc(alIsEnabled)("alIsEnabled", lib);
//    bindFunc(alHint)("alHint", lib);
    bindFunc(alGetBooleanv)("alGetBooleanv", lib);
    bindFunc(alGetIntegerv)("alGetIntegerv", lib);
    bindFunc(alGetFloatv)("alGetFloatv", lib);
    bindFunc(alGetDoublev)("alGetDoublev", lib);
    bindFunc(alGetString)("alGetString", lib);
    bindFunc(alGetInteger)("alGetInteger", lib);
    bindFunc(alGetFloat)("alGetFloat", lib);
    bindFunc(alGetDouble)("alGetDouble", lib);
    bindFunc(alGetError)("alGetError", lib);
    bindFunc(alIsExtensionPresent)("alIsExtensionPresent", lib);
    bindFunc(alGetProcAddress)("alGetProcAddress", lib);
    bindFunc(alGetEnumValue)("alGetEnumValue", lib);
    bindFunc(alListenerf)("alListenerf", lib);
    bindFunc(alListeneri)("alListeneri", lib);
    bindFunc(alListener3f)("alListener3f", lib);
    bindFunc(alListenerfv)("alListenerfv", lib);
    bindFunc(alGetListeneri)("alGetListeneri", lib);
    bindFunc(alGetListenerf)("alGetListenerf", lib);
//    bindFunc(alGetListeneriv)("alGetListeneriv", lib);
    bindFunc(alGetListenerfv)("alGetListenerfv", lib);
    bindFunc(alGetListener3f)("alGetListener3f", lib);
    bindFunc(alGenSources)("alGenSources", lib);
    bindFunc(alDeleteSources)("alDeleteSources", lib);
    bindFunc(alIsSource)("alIsSource", lib);
    bindFunc(alSourcei)("alSourcei", lib);
    bindFunc(alSourcef)("alSourcef", lib);
    bindFunc(alSource3f)("alSource3f", lib);
    bindFunc(alSourcefv)("alSourcefv", lib);
    bindFunc(alGetSourcei)("alGetSourcei", lib);
    bindFunc(alGetSourcef)("alGetSourcef", lib);
//    bindFunc(alGetSourceiv)("alGetSourceiv", lib);
    bindFunc(alGetSourcefv)("alGetSourcefv", lib);
    bindFunc(alGetSource3f)("alGetSource3f", lib);
    bindFunc(alSourcePlayv)("alSourcePlayv", lib);
    bindFunc(alSourceStopv)("alSourceStopv", lib);
    bindFunc(alSourceRewindv)("alSourceRewindv", lib);
    bindFunc(alSourcePausev)("alSourcePausev", lib);
    bindFunc(alSourcePlay)("alSourcePlay", lib);
    bindFunc(alSourcePause)("alSourcePause", lib);
    bindFunc(alSourceRewind)("alSourceRewind", lib);
    bindFunc(alSourceStop)("alSourceStop", lib);
    bindFunc(alGenBuffers)("alGenBuffers", lib);
    bindFunc(alDeleteBuffers)("alDeleteBuffers", lib);
    bindFunc(alIsBuffer)("alIsBuffer", lib);
    bindFunc(alBufferData)("alBufferData", lib);
    bindFunc(alGetBufferi)("alGetBufferi", lib);
    bindFunc(alGetBufferf)("alGetBufferf", lib);
    version(linux)
    {
        bindFunc(alGetBufferfv)("alGetBufferfv", lib);
        bindFunc(alGetBufferiv)("alGetBufferiv", lib);
    }
    bindFunc(alSourceQueueBuffers)("alSourceQueueBuffers", lib);
    bindFunc(alSourceUnqueueBuffers)("alSourceUnqueueBuffers", lib);
    bindFunc(alDopplerFactor)("alDopplerFactor", lib);
    bindFunc(alDopplerVelocity)("alDopplerVelocity", lib);
    bindFunc(alDistanceModel)("alDistanceModel", lib);

    bindFunc(alcGetString)("alcGetString", lib);
    bindFunc(alcGetIntegerv)("alcGetIntegerv", lib);
    bindFunc(alcOpenDevice)("alcOpenDevice", lib);
    bindFunc(alcCloseDevice)("alcCloseDevice", lib);
    bindFunc(alcCreateContext)("alcCreateContext", lib);
    bindFunc(alcMakeContextCurrent)("alcMakeContextCurrent", lib);
    bindFunc(alcProcessContext)("alcProcessContext", lib);
    bindFunc(alcGetCurrentContext)("alcGetCurrentContext", lib);
    bindFunc(alcGetContextsDevice)("alcGetContextsDevice", lib);
    bindFunc(alcSuspendContext)("alcSuspendContext", lib);
    bindFunc(alcDestroyContext)("alcDestroyContext", lib);
    bindFunc(alcGetError)("alcGetError", lib);
    bindFunc(alcIsExtensionPresent)("alcIsExtensionPresent", lib);
    bindFunc(alcGetProcAddress)("alcGetProcAddress", lib);
    bindFunc(alcGetEnumValue)("alcGetEnumValue", lib);
}


public void loadALU(SharedLib lib)
{
    version(Windows)
    {
        bindFunc(aluF2L)("aluF2L", lib);
        bindFunc(aluF2S)("aluF2S", lib);
        bindFunc(aluCrossproduct)("aluCrossproduct", lib);
        bindFunc(aluDotproduct)("aluDotproduct", lib);
        bindFunc(aluNormalize)("aluNormalize", lib);
        bindFunc(aluMatrixVector)("aluMatrixVector", lib);
        bindFunc(aluCalculateSourceParameters)("aluCalculateSourceParameters", lib);
        bindFunc(aluMixData)("aluMixData", lib);
        bindFunc(aluSetReverb)("aluSetReverb", lib);
        bindFunc(aluReverb)("aluReverb", lib);
    }
}


GenericLoader           DerelictAL;
GenericDependentLoader  DerelictALU;
static this() {
    DerelictAL.setup(
        "OpenAL32.dll",
        "libal.so, libAL.so, libopenal.so, libopenal.so.0",
        "",
        &loadAL
    );
    DerelictALU.setup(&DerelictAL, &loadALU);
}


extern(C):

typedef void function(ALenum) pfalEnable;
typedef void function(ALenum) pfalDisable;
typedef ALboolean function(ALenum) pfalIsEnabled;
//typedef void function(ALenum, ALenum) pfalHint;
typedef void function(ALenum, ALboolean*) pfalGetBooleanv;
typedef void function(ALenum, ALint*) pfalGetIntegerv;
typedef void function(ALenum, ALfloat*) pfalGetFloatv;
typedef void function(ALenum, ALdouble*) pfalGetDoublev;
typedef char* function(ALenum) pfalGetString;
typedef ALboolean function(ALenum) pfalGetBoolean;
typedef ALint function(ALenum) pfalGetInteger;
typedef ALfloat function(ALenum) pfalGetFloat;
typedef ALdouble function(ALenum) pfalGetDouble;
typedef ALenum function() pfalGetError;
pfalEnable                          alEnable;
pfalDisable                         alDisable;
pfalIsEnabled                       alIsEnabled;
//pfalHint                            alHint;
pfalGetBooleanv                     alGetBooleanv;
pfalGetIntegerv                     alGetIntegerv;
pfalGetFloatv                       alGetFloatv;
pfalGetDoublev                      alGetDoublev;
pfalGetString                       alGetString;
pfalGetInteger                      alGetInteger;
pfalGetFloat                        alGetFloat;
pfalGetDouble                       alGetDouble;
pfalGetError                        alGetError;

typedef ALboolean function(char*) pfalIsExtensionPresent;
typedef ALboolean function(char*) pfalGetProcAddress;
typedef ALenum function(char*) pfalGetEnumValue;
pfalIsExtensionPresent          alIsExtensionPresent;
pfalGetProcAddress                      alGetProcAddress;
pfalGetEnumValue                        alGetEnumValue;

typedef void function(ALenum, ALfloat) pfalListenerf;
typedef void function(ALenum, ALint) pfalListeneri;
typedef void function(ALenum, ALfloat, ALfloat, ALfloat) pfalListener3f;
typedef void function(ALenum, ALfloat*) pfalListenerfv;
typedef void function(ALenum, ALint*) pfalGetListeneri;
typedef void function(ALenum, ALfloat*) pfalGetListenerf;
//typedef void function(ALenum, ALint*) pfalGetListeneriv;
typedef void function(ALenum, ALfloat*) pfalGetListenerfv;
typedef void function(ALenum, ALfloat*, ALfloat*, ALfloat*) pfalGetListener3f;
pfalListenerf                           alListenerf;
pfalListeneri                           alListeneri;
pfalListener3f                          alListener3f;
pfalListenerfv                          alListenerfv;
pfalGetListeneri                        alGetListeneri;
pfalGetListenerf                        alGetListenerf;
//pfalGetListeneriv                       alGetListeneriv;
pfalGetListenerfv                       alGetListenerfv;
pfalGetListener3f                       alGetListener3f;

typedef void function(ALsizei, ALuint*) pfalGenSources;
typedef void function(ALsizei, ALuint*) pfalDeleteSources;
typedef void function(ALuint) pfalIsSource;
typedef void function(ALuint, ALenum, ALint) pfalSourcei;
typedef void function(ALuint, ALenum, ALfloat) pfalSourcef;
typedef void function(ALuint, ALenum, ALfloat, ALfloat, ALfloat) pfalSource3f;
typedef void function(ALuint, ALenum, ALfloat*) pfalSourcefv;
typedef void function(ALuint, ALenum, ALint*) pfalGetSourcei;
typedef void function(ALuint, ALenum, ALfloat*) pfalGetSourcef;
//typedef void function(ALuint, ALenum, ALint*) pfalGetSourceiv;
typedef void function(ALuint, ALenum, ALfloat*) pfalGetSourcefv;
typedef void function(ALuint, ALenum, ALfloat*, ALfloat*, ALfloat*) pfalGetSource3f;
pfalGenSources                          alGenSources;
pfalDeleteSources                       alDeleteSources;
pfalIsSource                            alIsSource;
pfalSourcei                             alSourcei;
pfalSourcef                             alSourcef;
pfalSource3f                            alSource3f;
pfalSourcefv                            alSourcefv;
pfalGetSourcei                          alGetSourcei;
pfalGetSourcef                          alGetSourcef;
//pfalGetSourceiv                         alGetSourceiv;
pfalGetSourcefv                         alGetSourcefv;
pfalGetSource3f                         alGetSource3f;

typedef void function(ALsizei, ALuint*) pfalSourcePlayv;
typedef void function(ALsizei, ALuint*) pfalSourceStopv;
typedef void function(ALsizei, ALuint*) pfalSourceRewindv;
typedef void function(ALsizei, ALuint*) pfalSourcePausev;
typedef void function(ALuint) pfalSourcePlay;
typedef void function(ALuint) pfalSourcePause;
typedef void function(ALuint) pfalSourceRewind;
typedef void function(ALuint) pfalSourceStop;
pfalSourcePlayv                         alSourcePlayv;
pfalSourceStopv                         alSourceStopv;
pfalSourceRewindv                       alSourceRewindv;
pfalSourcePausev                        alSourcePausev;
pfalSourcePlay                          alSourcePlay;
pfalSourcePause                         alSourcePause;
pfalSourceRewind                        alSourceRewind;
pfalSourceStop                          alSourceStop;

typedef void function(ALsizei, ALuint*) pfalGenBuffers;
typedef void function(ALsizei, ALuint*) pfalDeleteBuffers;
typedef ALboolean function(ALuint) pfalIsBuffer;
typedef void function(ALuint, ALenum, ALvoid*, ALsizei, ALsizei) pfalBufferData;
typedef void function(ALuint, ALenum, ALint*) pfalGetBufferi;
typedef void function(ALuint, ALenum, ALfloat*) pfalGetBufferf;
pfalGenBuffers                          alGenBuffers;
pfalDeleteBuffers                       alDeleteBuffers;
pfalIsBuffer                            alIsBuffer;
pfalBufferData                          alBufferData;
pfalGetBufferi                          alGetBufferi;
pfalGetBufferf                          alGetBufferf;

typedef void function(ALuint, ALsizei, ALuint*) pfalSourceQueueBuffers;
typedef void function(ALuint, ALsizei, ALuint*) pfalSourceUnqueueBuffers;
pfalSourceQueueBuffers                  alSourceQueueBuffers;
pfalSourceUnqueueBuffers                alSourceUnqueueBuffers;

typedef void function(ALfloat) pfalDopplerFactor;
typedef void function(ALfloat) pfalDopplerVelocity;
typedef void function(ALenum) pfalDistanceModel;
pfalDopplerFactor                       alDopplerFactor;
pfalDopplerVelocity                     alDopplerVelocity;
pfalDistanceModel                       alDistanceModel;

version(linux)
{
    extern(C):
        typedef void function(ALuint, ALenum, ALint*) pfalGetBufferiv;
        typedef void function(ALuint, ALenum, ALfloat*) pfalGetBufferfv;
        pfalGetBufferiv                         alGetBufferiv;
        pfalGetBufferfv                         alGetBufferfv;
}

// ALC
typedef char* function(ALCdevice*, ALCenum) pfalcGetString;
typedef ALCvoid function(ALCdevice*, ALCenum, ALCsizei, ALCint*) pfalcGetIntegerv;
pfalcGetString                          alcGetString;
pfalcGetIntegerv                        alcGetIntegerv;

typedef ALCdevice* function(char*) pfalcOpenDevice;
typedef ALCboolean function(ALCdevice*) pfalcCloseDevice;
pfalcOpenDevice                         alcOpenDevice;
pfalcCloseDevice                        alcCloseDevice;

typedef ALCcontext* function(ALCdevice*, ALCint*) pfalcCreateContext;
typedef ALCboolean function(ALCcontext*) pfalcMakeContextCurrent;
typedef ALCvoid function(ALCcontext*) pfalcProcessContext;
typedef ALCcontext* function() pfalcGetCurrentContext;
typedef ALCdevice* function(ALCcontext*) pfalcGetContextsDevice;
typedef ALCvoid function(ALCcontext*) pfalcSuspendContext;
typedef ALCvoid function(ALCcontext*) pfalcDestroyContext;
pfalcCreateContext                      alcCreateContext;
pfalcMakeContextCurrent                 alcMakeContextCurrent;
pfalcProcessContext                     alcProcessContext;
pfalcGetCurrentContext                  alcGetCurrentContext;
pfalcGetContextsDevice                  alcGetContextsDevice;
pfalcSuspendContext                     alcSuspendContext;
pfalcDestroyContext                     alcDestroyContext;

typedef ALCenum function(ALCdevice*) pfalcGetError;
pfalcGetError                           alcGetError;

typedef ALCboolean function(ALCdevice*, char*) pfalcIsExtensionPresent;
typedef ALCvoid* function(ALCdevice*, char*) pfalcGetProcAddress;
typedef ALCenum function(ALCdevice*, char*) pfalcGetEnumValue;
pfalcIsExtensionPresent                 alcIsExtensionPresent;
pfalcGetProcAddress                 alcGetProcAddress;
pfalcGetEnumValue                       alcGetEnumValue;

// ALU
version(Windows)
{
//      extern(Windows):
    extern(C):

        typedef ALint function(ALfloat) pfaluF2L;
        typedef ALshort function(ALfloat) pfaluF2S;
        typedef ALvoid function(ALfloat*, ALfloat*, ALfloat*) pfaluCrossproduct;
        typedef ALfloat function(ALfloat*, ALfloat*) pfaluDotproduct;
        typedef ALvoid function(ALfloat*) pfaluNormalize;
        typedef ALvoid function(ALfloat*, ALfloat[3][3]) pfaluMatrixVector;
        typedef ALvoid function(ALuint, ALuint, ALfloat*, ALfloat*, ALfloat*) pfaluCalculateSourceParameters;
        typedef ALvoid function(ALvoid*, ALvoid*, ALsizei, ALenum) pfaluMixData;
        typedef ALvoid function(ALvoid*, ALuint) pfaluSetReverb;
        typedef ALvoid function(ALvoid*, ALfloat[][2], ALsizei) pfaluReverb;
        pfaluF2L                    aluF2L;
        pfaluF2S                    aluF2S;
        pfaluCrossproduct           aluCrossproduct;
        pfaluDotproduct             aluDotproduct;
        pfaluNormalize              aluNormalize;
        pfaluMatrixVector           aluMatrixVector;
        pfaluCalculateSourceParameters aluCalculateSourceParameters;
        pfaluMixData                aluMixData;
        pfaluSetReverb              aluSetReverb;
        pfaluReverb                 aluReverb;

} // version(Windows)


