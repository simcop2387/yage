/**
 * Yage Game Engine source code - yage3d.net
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */
module yage.system.sound.openal;

import derelict.openal.al;
import tango.core.Traits;
import yage.core.misc;
import yage.core.object2;
import yage.system.sound.soundsystem;

/**
 * Create a wrapper around all OpenAL functions providing the following additional features:
 * 
 * Error results from each openal call are checked.$(BR)
 * On error, an exception is thrown with the OpenAL error code translated to a meaningful string. */
class OpenAL
{
	static string[int] ALErrorLookup;
	static Object mutex;
	
	// Initialize static variables
	static this ()
	{	ALErrorLookup = [
			0xA001: "AL_INVALID_NAME"[],
			0xA002: "AL_ILLEGAL_ENUM",
			0xA002: "AL_INVALID_ENUM",
			0xA003: "AL_INVALID_VALUE",
			0xA004: "AL_ILLEGAL_COMMAND",
			0xA004: "AL_INVALID_OPERATION",
			0xA005: "AL_OUT_OF_MEMORY" 
		];
		mutex = new Object();
	}
	
	/*
	 * Create a wrapper around any OpenAL function.
	 * ReturnType execute(FunctionName)(Arguments ...);*/
	static R execute(alias T, R=ReturnTypeOf!(baseTypedef!(typeof(T))))(ParameterTupleOf!(baseTypedef!(typeof(T))) args)
	in {
		if (T.stringof[0..3] != "alc") // all non-alc functions require an active OpenAL Context
			assert(SoundContext.getContext());
	}
	body
	{	int error = alGetError(); // clear any previous errors.
		
		// Check to see if an OpenAL error was set.
		void checkError()
		{	error = alGetError();
			if (error != AL_NO_ERROR)
				throw new OpenALException("OpenAL %s error %s", T.stringof, OpenAL.ALErrorLookup[error]);
		}		
		
		// Call the function
		try {
			static if (is (R==void))
			{	T(args);
				if (T.stringof[0..3] != "alc") // TODO can be static if.
					checkError();
			}
			else
			{	R result = T(args);
				if (T.stringof[0..3] == "alc") // can't use alGetError for alc functions.
				{	if (!result)
						throw new OpenALException("OpenAL %s error. %s returned null.", T.stringof, T.stringof);
				} else
					checkError();
				return result;
			}
		} catch (OpenALException e)
		{	throw e;			
		} catch (Exception e)
		{	throw new OpenALException("OpenAL %s error. %s threw an exception with message '%s'", T.stringof, T.stringof, e);
		}
	}
	
	/**
	 * Get an OpenAL mutex to ensure that no two threads ever execute OpenAL functionality simultaneously. */
	static Object getMutex()
	{	return mutex;		
	}
	
	/**
	 * Wrappers for each OpenAL function (unfinished). */
	alias execute!(alBufferData) bufferData; /// ditto	
	alias execute!(alDeleteBuffers) deleteBuffers; /// ditto
	alias execute!(alDeleteSources) deleteSources; /// ditto
	alias execute!(alGenBuffers) genBuffers; /// ditto
	alias execute!(alGenSources) genSources; /// ditto
	alias execute!(alGetSourcef) getSourcef; /// ditto
	alias execute!(alGetSourcei) getSourcei; /// ditto
	alias execute!(alIsBuffer) isBuffer; /// ditto
	alias execute!(alListenerfv) listenerfv; /// ditto
	alias execute!(alSourcef) sourcef; /// ditto
	alias execute!(alSourcefv) sourcefv; /// ditto
	alias execute!(alSourcePlay) sourcePlay; /// ditto
	alias execute!(alSourcePause) sourcePause; /// ditto
	alias execute!(alSourceQueueBuffers) sourceQueueBuffers; /// ditto
	alias execute!(alSourceStop) sourceStop; /// ditto
	alias execute!(alSourceUnqueueBuffers) sourceUnqueueBuffers; /// ditto
	
	alias execute!(alcCloseDevice) closeDevice; /// ditto
	alias execute!(alcCreateContext) createContext; /// ditto
	alias execute!(alcDestroyContext) destroyContext; /// ditto
	alias execute!(alcGetIntegerv) getIntegerv; /// ditto
	alias execute!(alcGetString) getString; /// ditto
	alias execute!(alcMakeContextCurrent) makeContextCurrent; /// ditto
	alias execute!(alcOpenDevice) openDevice; /// ditto
}