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
	protected static int count=0;
	protected static ALCdevice* device = null;
	protected static ALCcontext* context = null; // OpenAL allows for only one context
	
	protected static ALContext current_context;	// a refernce to the instance of this class that is the current virutal context
	
	protected static Object openal_mutex = null;
	
	protected Closure[] queue;
	protected Object queue_mutex;
	
	// context-specific openal settings
	float doppler_velocity = 1;
	
	static this()
	{	openal_mutex = new Object();		
	}
	
	/**
	 * Create an OpenAL and context if they don't exist. */
	this()
	{	super();
		queue_mutex = new Object();
		
		synchronized(openal_mutex)
		{	int error = 0;
		
			if (count==0)
			{	
				device = alcOpenDevice(null); // it seems that this can be called multiple times and still return the same device.			
				count++;
				error = alGetError();
				//if (error != 0)
				//	throw new YageException("There was an error creating the OpenAL device. OpenAL Error Code %d.", error);
				if (!device)
					throw new YageException("There was an error creating the OpenAL device. OpenAL returned a null device.");
				Log.write("Using OpenAL Device '%s'.", .toString(alcGetString(device, ALC_DEVICE_SPECIFIER)));
			
				context = alcCreateContext(device, null); // this returns a null context, but why?
				// context = Device.getOpenALContext(); // for now
				//error = alGetError();
				//if (error !=0 )
				//	throw new YageException("There was an error creating the OpenAL context. OpenAL Error Code %d.", error);
				if (!context)
					throw new YageException("There was an error creating the OpenAL context. OpenAL returned a null context.");
			}			
			alcMakeContextCurrent(context);
			current_context = this;
			
			error = alGetError();
			if (error != 0)
				throw new YageException("There was an error activating the OpenAL context. OpenAL Error Code %d", error);
		}
	}
	
	/**
	 * Call finalize on destruction. */
	~this()
	{	finalize();		
	}
	
	/**
	 * Destroy the OpenAL context and also the OpenAL device if this is the last context. */
	void finalize()
	{	if (context)
		{	count--;
			synchronized(openal_mutex)
			{	if (count==0)
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
	 * Add an operation to perform from within this thread. */
	void addToQueue(Closure c)
	{	 synchronized(queue_mutex) queue ~= c;
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
	 * Process the queue of closures that use OpenAl functions. */
	void processQueue(double unused=0)
	in {
		assert(isContextThread()); // called from the helper thread.
	}
	body
	{	synchronized(queue_mutex)
		{	if (queue.length)
			{	synchronized(openal_mutex)
				{	makeCurrent();
					foreach(i, func; queue)
						func.call();
					queue.length = 0;
				}
			}
		}
	}
	
	/**
	 * Make this virtual OpenAL context the current one. */
	void makeCurrent()
	in
	{	assert(context);		
	}
	body
	{	synchronized(openal_mutex)
		{	if (this != current_context)
			{	
				// TODO: apply any openal settings, such as speed of sound, related to this virtual context.
			
				current_context = this;
		}	}
	}
	
	static Object getOpenALMutex()
	{	return openal_mutex;
	}
}