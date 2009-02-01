/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:	   Eric Poggel
 * License:	   <a href="lgpl.txt">LGPL</a>
 *
 * This module contains OpenAL wrapping classes that are used internally by the engine.
 * Ideally, few if any other modules should include derelict._openal and use its functions directly.
 */
module yage.system.openal;

import tango.math.Math;
import tango.io.Stdout;
import tango.util.Convert;
import tango.core.Thread;
import tango.core.Traits;

import derelict.openal.al;

import yage.core.array;
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
import yage.system.system;
import yage.system.log;
import yage.resource.sound;

// Not defined in derelict yet
const int ALC_MONO_SOURCES   = 0x1010;
const int ALC_STEREO_SOURCES = 0x1011;
const int AL_SEC_OFFSET = 0x1024;
const int AL_SAMPLE_OFFSET = 0x1025;

template e()
{	const char[] e = "scope(failure) Stdout.format(__FILE__, \" line:\", __LINE__);";
}


/*
 * Represents an OpenAL source (an instance of a sound playing).
 * Typical hardware can only support a small number of these, so SoundNodes map and unmap to these sources as needed. 
 * This is used internally by the engine and should never need to be instantiated manually. */
private class ALSource : IFinalizable
{
	package uint al_source;
	
	protected SoundNode soundNode;
	
	protected Sound sound;
	protected float	pitch;
	protected float	radius;	// The radius of the Sound that plays.
	protected float	volume;	
	protected bool	looping = false;
	protected Vec3f position;
	protected Vec3f velocity;
	
	protected int	size;			// number of buffers that we use at one time, either sounds' buffers per second, 
									// or less if the sound is less than one second long.
	protected bool	enqueue = true;	// Keep enqueue'ing more buffers, false if no loop and at end of track.
	protected uint	buffer_start;	// the first buffer in the array of currently enqueue'd buffers
	protected uint	buffer_end;		// the last buffer in the array of currently enqueue'd buffers
	protected uint	to_process;		// the number of buffers to queue next time.
	
	/*
	 * Create the OpenAL Source. */
	this()
	{	mixin(e!());		
		OpenAL.genSources(1, &al_source);
	}
	
	/*
	 * Stop playback, unqueue all buffers and then delete the source itself. */
	~this()
	{	mixin(e!());
		finalize();		
	}
	void finalize() // ditto
	{	mixin(e!());
		if (al_source)
		{	unbind();
			alDeleteSources(1, &al_source);
			al_source = 0;
		}
	}

	/*
	 * SoundNodes act as a virtual instance of a real ALSource
	 * This function ensures the ALSource matches all of the parameters of the SoundNode. 
	 * If called multiple times from the same SoundNode, this will just update the parameters. */
	void bind(SoundNode soundNode)
	{	mixin(e!());
		this.soundNode = soundNode;
		this.looping = soundNode.getLooping();
		
		synchronized(OpenAL.getMutex())
		{
			
			if (sound !is soundNode.getSound())
			{	// Stdout.format("Changing sound to %s", soundNode.getSound().getSource());
				sound = soundNode.getSound();
			
				// Ensure that our number of buffers isn't more than what exists in the sound file
				int len = sound.getBuffersLength();
				int sec = sound.getBuffersPerSecond();
				size = len < sec ? len : sec;
				
				seek(soundNode.tell());
			}
			
			if (radius != soundNode.getSoundRadius())
			{	radius = soundNode.getSoundRadius();
				// Stdout.format("Changing radius to %s", radius);
				OpenAL.sourcef(al_source, AL_ROLLOFF_FACTOR, 1.0/radius);
			}
			
			if (this.volume != soundNode.getVolume())
			{	volume = soundNode.getVolume();
				// Stdout.format("Changing volume to %s", volume);
				OpenAL.sourcef(al_source, AL_GAIN, volume);
			}
			
			if (this.pitch != soundNode.getPitch())
			{	pitch = soundNode.getPitch();
				// Stdout.format("Changing pitch to %s", pitch);
				OpenAL.sourcef(al_source, AL_PITCH, pitch);
			}
			
			double epsilon = 1.0/sound.getBuffersPerSecond(); // is this always .05?
			double _tell = tell();
			double seconds = soundNode.tell();
			//Stdout.format("times: %f, %f", _tell, seconds);
			if (soundNode.reseek && (seconds+epsilon < _tell ||  _tell < seconds-epsilon))
			{	// Stdout.format("Changing playback position from %s to %s", _tell, seconds);				
				seek(seconds);
				// Stdout.format(tell());
			} else if (enqueue) // update soundNode's playback timer to the real playback location.
				soundNode.seek(_tell);
			soundNode.reseek = false;
			
			Vec3f position = soundNode.getAbsolutePosition();			
			if (this.position != position)
			{	//Stdout.format("Changing position from %s to %s", this.position, position);
				this.position = position;
				OpenAL.sourcefv(al_source, AL_POSITION, position.ptr);
			}
			
			Vec3f velocity = soundNode.getAbsoluteVelocity();
			if (this.velocity != velocity)
			{	//Stdout.format("Changing velocity from %s to %s", this.velocity, velocity);
				this.velocity = velocity;
				OpenAL.sourcefv(al_source, AL_VELOCITY, velocity.ptr);
			}
			
			//Stdout.format("radius is %s, volume is %s, paused is %s, tell is %s, position is %s, velocity is %s",
			//	radius, volume, _paused, seconds, position, velocity);
		}
	}
	
