/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.sound;
import derelict.openal.al;
import std.math;
import std.string;
import std.stdio;
import std.gc;
import yage.core.math;
import yage.core.interfaces;
import yage.core.exceptions;
import yage.resource.manager;
import yage.resource.sound;
import yage.system.alcontext;
import yage.scene.node;
import yage.scene.movable;
import yage.scene.scene;


/**
 * A node that emits a sound.
 */ 
class SoundNode : MovableNode, ITemporal
{	
	protected uint	al_source;		// OpenAL index of this Sound ResourceManager
	protected Sound	sound;			// The Sound ResourceManager (file) itself.

	protected float	pitch = 1.0;
	protected float	radius = 256;	// The radius of the Sound that plays.
	protected float	volume = 1.0;
	protected bool	looping = false;
	protected bool	_paused  = true;// true if paused or stopped

	// To be moved excluisively to ALSource
	protected int	size;			// number of buffers that we use at one time
	protected bool	enqueue = true;	// Keep enqueue'ing more buffers, false if no loop and at end of track.
	protected uint	buffer_start;	// the first buffer in the array of currently enqueue'd buffers
	protected uint	buffer_end;		// the last buffer in the array of currently enqueue'd buffers
	protected uint	to_process;		// the number of buffers to queue next time.
	
	/**
	 * Create a SoundNode and optinally set the sound from an already loaded sound or a sound filename. */
	this()
	{	super();
		synchronized(ALContext.getMutex())
		{	try
			{	ALContext.genSources(1, &al_source); // first, so position to be set correctly by SoundNode.setTransformDirty()
			} catch (OpenALException e)
			{	genCollect(); // hopefully this can call some SoundNode destructors and get us some sounds.
				try
				{	ALContext.genSources(1, &al_source); // first, so position to be set correctly by SoundNode.setTransformDirty()
				} catch (OpenALException e)
				{	fullCollect(); // slower, but more likely to work.
					ALContext.genSources(1, &al_source);
				}
			}
			setSoundRadius(radius);
		}
	}
	this(Sound sound) /// ditto
	{	this();
		setSound(sound);
	}	
	this(char[] filename) /// ditto
	{	this();
		setSound(filename);
	}
	
	/**
	 * Overridden to call finalize(). */
	~this()
	{	finalize();
	}
	
	/**
	 * Make a duplicate of this node, unattached to any parent Node.
	 * Params:
	 *     children = recursively clone children (and descendants) and add them as children to the new Node.
	 * Returns: The cloned Node. */
	override SoundNode clone(bool children=false)
	{	auto result = cast(SoundNode)super.clone(children);
		
		result.setSound(sound);
		result.seek(tell());	
		result.setPitch(pitch);
		result.setSoundRadius(radius);
		result.setVolume(volume);
		result.setLooping(looping);
		if (paused())
			result.pause();
		else
			result.play();
		return result;
	}

	/**
	 * Delete OpenAL Sound source on destruction. */
	override public void finalize()
	{	if (al_source)
		{	synchronized(ALContext.getMutex())
			{	stop();
				unqueueBuffers();
				ALContext.deleteSources(1, &al_source);
			}
			al_source = 0;
			super.finalize();
		}
	}

	/**
	 * Get / set the Sound ResourceManager that this SoundNode will play. */
	Sound getSound()
	{	return sound;
	}	
	void setSound(Sound _sound) /// ditto
	{	bool tpaused = paused();
		stop();
		sound = _sound;

		// Ensure that our number of buffers isn't more than what exists in the sound file
		int len = sound.getBuffersLength();
		int sec = sound.getBuffersPerSecond();
		size = len < sec ? len : sec;

		if (tpaused)
			pause();
		else
			play();
	}

	/** Set the Sound used by this Node, using the ResourceManager Manager
	 *  to ensure that no Sound is loaded twice.
	 *  Equivalent of setSound(ResourceManager.sound(filename)); */
	void setSound(char[] filename)
	{	setSound(ResourceManager.sound(filename));
	}

	/// Get the pitch of the SoundNode.
	float getPitch()
	{	return pitch;
	}

	/**
	 * Set the pitch of the SoundNode.
	 * This has nothing to do with the frequency of the loaded Sound ResourceManager.
	 * Params:
	 * pitch = Less than 1.0 is deeper, greater than 1.0 is higher. */
	void setPitch(float pitch)
	{	this.pitch = pitch;
		synchronized(ALContext.getMutex())
			ALContext.sourcef(al_source, AL_PITCH, pitch);
	}

	/// Get the radius of the SoundNode
	float getSoundRadius()
	{	return radius;
	}

