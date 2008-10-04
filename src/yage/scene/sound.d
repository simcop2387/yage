/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.sound;

import std.math;
import std.string;
import std.stdio;
import derelict.openal.al;
import yage.core.math;
import yage.core.interfaces;
import yage.resource.resource;
import yage.resource.sound;
import yage.scene.node;
import yage.scene.movable;
import yage.scene.scene;


/// A node that emits a sound.
class SoundNode : MovableNode, ITemporal
{	protected:

	uint		al_source;		// OpenAL index of this Sound Resource
	Sound		sound;			// The Sound Resource (file) itself.

	float		pitch = 1.0;
	float		radius = 256;	// The radius of the Sound that plays.
	float		volume = 1.0;
	bool		looping = false;
	bool		_paused  = true;	// true if paused or stopped

	int			size;			// number of buffers that we use at one time
	bool		enqueue = true;	// Keep enqueue'ing more buffers, false if no loop and at end of track.
	uint		buffer_start;	// the first buffer in the array of currently enqueue'd buffers
	uint		buffer_end;		// the last buffer in the array of currently enqueue'd buffers
	uint		to_process;		// the number of buffers to queue next time.

	public:

	/// Construct this Node as a child parent.
	this(Node parent)
	{	alGenSources(1, &al_source); // first, so position to be set correctly by SoundNode.setTransformDirty()
		super(parent);
		setSoundRadius(radius);
	}

	/**
	 * Construct this Node as a copy of another Node and recursively copy all children.
	 * Params:
	 * parent = This Node will be a child of parent.
	 * original = This Node will be an exact copy of original.*/
	this (Node parent, SoundNode original)
	{
		alGenSources(1, &al_source); // first, so position to be set correctly by SoundNode.setTransformDirty()
		super(parent, original);

		setSound(original.sound);
		seek(original.tell());

		setPitch(original.pitch);
		setSoundRadius(original.radius);
		setVolume(original.volume);
		setLooping(original.looping);
		if (original._paused)
			pause();
		else
			play();
	}

	/// Remove the Sound Node, overridden for OpenAL cleanup.
	void remove()
	{	stop();
		alDeleteSources(1, &al_source);
		super.remove();
	}

	/// Return the Sound Resource that this SoundNode plays.
	Sound getSound()
	{	return sound;
	}

	/// Set the Sound Resource that this SoundNode will play.
	void setSound(Sound _sound)
	{	bool tpaused = paused;
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

	/** Set the Sound used by this Node, using the Resource Manager
	 *  to ensure that no Sound is loaded twice.
	 *  Equivalent of setSound(Resource.sound(filename)); */
	void setSound(char[] filename)
	{	setSound(Resource.sound(filename));
	}

	/// Get the pitch of the SoundNode.
	float getPitch()
	{	return pitch;
	}

	/**
	 * Set the pitch of the SoundNode.
	 * This has nothing to do with the frequency of the loaded Sound Resource.
	 * Params:
	 * pitch = Less than 1.0 is deeper, greater than 1.0 is higher. */
	void setPitch(float pitch)
	{	this.pitch = pitch;
		alSourcef(al_source, AL_PITCH, pitch);
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
		alSourcef(al_source, AL_ROLLOFF_FACTOR, 1.0/radius);
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
		alSourcef(al_source, AL_GAIN, volume);
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
				throw new Exception("You cannot play or unpause a SoundNode without first calling setSound().");
			alSourcePlay(al_source);
			enqueue = true;
		}	
	}
	
	/// Pause playback of the sound.
	void pause()
	{	// Only do something if changing states
		if (!_paused)
		{	_paused = true;
			if (paused)
				alSourcePause(al_source);
		}
	}

	/// Is the sound currently paused (or stopped?)
	bool paused()
	{	return _paused;
	}
	
