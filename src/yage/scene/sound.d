/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.sound;

import tango.stdc.math;
import tango.math.Math;
import yage.core.exceptions;
import yage.core.interfaces;
import yage.core.math;
import yage.core.timer;
import yage.core.vector;
import yage.resource.manager;
import yage.resource.sound;
import yage.scene.node;
import yage.scene.movable;
import yage.scene.scene;

/**
 * A node that emits a sound.
 */ 
class SoundNode : MovableNode, ITemporal
{	
	protected Sound	sound;			// The Sound ResourceManager (file) itself.

	protected float	pitch = 1.0;
	protected float	radius = 256;	// The radius of the Sound that plays.
	protected float	volume = 1.0;
	protected bool	looping = false;
	
	Timer timer;
	
	public float intensity; // used internally by the engine.
	public bool reseek = false;
	
	/**
	 * Create a SoundNode and optionally set the sound from an already loaded sound or a sound filename. */
	this()
	{	super();
		timer = new Timer(false);
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
		result.timer = timer.clone();
		result.setPitch(pitch);
		result.setSoundRadius(radius);
		result.setVolume(volume);
		result.setLooping(looping);
		return result;
	}

	/**
	 * Get / set the Sound ResourceManager that this SoundNode will play. */
	Sound getSound()
	{	return sound;
	}	
	void setSound(Sound sound) /// ditto
	{	this.sound = sound;
	}

	/** Set the Sound used by this Node, using the ResourceManager Manager
	 *  to ensure that no Sound is loaded twice.
	 *  Equivalent of setSound(ResourceManager.sound(filename)); */
	void setSound(char[] filename)
	{	setSound(ResourceManager.sound(filename));
	}

	/**
	 * Get / set the pitch of the SoundNode.
	 * This has nothing to do with the frequency of the loaded Sound ResourceManager.
	 * Params:
	 * pitch = Less than 1.0 is deeper, greater than 1.0 is higher. */
	float getPitch() /// ditto
	{	return pitch;
	}
	void setPitch(float pitch)
	{	this.pitch = pitch;
	}

	/**
	 * Get / set the radius of the SoundNode.  The volume of the sound falls off at a rate of
	 * inverse distance squared.  The default radius is 256.
	 * Params:
	 * radius = The sound will be 1/2 its volume at this distance.*/
	float getSoundRadius()
	{	return radius;
	}
	void setSoundRadius(float radius) /// ditto
	{	this.radius = radius;
	}

	/**
	 * Get / set the volume (gain) of the SoundNode.
	 * Params:
	 * volume = 1.0 is the default. */
	float getVolume()
	{	return volume;
	}
	void setVolume(float volume) /// ditto
	{	this.volume = volume;
	}
	
	/**
	 * Get the volume of this sound as it would be heard at an arbitrary position.
	 * Params:
	 *     position = 3D Coordinates
	 * Returns: The volume, where n is the volume of a SoundNode with a volume of 1.0 at a distnace of n. */
	float getVolumeAtPosition(Vec3f position)
	{	if (timer.paused())
			return 0;
		
		float dist = getAbsolutePosition().distance(position);
		if (radius/dist<256) // TODO: implement min/max volume.
			return radius / dist;
		else return 256;
	}
	unittest
	{	
		auto s = new SoundNode();
		s.setPosition(Vec3f(2, 1, 0));
		s.setSoundRadius(12);
		s.play(); // otherwise the function will always return 0.
		assert(s.getVolumeAtPosition(Vec3f(2,  7, 0)) == 2.0f); // distance of 6
		assert(s.getVolumeAtPosition(Vec3f(2, 13, 0)) == 1.0f); // distance of 12
		assert(s.getVolumeAtPosition(Vec3f(2, 25, 0)) == 0.5f); // distance of 24
	}

	/**
	 * Get / set whether the playback of the SoundNode loops when playback is finished. */ 
	bool getLooping()
	{	return looping;
	}
	void setLooping(bool looping=true) /// ditto
	{	this.looping = looping;
	}

	/// Begin / resume playback of the sound at the last position.
	void play()
	{	timer.play();
	}
	
	/// Pause playback of the sound.
	void pause()
	{	timer.pause();
	}

	/// Is the sound currently paused (or stopped?)
	bool paused()
	{	return timer.paused();
	}
	
	/** 
	 * Seek to the position in the track.  Seek has a precision of .05 seconds. */
	void seek(double seconds)
	{	timer.seek(seconds);
		reseek=true;
	}

	/// Tell the position of the playback of the current sound file, in seconds.
	double tell()
	{	real time = timer.tell();
		real length = sound.getLength();
		if (!looping && time > length)
		{	timer.pause();
			timer.seek(length);
			return length;			
		}		
		return fmod(time, length);
	}

	/// Stop the SoundNode from playing and rewind it to the beginning.
	void stop()
	{	timer.stop();
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
		delete pad;

		if (recurse)
		{	indent++;
			foreach (Node c; children)
				result ~= c.toString();
			indent--;
		}

		return result;
	}
	
	/*
	 * Stop playing the sound when
	 * This should be protected, but making it anything but public causes it not to be called.
	 * Most likely a D bug. */
	override void ancestorChange(Node old_ancestor)
	{	Scene old_scene = old_ancestor ? old_ancestor.scene : null;
		super.ancestorChange(old_ancestor); // must be called first so scene is set.
		
		// Update scene's list of sounds
		if (old_scene && old_scene !is scene)
			old_scene.removeSound(this);
		if (scene && scene !is old_scene)
			scene.addSound(this);
	}
}