	/*
	 * Unbind this sound source from a sound node, stopping playback and resetting key state variables. */
	void unbind()
	{	mixin(e!());
		if (soundNode)
		{	enqueue	= false;
			synchronized(OpenAL.getMutex())
			{	//Stdout.format("unbinding source");
				OpenAL.sourceStop(al_source);
				//Stdout.format("2]");
				unqueueBuffers();
			}
			buffer_start = buffer_end = 0;
			sound = null; // so sound can be freed if no more references.
			soundNode = null;
		}
	}
		
	/*
	 * Seek to the position in the track.  Seek has a precision of .05 seconds.
	 * @throws OpenALException if the value is outside the range of the Sound. */
	void seek(double seconds)
	{	mixin(e!());
		int buffers_per_second = sound.getBuffersPerSecond();
		int new_start = cast(int)floor(seconds*buffers_per_second);
		float fraction = seconds*buffers_per_second - new_start;
		if (new_start>sound.getBuffersLength())
			throw new OpenALException("ALSource.seek(%f) is invalid for '%s'", seconds, sound.getSource());

		// Delete any leftover buffers
		synchronized(OpenAL.getMutex())
		{	OpenAL.sourceStop(al_source);
			unqueueBuffers();
			buffer_start = buffer_end = new_start;
			enqueue = true;
			updateBuffers();
			OpenAL.sourcePlay(al_source);			
			OpenAL.sourcef(al_source, AL_SEC_OFFSET, fraction/buffers_per_second);
		}
		// Stdout.format("seeked to ", (new_start+fraction)/buffers_per_second);
	}

	/*
	 * Tell the position of the playback of the current sound file, in seconds. */ 
	double tell()
	{	mixin(e!());
		int processed; // [below] synchronization shouldn't be needed for read-only functions... ?
		OpenAL.getSourcei(al_source, AL_BUFFERS_PROCESSED, &processed);
		float fraction=0;
		OpenAL.getSourcef(al_source, AL_SEC_OFFSET, &fraction);
		return ((buffer_start + processed) % sound.getBuffersLength()) /
			cast(double)sound.getBuffersPerSecond();
	}

