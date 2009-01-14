/**
 * 
 */
module yage.system.alcontext;

import std.stdio;
import std.string;
import std.thread;
import derelict.openal.al;
import yage.core.closure;
import yage.core.exceptions;
import yage.core.repeater;
import yage.system.device;
import yage.system.log;
import yage.core.misc;
import std.traits;


char[][int] ALErrorLookup;
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
}


/**
 * This is a virtual OpenAL context that provides the following features
 * - All instances wraps around a single real OpenAL Context, since OpenAL typically fails on the creation of more than one context.
 * - An OpenAL device and (real) OpenAL context are created on the first instantiation, and destroyed when the last instance is destroyed.
 * - Using a queue of closures, it ensures that all calls to OpenAL from multiple threads occur in a synchronized fashion.
 *   - This queue is processed via the processQueue() method.   
 * - It allows sound decoding and playback to be processed in its own thread. 
 *   - This class extends from Repeater, which handles creating a new thread that can be set to call processQueue() at a set interval. */
class ALContext : Repeater
{	
	protected static ALCdevice* device = null;
	protected static ALCcontext* context = null; // OpenAL allows for only one context
	
	protected static int count=0;
	protected static ALContext current_context;	// a refernce to the instance of this class that is the current virutal context

	// context-specific openal settings
	float doppler_velocity = 1;
	
	/**
	 * Create an OpenAL and context if they don't exist. */
	this()
	{	super();		
		
		synchronized(getMutex())
		{	int error = 0;
		
			// If we don't have a context
			if (count==0)
			{	
				// Get the device, null for the default device
				device = alcOpenDevice(null);
				
				// check for errors
				error = alcGetError(device);
				if (error != AL_NO_ERROR)
					throw new OpenALException("There was an error creating the OpenAL device. OpenAL Error Code %d.", error);
				if (!device)
					throw new OpenALException("There was an error creating the OpenAL device. OpenAL returned a null device.");
				Log.write("Using OpenAL Device '%s'.", .toString(alcGetString(device, ALC_DEVICE_SPECIFIER)));
			
				// Get a context
				context = alcCreateContext(device, null);
				
				// Check for errors
				error = alcGetError(device);
				if (error != AL_NO_ERROR)
					throw new OpenALException("There was an error creating the OpenAL context. OpenAL Error Code %d.", error);
				if (!context)
					throw new OpenALException("There was an error creating the OpenAL context. OpenAL returned a null context.");
				
				count++;
			}			
			alcMakeContextCurrent(context);
			current_context = this;
			
			error = alcGetError(device);
			if (error != AL_NO_ERROR)
				throw new OpenALException("There was an error activating the OpenAL context. OpenAL Error Code %d", error);
		}
	}
	
	/**
	 * Call finalize on destruction. */
	~this()
	{	finalize();		
	}
	
	/**
	 * Destroy the OpenAL context and also the OpenAL device if this is the last context. 
	 * TODO: What if the garbae collector calls this after a new context is created? */
	void finalize()
	{	if (context)
		{	synchronized(getMutex())
			{	count--;
				if (count==0)
				{	alcMakeContextCurrent(null);
					alcDestroyContext(context);			
					alcCloseDevice(device);
					context = device = null;
				}
				current_context = null;
			}
			super.finalize();
		}
	}
	
	/**
	 * Get/set the speed of sound for this virtual context.
	 * A doppler velocity of 1 is 343m/s, the default speed of sound in Earth's atmosphere. */
	float getDopplerVeloity()
	{	return doppler_velocity;
	}
	void setDopplerVelocity(float velocity) /// ditto
	{	doppler_velocity = velocity;		
	}
	
	/**
	 * Is the thread that called this function the same as the thread responsible for this context? */
	bool isContextThread()
	{	return !!(thread == Thread.getThis());
	}
	
	/**
	 * Make this virtual OpenAL context the current one. */
	void makeCurrent()
	in
	{	assert(context);		
	}
	body
	{	synchronized(getMutex())
			if (this != current_context)
			{	current_context = this;			
				alDopplerVelocity(doppler_velocity);
			}
	}
	
	///
	static Object getMutex()
	{	return ALContext.classinfo; // sychronize on static object.
	}

	/**
	 * Create a wrapper around any OpenAL function.
	 * ReturnType execute(FunctionName)(Arguments ...);
	 * The wrapper checks for errors. */
	static R execute(alias T, R=ReturnType!(baseTypedef!(typeof(T))))(ParameterTypeTuple!(baseTypedef!(typeof(T))) args)
	in {
		assert(context);
	}
	body
	{	int error = alGetError();
		static if (is (R==void))
			T(args);
		else
			R result = T(args);
		error = alGetError();
		if (error != AL_NO_ERROR)
			throw new OpenALException("OpenAL %s error %s", T.stringof, ALErrorLookup[error]);

		static if (!is (R==void))
			return result;
	}
	
	/**
	 * Add wrappers for each OpenAL function (unfinished). */
	alias execute!(alSourceUnqueueBuffers) sourceUnqueueBuffers;
	alias execute!(alSourceQueueBuffers) sourceQueueBuffers;	
	alias execute!(alSourcef) sourcef;
	alias execute!(alSourcefv) sourcefv;
	alias execute!(alSourcePlay) sourcePlay;
	alias execute!(alSourcePause) sourcePause;
	alias execute!(alSourceStop) sourceStop;
	alias execute!(alGenSources) genSources;
	alias execute!(alDeleteSources) deleteSources;
	alias execute!(alGetSourcei) getSourcei;
	alias execute!(alIsBuffer) isBuffer;
	alias execute!(alGenBuffers) genBuffers;
	alias execute!(alDeleteBuffers) deleteBuffers;
	alias execute!(alBufferData) bufferData;
}

	