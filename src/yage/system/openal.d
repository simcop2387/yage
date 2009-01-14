/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:	Eric Poggel
 * License:	<a href="lgpl.txt">LGPL</a>
 *
 * This module contains OpenAL wrapping classes that are used internally by the engine.
 * Ideally, few if any other modules should include derelict.openal.
 */
module yage.system.openal;

import std.stdio;
import std.string;
import std.thread;
import std.traits;

import derelict.openal.al;

import yage.core.closure;
import yage.core.exceptions;
import yage.core.interfaces;
import yage.core.math;
import yage.core.matrix;
import yage.core.misc;
import yage.core.repeater;
import yage.core.vector;
import yage.scene.camera;
import yage.scene.sound;
import yage.system.device;
import yage.system.log;
import yage.resource.sound;

// Not defined in derelict yet
const int ALC_MONO_SOURCES   = 0x1010;
const int ALC_STEREO_SOURCES = 0x1011;


/**
 * Represents an OpenAL source (an instance of a sound playing).
 * Typical hardware can only support a small number of these, so SoundNodes map and unmap to these sources as needed. 
 * This is used internally by the engine and should never need to be instantiated manually. */
class ALSource : IFinalizable
{
	package uint al_source;
	package bool in_use = false;
	
	protected Sound sound;
	protected float	pitch = 1.0;
	protected float	radius = 256;	// The radius of the Sound that plays.
	protected float	volume = 1.0;	
	protected bool	looping = false;
	protected bool	_paused  = true;// true if paused or stopped
	protected Vec3f position;
	protected Vec3f velocity;
	
	protected int	size;			// number of buffers that we use at one time, either sounds' buffers per second, 
									// or less if the sound is less than one second long.
	protected bool	enqueue = true;	// Keep enqueue'ing more buffers, false if no loop and at end of track.
	protected uint	buffer_start;	// the first buffer in the array of currently enqueue'd buffers
	protected uint	buffer_end;		// the last buffer in the array of currently enqueue'd buffers
	protected uint	to_process;		// the number of buffers to queue next time.
	
	/**
	 * Create the OpenAL Source. */
	this()
	{	OpenAL.genSources(1, &al_source);
	}
	
	/**
	 * Stop bplayback, unqueue all buffers and then delete the source itself. */
	~this()
	{	finalize();		
	}
	void finalize() /// ditto
	{	if (al_source)
		{	enqueue	= false;
			OpenAL.sourceStop(al_source);
			unqueueBuffers();		
			alDeleteSources(1, &al_source);
			sound=null;
			al_source = 0;
			in_use = false; // not really necessary
		}
	}

	/**
	 * SoundNodes act as a virtual instance of a real ALSource
	 * This function ensures the ALSource matches all of the parameters of the SoundNode. 
	 * If called multiple times from the same SoundNode, this will just update the parameters. */
	void bind(Sound sound, float pitch, float radius, float volume, bool looping, bool paused, double seconds, Vec3f position, Vec3f velocity)
	{	in_use = true;
		
		this.looping = looping;
		
		synchronized(OpenAL.getMutex())
		{
			if (this.sound != sound)
			{
				// Stop, seek 0
				enqueue	= false;
				OpenAL.sourceStop(al_source);
				unqueueBuffers();
				buffer_start = buffer_end = 0;
				
				this.sound = sound;

				// Ensure that our number of buffers isn't more than what exists in the sound file
				int len = sound.getBuffersLength();
				int sec = sound.getBuffersPerSecond();
				size = len < sec ? len : sec;

				if (paused)
					OpenAL.sourcePause(al_source);
				else
				{	OpenAL.sourcePlay(al_source);
					enqueue = true;
				}
				this._paused = paused; // avoid the same check again further down.
			}
			
			if (this.radius != radius)
			{	this.radius = radius;
				OpenAL.sourcef(al_source, AL_ROLLOFF_FACTOR, 1.0/radius);
			}
			
			if (this.volume != volume)
			{	this.volume = volume;
				OpenAL.sourcef(al_source, AL_GAIN, volume);
			}
			
			if (this._paused != paused)
			{
				if (paused)
					OpenAL.sourcePause(al_source);
				else
				{	OpenAL.sourcePlay(al_source);
					enqueue = true;
				}
				this._paused = paused;
			}
			
			double epsilon = 1.0/sound.getBuffersPerSecond(); // is this always .05?
			double _tell = tell();
			if (seconds+epsilon < _tell ||  _tell < seconds-epsilon)
			{	seek(seconds);				
			}
			
			if (this.position != position)
			{	this.position = position;
				OpenAL.sourcefv(al_source, AL_POSITION, position.ptr);
			}
			
			if (this.velocity != velocity)
			{	this.velocity = velocity;
				OpenAL.sourcefv(al_source, AL_VELOCITY, velocity.ptr);
			}
		}
	}
	