	/*
	 * Enqueue new buffers for this SoundNode to play
	 * Takes into account pausing, looping and all kinds of other things.
	 * This is normally called automatically from the SoundNode's scene's sound thread. 
	 * This will fail silently if the SoundNode has no sound or no scene. */
	void updateBuffers()
	in {
		assert(soundNode);
		assert(sound);
	}
	body
	{	mixin(e!());
		synchronized(OpenAL.getMutex())
		{	if (enqueue)
			{	
				//Stdout.format("updating buffers for %s", sound.getSource());
				// Count buffers processed since last time we queue'd more
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
					unqueueBuffers();
	
					// Enqueue as many buffers as what are available
					sound.allocBuffers(buffer_end, to_process);
					OpenAL.sourceQueueBuffers(al_source, to_process, sound.getBuffers(buffer_end, buffer_end+to_process).ptr);
	
					buffer_start+= processed;
					buffer_end	+= to_process;
				}
			}
	
			// If not playing
			// Is this block unnecessary if everything behaves as it should?
			int state;
			OpenAL.getSourcei(al_source, AL_SOURCE_STATE, &state);
			if (state==AL_STOPPED || state==AL_INITIAL)
			{	// but it should be, resume playback
				if (enqueue)
					OpenAL.sourcePlay(al_source);
				else // we've reached the end of the track
				{	
					// stop
					OpenAL.sourceStop(al_source);
					unqueueBuffers();
					buffer_start = buffer_end = 0;
					
					if (looping)
					{	//play
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
	 * Unqueue all buffers that have finished playing
	 * If the source is stopped, all buffers will be removed. */
	protected void unqueueBuffers()
	{	mixin(e!());
		if (sound)
		{	synchronized(OpenAL.getMutex())
			{	int processed;
				OpenAL.getSourcei(al_source, AL_BUFFERS_PROCESSED, &processed);
				OpenAL.sourceUnqueueBuffers(al_source, processed, sound.getBuffers(buffer_start, buffer_start+processed).ptr);
				sound.freeBuffers(buffer_start, processed);
		}	}	
	}
}

/**
 * This is a representation of an OpenAL Context as a Singleton, simce many OpenAL implementations support only one context.
 * It is used internally by the engine and shouldn't need to be used manually.
 * It provides the following features:
 * 
 * Instantiates an OpenAL device and context upon construction.$(BR)
 * Stores a short array of ALSource wrappers that can be wrapped around with an infinite number of virtual sources.$(BR)
 * Controls a sound thread that handles buffering audio to all active ALSources. */
class OpenALContext : IFinalizable
{	
	protected const int MAX_SOURCES = 32;
	protected const int UPDATE_FREQUENCY = 30;
	protected ALSource[] sources;
	
	protected ALCdevice* device = null;
	protected ALCcontext* context = null;	
	
	protected Repeater sound_thread = null;
	
	protected SoundNode[] sounds; // currently playing sounds.
	
	/**
	 * Constructor.
	 * Create a device, a context, and start a thread that automatically updates all sound buffers.
	 * This function is called automatically by the Singleton template.
	 * To get an instance, use OpenALContext.getInstance(). */
	protected this()
	{	mixin(e!());
		// Get a device
		device = OpenAL.openDevice(null);		
		Log.write("Using OpenAL System '%s'.", OpenAL.getString(device, ALC_DEVICE_SPECIFIER));
	
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
				sources ~= source;
			} catch (OpenALException e)
			{	break;				
			}
		}
		
		// Start a thread to perform sound updates.
		sound_thread = new Repeater();
		sound_thread.setFrequency(UPDATE_FREQUENCY);
		sound_thread.setFunction(&updateSounds);
		sound_thread.play();
	}
	
	/**
	 * Add the getInstance() method to get an instance of this singleton.
	 * On the first requiest (which happens automatically in System.init(), the constructor is called. */
	mixin Singleton!(typeof(this));
	
	
	/**
	 * Delete the dedvice and context,
	 * delete all sources, and set the current context to null. */
	~this()
	{	finalize();
	}
	
	/**
	 * Delete the dedvice and context,
	 * delete all sources, and set the current context to null. */
	void finalize()
	{	mixin(e!());
		if (context)
		{	sound_thread.finalize();
			synchronized(OpenAL.getMutex())
			{	foreach (source; sources)
					if (source) // in case of the unpredictible order of the gc.
						source.finalize();
				sources = null;
			
				OpenAL.makeContextCurrent(null);
				OpenAL.destroyContext(context);			
				OpenAL.closeDevice(device);
				context = device = null;
			}
		}
	}
	
	/**
	 * Get the OpenAL Context. */
	ALCcontext* getContext()
	{	mixin(e!());
		return context;		
	}
	
	/*
	 * Called by the sound thread to update all active source's sound buffers. 
	 * XXX: Access violation from this function occurred once on exit.  */
	protected void updateSounds(float unused)
	{	mixin(e!());
			
		auto listener = CameraNode.getListener();
		if (listener)
		{	auto scene = listener.getScene();
			
			// Calculate the listener position, velocity, and orientation
			Matrix transform = listener.getAbsoluteTransform();
			Vec3f camera_position = Vec3f(transform.v[12..15]);
			Vec3f look = Vec3f(0, 0, -1).rotate(transform);
			Vec3f up = Vec3f(0, 1, 0).rotate(transform);
			float[6] concat;
			concat[0..3] = look.v;
			concat[3..6] = up.v;
			
			// Create an array of the loudest sounds
			sounds.length = 0;
			synchronized(scene.getSoundsMutex())
				foreach (sound; listener.getScene().getAllSounds())
				{	if (!sound.paused() && sound.getSound())
					{	sound.intensity = sound.getVolumeAtPosition(camera_position);						
						if (sound.intensity > 0.002) // A very quiet sound, arbitrary number
							addSorted!(SoundNode, float)(sounds, sound, false, (SoundNode s){return s.intensity;}, sources.length );
				}	}
	
			synchronized (OpenAL.getMutex())
			{	
				// Set the listener position, velocity, and orientation
				OpenAL.listenerfv(AL_POSITION, camera_position.ptr);
				OpenAL.listenerfv(AL_ORIENTATION, concat.ptr);
				OpenAL.listenerfv(AL_VELOCITY, listener.getAbsoluteVelocity().ptr);
				
				// Unbind sources that no longer have a SoundNode.
				foreach (i, source; sources)
				{	
					bool unbind = true;
					foreach (sound; sounds)
						if (source.soundNode is sound)
						{	//Stdout.format("rebinding %s to source %d", sound.getSound().getSource(), i);
							source.bind(sound);
							unbind = false;
							break;					
						}
					if (unbind)
						source.unbind();
				}
								
				// Bind SoundNodes to empty sources.
				foreach (sound; sounds)			
				{	bool unbound = true;
					foreach (source; sources)
						if (source.soundNode is sound)
						{	unbound = false;
							break;					
						}
					
					// if this sound is not bould to any source
					if (unbound)
					{	foreach (i, source; sources) // find a source to bind to.
							if (!source.soundNode)
							{	//Stdout.format("binding %s to source %d, intensity=%f", sound.getSound().getSource(), i, sound.intensity);
								source.bind(sound); // this is never getting called.
								break;
							}
					}
				}
			}
		}
		
		//debugSources();
		
		// update each source's sound buffers.
		foreach (source; sources)
			if (source.soundNode)
				source.updateBuffers();
	}
	
	void debugSources()
	{	try {
			foreach (i, source; sources)
			{	if (source.soundNode)
					Stdout.format("source %d bound, vol=%s, dist=%s, file=%s", i, source.soundNode.intensity, 
						CameraNode.getListener().getAbsolutePosition().distance(source.soundNode.getAbsolutePosition()), 
						source.soundNode.getSound().getSource());
				else
					Stdout.format("source %s unbound", i);
			}
			foreach (i, sound; sounds)
			{	
				Stdout.format("sound %s, file=%s", i, sound.intensity, sound.getSound().getSource());
			}
		}
		catch (Exception e) {}
	}
}

/**
 * Create a wrapper around all OpenAL functions providing the following additional features:
 * 
 * Error results from each openal call are checked.$(BR)
 * On error, an exception is thrown with the OpenAL error code translated to a meaningful string. */
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
	static R execute(alias T, R=ReturnTypeOf!(baseTypedef!(typeof(T))))(ParameterTupleOf!(baseTypedef!(typeof(T))) args)
	in {
		if (T.stringof[0..3] != "alc" && OpenALContext.singleton) // all non-alc functions require an active OpenAL Context
			assert(OpenALContext.getInstance().getContext());
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
				if (T.stringof[0..3] != "alc")
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