	/**
	 * Set the radius of the SoundNode.  The volume of the sound falls off at a rate of
	 * inverse distance squared.  The default radius is 256.
	 * Params:
	 * radius = The sound will be 1/2 its volume at this distance.*/
	void setSoundRadius(float radius)
	{	this.radius = radius;
		synchronized(ALContext.getMutex())
			ALContext.sourcef(al_source, AL_ROLLOFF_FACTOR, 1.0/radius);
	}

	/// Get the volume (gain) of the SoundNode
	float getVolume()
	{	return volume;
	}

	/**
	 * Set the volume (gain) of the SoundNode.
	 * Params:
	 * volume = 1.0 is the default. */
	void setVolume(float volume)
	{	this.volume = volume;
		synchronized(ALContext.getMutex())
		{	ALContext.sourcef(al_source, AL_GAIN, volume);
		}
	}

	/// Does the Sound loop when playback is finished?
	bool getLooping()
	{	return looping;
	}

	/// Set whether the playback of the SoundNode loops when playback is finished.
	void setLooping(bool looping=true)
	{	this.looping = looping;
	}


	/// Begin / resume playback of the sound at the last position.
	void play()
	{	// Only do something if changing states
		if (_paused)
		{	_paused = false;
			if (sound is null)
				throw new YageException("You cannot play or unpause a SoundNode without first calling setSound().");
			synchronized(ALContext.getMutex())
				ALContext.sourcePlay(al_source);
			enqueue = true;
		}	
	}
	
	/// Pause playback of the sound.
	void pause()
	{	// Only do something if changing states
		if (!_paused)
		{	_paused = true;
			synchronized(ALContext.getMutex())
				ALContext.sourcePause(al_source);
		}
	}

	/// Is the sound currently paused (or stopped?)
	bool paused()
	{	return _paused;
	}
	
	/** 
	 * Seek to the position in the track.  Seek has a precision of .05 seconds.
	 * @throws YageException if the value is outside the range of the Sound. */
	void seek(double seconds)
	{	if (sound is null)
			throw new YageException("You cannot seek a SoundNode without first calling setSound().");
		uint secs = cast(uint)(seconds*size);
		if (secs>sound.getBuffersLength())
			throw new YageException("SoundNode.seek(%d) is invalid for '%s'", seconds, sound.getSource());

		// Delete any leftover buffers
		synchronized(ALContext.getMutex())
		{	unqueueBuffers();
			buffer_start = buffer_end = secs;
			if (_paused)
				pause();
			else
				play();
		}
	}

	/// Tell the position of the playback of the current sound file, in seconds.
	double tell()
	{	int processed;
		synchronized(ALContext.getMutex())
			ALContext.getSourcei(al_source, AL_BUFFERS_PROCESSED, &processed);
		return ((buffer_start+processed) % sound.getBuffersLength()) /
			cast(double)sound.getBuffersPerSecond();
	}

	/// Stop the SoundNode from playing and rewind it to the beginning.
	void stop()
	{	synchronized(ALContext.getMutex())
		{	enqueue	= false;
			if (sound !is null)
			{	ALContext.sourceStop(al_source);
				seek(0);
		}	}
	}

	/**
	 * Return a string representation of this Node for human reading.
	 * Params:
	 * recurse = Print this Node's children as well. */
	override char[] toString()
	{	return toString(false);
	}	
	char[] toString(bool recurse) /// ditto
	{	static int indent;
		char[] pad = new char[indent*3];
		pad[0..length] = ' ';

		char[] result = super.toString();
		result ~= pad~"Sound: " ~ sound.getSource() ~ "\n";
		result ~= pad~"Radius: " ~ std.string.toString(radius) ~ "\n";
		result ~= pad~"Volume: " ~ std.string.toString(volume) ~ "\n";
		result ~= pad~"Pitch : " ~ std.string.toString(pitch) ~ "\n";
		result ~= pad~"Looping: " ~ std.string.toString(looping) ~ "\n";
		result ~= pad~"Paused: " ~ std.string.toString(paused) ~ "\n";

		result ~= pad~"Number of Buffers: " ~ std.string.toString(size) ~ "\n";
		result ~= pad~"Buffer Start: " ~ std.string.toString(buffer_start) ~ "\n";
		result ~= pad~"Buffer End: " ~ std.string.toString(buffer_end) ~ "\n";
		result ~= pad~"Buffers to Process: " ~ std.string.toString(to_process) ~ "\n";
		result ~= pad~"Enqueue: " ~ std.string.toString(enqueue) ~ "\n";
		delete pad;

		if (recurse)
		{	indent++;
			foreach (Node c; children)
				result ~= c.toString();
			indent--;
		}

		return result;
	}