	/**
	 * Unbind this sound source from a sound node, stopping playback and resetting key state variables. */
	void unbind()
	{	enqueue	= false;
		synchronized(OpenAL.getMutex())
		{	OpenAL.sourceStop(al_source);
			unqueueBuffers();
		}
		buffer_start = buffer_end = 0;
		sound = null; // so sound can be freed if no more references.
		in_use = false;
	}
		
	/** 
	 * Seek to the position in the track.  Seek has a precision of .05 seconds.
	 * @throws YageException if the value is outside the range of the Sound. */
	void seek(double seconds)
	{	uint secs = cast(uint)(seconds*size);
		if (secs>sound.getBuffersLength())
			throw new YageException("SoundNode.seek(%d) is invalid for '%s'", seconds, sound.getSource());

		// Delete any leftover buffers
		synchronized(OpenAL.getMutex())
		{	unqueueBuffers();
			buffer_start = buffer_end = secs;
			if (_paused)
				OpenAL.sourcePause(al_source);
			else
			{	OpenAL.sourcePlay(al_source);
				enqueue = true;
			}
		}
	}

	/**
	 * Tell the position of the playback of the current sound file, in seconds. */ 
	double tell()
	{	int processed; // [below] synchronization shouldn't be needed for read-only functions... ?
		OpenAL.getSourcei(al_source, AL_BUFFERS_PROCESSED, &processed);
		return ((buffer_start+processed) % sound.getBuffersLength()) /
			cast(double)sound.getBuffersPerSecond();
	}
	
	/**
	 * Enqueue new buffers for this SoundNode to play
	 * Takes into account pausing, looping and all kinds of other things.
	 * This is normally called automatically from the SoundNode's scene's sound thread. 
	 * This will fail silently if the SoundNode has no sound or no scene. */
	void updateBuffers()
	in {
		assert(in_use);
		assert(sound);
	}
	body
	{	synchronized(OpenAL.getMutex())
		{	if (enqueue)
			{	// Count buffers processed since last time we queue'd more
				int processed;
				OpenAL.getSourcei(al_source, AL_BUFFERS_PROCESSED, &processed);
				to_process = max(processed, cast(int)(size-(buffer_end-buffer_start)));
	
				// Update the buffers for this source if more than 1/4th have been used.
				if (to_process > size/4)
				{
					// If looping and our buffer has reached the end of the track
					int blength = sound.getBuffersLength();
					if (!looping && buffer_end+to_process >= blength)
						to_process = blength - buffer_end;
	
					// Unqueue old buffers
					if (processed > 0)	// shouldn't the outer conditional always ensure this is true?
						unqueueBuffers(processed);
	
					// Enqueue as many buffers as what are available
					sound.allocBuffers(buffer_end, to_process);
					OpenAL.sourceQueueBuffers(al_source, to_process, sound.getBuffers(buffer_end, buffer_end+to_process).ptr);
	
					buffer_start+= processed;
					buffer_end	+= to_process;
				}
			}
	
			// If not playing
			// Is this block unnecessary if everything behaves as it should?
			int temp;
			OpenAL.getSourcei(al_source, AL_SOURCE_STATE, &temp);
			if (temp==AL_STOPPED || temp==AL_INITIAL)
			{	// but it should be, resume playback
				if (!_paused && enqueue)
					OpenAL.sourcePlay(al_source);
				else // we've reached the end of the track
				{	
					// stop()
					OpenAL.sourceStop(al_source);
					unqueueBuffers();
					buffer_start = buffer_end = 0;
					
					if (looping && !_paused)
					{	//play();
						OpenAL.sourcePlay(al_source);
						enqueue = true;
					}
				}
			}
	
			// This is required for tracks with their total number of buffers equal to size.
			if (enqueue)
				// If not looping and our buffer has reached the end of the track
				if (!looping && buffer_end+1 >= sound.getBuffersLength())
					enqueue = false;
		}
	}
	