	/** 
	 * Seek to the position in the track.  Seek has a precision of .05 seconds.
	 * @throws Exception if the value is outside the range of the Sound. */
	void seek(double seconds)
	{	if (sound is null)
			throw new Exception("You cannot seek a SoundNode without first calling setSound().");
		uint secs = cast(uint)(seconds*size);
		if (secs>sound.getBuffersLength())
			throw new Exception("SoundNode.seek("~.toString(seconds)~") is invalid for '"~sound.getSource()~"'");

		// Delete any leftover buffers
		int processed;
		alGetSourcei(al_source, AL_BUFFERS_PROCESSED, &processed);
		if (processed>0)
		{	//writefln("Unqueuing buffers[%d..%d]", buffer_start, buffer_start+processed);
			alSourceUnqueueBuffers(al_source, processed, sound.getBuffers(buffer_start, buffer_start+processed).ptr);
			sound.freeBuffers(buffer_start, processed);
		}

		buffer_start = buffer_end = secs;
		if (_paused)
			pause();
		else
			play();
	}

	/// Tell the position of the playback of the current sound file, in seconds.
	double tell()
	{	int processed;
		alGetSourcei(al_source, AL_BUFFERS_PROCESSED, &processed);
		return ((buffer_start+processed) % sound.getBuffersLength()) /
			cast(double)sound.getBuffersPerSecond();
	}

	/// Stop the SoundNode from playing and rewind it to the beginning.
	void stop()
	{	pause();
		enqueue		= false;
		if (sound !is null)
		{	alSourceStop(al_source);
			seek(0);
		}
	}

	///
	char[] toString()
	{	return toString(false);
	}

	/**
	 * Return a string representation of this Node for human reading.
	 * Params:
	 * recurse = Print this Node's children as well. */
	char[] toString(bool recurse)
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
	 * This is normally called automatically by the update function. */
	void updateBuffers()
	{
		if (enqueue)
		{	// Count buffers processed since last time we queue'd more
			int processed;
			alGetSourcei(al_source, AL_BUFFERS_PROCESSED, &processed);
			to_process = max(processed, cast(int)(size-(buffer_end-buffer_start)));

			// Update the buffers for this source
			if (to_process > size/4)
			{
				// If looping and our buffer has reached the end of the track
				int blength = sound.getBuffersLength();
				if (!looping && buffer_end+to_process >= blength)
					to_process = blength - buffer_end;

				// Unqueue old buffers
				if (processed > 0)	// new, ensure no bugs
				{	//writefln("Unqueuing buffers[%d..%d]", buffer_start, buffer_start+processed);
					alSourceUnqueueBuffers(al_source, processed, sound.getBuffers(buffer_start, buffer_start+processed).ptr);
					sound.freeBuffers(buffer_start, processed);
				}

				// Enqueue as many buffers as what are available
				//writefln("Enqueuing buffers[%d..%d]", buffer_end, buffer_end+to_process);
				sound.allocBuffers(buffer_end, to_process);
				alSourceQueueBuffers(al_source, to_process, sound.getBuffers(buffer_end, buffer_end+to_process).ptr);

				buffer_start+= processed;
				buffer_end	+= to_process;
			}
		}

		// If not playing
		int temp;
		alGetSourcei(al_source, AL_SOURCE_STATE, &temp);
		if (temp==AL_STOPPED || temp==AL_INITIAL)
		{	// but it should be, resume playback
			if (!paused && enqueue)
				alSourcePlay(al_source);
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


	/// Overridden to also call updateBuffers().
	void update(float delta)
	{	super.update(delta);
		if (sound !is null)
			updateBuffers();	// best place to call this?
	}

	/// Overridden so that the position of the sound is updated in OpenAL when this node is moved.
	void setTransformDirty()
	{	super.setTransformDirty();
		alSourcefv(al_source, AL_POSITION, &(getAbsoluteTransform().v[12]));
		alSourcefv(al_source, AL_VELOCITY, &(getAbsoluteVelocity().v[0]));
	}

}