	/**
	 * Enqueue new buffers for this SoundNode to play
	 * Takes into account pausing, looping and all kinds of other things.
	 * This is normally called automatically from the SoundNode's scene's sound thread. 
	 * This will fail silently if the SoundNode has no sound or no scene */
	void updateBuffers()
	{
		if (!sound || !scene)
			return;
		
		synchronized(ALContext.getMutex())
		{	if (enqueue)
			{	// Count buffers processed since last time we queue'd more
				int processed;
				ALContext.getSourcei(al_source, AL_BUFFERS_PROCESSED, &processed);
				to_process = max(processed, cast(int)(size-(buffer_end-buffer_start)));
	
				// Update the buffers for this source if more than 1/4th have been used.
				if (to_process > size/4)
				{
					// If looping and our buffer has reached the end of the track
					int blength = sound.getBuffersLength();
					if (!looping && buffer_end+to_process >= blength)
						to_process = blength - buffer_end;
	
					// Unqueue old buffers
					if (processed > 0)	// new, ensure no bugs
					{	//writefln("Unqueuing buffers[%d..%d]", buffer_start, buffer_start+processed);
						//alSourceUnqueueBuffers(al_source, processed, sound.getBuffers(buffer_start, buffer_start+processed).ptr);
						//sound.freeBuffers(buffer_start, processed);
						
						unqueueBuffers(processed);
					}
	
					// Enqueue as many buffers as what are available
					//writefln("Enqueuing buffers[%d..%d]", buffer_end, buffer_end+to_process);
					sound.allocBuffers(buffer_end, to_process);
					ALContext.sourceQueueBuffers(al_source, to_process, sound.getBuffers(buffer_end, buffer_end+to_process).ptr);
	
					buffer_start+= processed;
					buffer_end	+= to_process;
				}
			}
	
			// If not playing
			int temp;
			ALContext.getSourcei(al_source, AL_SOURCE_STATE, &temp);
			if (temp==AL_STOPPED || temp==AL_INITIAL)
			{	// but it should be, resume playback
				if (!paused && enqueue)
					ALContext.sourcePlay(al_source);
				else // we've reached the end of the track
				{	bool tpaused = paused;
					stop();
					if (looping && !tpaused)
						play();
				}
			}
	
			// This must be here for tracks with their total number of buffers equal to size.
			if (enqueue)
				// If not looping and our buffer has reached the end of the track
				if (!looping && buffer_end+1 >= sound.getBuffersLength())
					enqueue = false;
		}
	}
	
	/**
	 * 
	 * Params:
	 *     all = Unqueue all buffers, or just those that have been processed? */
	protected void unqueueBuffers(int number=-1)
	{	if (sound)	
		{	if (number == -1)
				number = buffer_end - buffer_start;		
			synchronized(ALContext.getMutex())
			{	ALContext.sourceUnqueueBuffers(al_source, number, sound.getBuffers(buffer_start, buffer_start+number).ptr);
				sound.freeBuffers(buffer_start, number-1);
			}
		}
	}


	/// Overridden to also call updateBuffers().
	override void update(float delta)
	{	super.update(delta);
		//updateBuffers();	// best place to call this?
	}

	/*
	 * Stop playing the sound when
	 * This should be protected, but making it anything but public causes it not to be called.
	 * Most likely a D bug. */
	override void ancestorChange(Node old_ancestor)
	{	Scene old_scene = old_ancestor ? old_ancestor.scene : null;
		super.ancestorChange(old_ancestor); // must be called first so scene is set.
		
		// Resume / pause the sound if becoming / not becoming part of a scene.
		if (!_paused)
		{	if (scene && !old_scene)
				synchronized(ALContext.getMutex())
					ALContext.sourcePause(al_source);
			else if (!scene && old_scene)
				synchronized(ALContext.getMutex())
					ALContext.sourcePlay(al_source);
		}
		
		// Update scene's list of sounds
		if (old_scene)
			old_scene.removeSound(this);
		if (scene && scene != old_scene)
			scene.addSound(this);
	}
	
	
	/**
	 * Update sound position and velocity as soon as a new position is calculated. */
	override protected void calcTransform()
	{	super.calcTransform();
		if (al_source)
			synchronized(ALContext.getMutex())
			{	ALContext.sourcefv(al_source, AL_POSITION, &(getAbsoluteTransform().v[12]));
				ALContext.sourcefv(al_source, AL_VELOCITY, &(getAbsoluteVelocity().v[0]));
			}
	}
}