	/*
	 * Params:
	 *     all = Unqueue all buffers, or just those that have been processed? */
	protected void unqueueBuffers(int number=-1)
	in
	{	assert(sound);		
	}
	body 
	{	if (number == -1)
			number = buffer_end - buffer_start;		
		synchronized(OpenAL.getMutex())
		{	OpenAL.sourceUnqueueBuffers(al_source, number, sound.getBuffers(buffer_start, buffer_start+number).ptr);
			sound.freeBuffers(buffer_start, number-1);
		}	
	}
}

public class ALListener
{
	
}

/**
 * This singleton provides the following features:
 * - Instantiates an OpenAL device and context upon construction.
 * - Stores a short array of ALSource wrappers that can be wrapped around with an infinite number of virtual sources.
 * - Controls a sound thread that handles buffering audio to all active ALSources.
 */
class OpenALContext : IFinalizable
{	
	protected const int MAX_SOURCES = 8;
	protected ALSource[] sources;
	
	protected ALCdevice* device = null;
	protected ALCcontext* context = null;	
	
	protected Repeater sound_thread = null;
	
	/**
	 * Constructor.
	 * This function is called automatically by the Singleton template.
	 * To get an instance, use OpenALContext.getInstance(). */
	private this()
	{	
		// Get a device
		device = OpenAL.openDevice(null);		
		Log.write("Using OpenAL Device '%s'.", .toString(OpenAL.getString(device, ALC_DEVICE_SPECIFIER)));
	
		// Get a context
		context = OpenAL.createContext(device, null);
		OpenAL.makeContextCurrent(context);
	
		// Query how many sources are available.
		// Note that we only query the number of mono sources.
		int max_sources;
		OpenAL.getIntegerv(device, ALC_MONO_SOURCES, 1, &max_sources);
		if (max_sources > MAX_SOURCES)
			max_sources = MAX_SOURCES;
		if (max_sources<1)
			throw new OpenALException("OpenAL reports %d sound sources available. "
				" Please close any other applications which may be using sound resources.", max_sources);
		
		// Create as many soures as we can, up to a limit
		for (int i=0; i<max_sources; i++)
		{	try {
				auto source = new ALSource(); // trigger any exceptions before array length increases.
				sources.length = sources.length+1;
				sources[length-1] = source;
			} catch (OpenALException e)
			{	break;				
			}
		}
		
		// Start a thread to perform sound updates.
		//sound_thread = new Repeater();
		//sound_thread.setFrequency(30);
		//sound_thread.setFunction(&updateSounds);
		//sound_thread.play();
	}
	mixin Singleton!(typeof(this)); /// ditto
	
	
	~this()
	{	finalize();
	}
	
	/**
	 * Delete the dedvice and context,
	 * delete all sources, and set the current context to null. */
	void finalize()
	{	if (context)
		{	synchronized(OpenAL.getMutex())
			{	foreach (source; sources)
					if (source) // in case of the unpredictible order of the gc.
						source.finalize();
				sources = null;
			
				alcMakeContextCurrent(null);
				alcDestroyContext(context);			
				alcCloseDevice(device);
				context = device = null;
			}
		}
	}
	
	/**
	 * Get the OpenAL Context. */
	ALCcontext* getContext()
	{	return context;		
	}
	
	/**
	 * Get the first source not in use.  It is not marked as in-use until it is bound to a SoundNode.
	 * Returns: A source not in use, or null if all are in use. */
	ALSource getSource()
	{	foreach (source; sources)
			if (!source.in_use)
				return source;
		return null;
	}
	
	/*
	 * Called by the sound thread to update all active source's sound buffers. */
	void updateSounds(float unused)
	{	
		auto listener = CameraNode.getListener();
		
		
		if (listener)
		{	// Set the listener position, velocity, and orientation
			Matrix transform = listener.getAbsoluteTransform();
			Vec3f look = Vec3f(0, 0, -1).rotate(transform);
			Vec3f up = Vec3f(0, 1, 0).rotate(transform);
			float[6] concat;
			concat[0..3] = look.v;
			concat[3..6] = up.v;
	
			alListenerfv(AL_POSITION, &transform.v[12]);
			alListenerfv(AL_ORIENTATION, concat.ptr);
			alListenerfv(AL_VELOCITY, listener.getAbsoluteVelocity().ptr);
		
		
			// Map sounds to the listener.
			// TODO: synchronize on scene sound mutex.
			auto sounds = listener.getScene().getAllSounds();
			//auto max_sounds, 
		}
		
		// update each source's sound buffers.
		foreach (source; sources)
			if (source.in_use)
				source.updateBuffers();
	}
}

/**
 * Create a wrapper around all OpenAL functions providing the following additional features:
 * - Error results from each openal call are checked.
 * - On error, an exception is thrown with the OpenAL error code translated to a meaningful string.
 */
class OpenAL
{
	static char[][int] ALErrorLookup;
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
	static R execute(alias T, R=ReturnType!(baseTypedef!(typeof(T))))(ParameterTypeTuple!(baseTypedef!(typeof(T))) args)
	in {
		if (T.stringof[0..3] != "alc") // all non-alc functions require an active OpenAL Context
			if (OpenALContext.singleton) // if OpenALContext constructor has completed
				assert(OpenALContext.getInstance().getContext());
	}
	body
	{	int error = alGetError();
		static if (is (R==void))
			T(args);
		else
			R result = T(args);
		error = alGetError();
		if (error != AL_NO_ERROR)
			throw new OpenALException("OpenAL %s error %s", T.stringof, OpenAL.ALErrorLookup[error]);

		static if (!is (R==void))
			return result;
	}
	
	static Object getMutex()
	{	return mutex;		
	}
	
	/**
	 * Add wrappers for each OpenAL function (unfinished). */
	alias execute!(alSourceUnqueueBuffers) sourceUnqueueBuffers;
	alias execute!(alSourceQueueBuffers) sourceQueueBuffers; /// ditto
	alias execute!(alSourcef) sourcef; /// ditto
	alias execute!(alSourcefv) sourcefv; /// ditto
	alias execute!(alSourcePlay) sourcePlay; /// ditto
	alias execute!(alSourcePause) sourcePause; /// ditto
	alias execute!(alSourceStop) sourceStop; /// ditto
	alias execute!(alGenSources) genSources; /// ditto
	alias execute!(alDeleteSources) deleteSources; /// ditto
	alias execute!(alGetSourcei) getSourcei; /// ditto
	alias execute!(alIsBuffer) isBuffer; /// ditto
	alias execute!(alGenBuffers) genBuffers; /// ditto
	alias execute!(alDeleteBuffers) deleteBuffers; /// ditto
	alias execute!(alBufferData) bufferData; /// ditto	

	alias execute!(alcGetIntegerv) getIntegerv; /// ditto
	alias execute!(alcGetString) getString; /// ditto
	alias execute!(alcOpenDevice) openDevice; /// ditto	
	alias execute!(alcCreateContext) createContext; /// ditto
	alias execute!(alcMakeContextCurrent) makeContextCurrent; /// ditto

}