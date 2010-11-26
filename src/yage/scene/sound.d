/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.sound;

import tango.stdc.math;
import tango.math.Math;
import yage.core.object2;;
import yage.core.object2;;
import yage.core.math.math;
import yage.core.timer;
import yage.core.math.vector;
import yage.resource.manager;
import yage.resource.sound;
import yage.scene.node;
import yage.scene.scene;

/**
 * A node that emits a sound. */ 
class SoundNode : Node, ITemporal
{	
	float pitch = 1.0;		/// The sound pitch.  Less than 1.0 is deeper, greater than 1.0 is higher.
	float radius = 256;		/// The sound radius.  The sound will be 1/2 its volume at this distance.  The volume falls off at a rate of inverse distance squared.
	float volume = 1.0;		///
	bool looping = false;	/// Get / set whether the playback of the sound starts again from the beginning when playback is finished.
	
	protected Timer timer;	
	protected Sound	sound;			// The Sound ResourceManager (file) itself.
	package float intensity;		// used internally for sorting
	package bool reseek = false;	// used internally to tell the sound system to adjust the playback position.
	
	/**
	 * Create a SoundNode and optionally set the sound from an already loaded sound or a sound filename. */
	this()
	{	super();
		timer = new Timer(false);
	}
	this(Node parent)
	{	super(parent);
		timer = new Timer(false);
	}
	this(Sound sound, Node parent=null) /// ditto
	{	this(parent);
		setSound(sound);
	}	
	this(char[] filename, Node parent=null) /// ditto
	{	this(parent);
		setSound(filename);
	}
	
	/**
	 * Make a duplicate of this node, unattached to any parent Node.
	 * Params:
	 *     children = recursively clone children (and descendants) and add them as children to the new Node.
	 * Returns: The cloned Node. */
	/*override*/ SoundNode clone(bool children=false, SoundNode destination=null)
	{	auto result = cast(SoundNode)super.clone(children, destination);
		
		result.setSound(sound);
		result.timer = timer.clone();
		result.pitch = pitch;
		result.radius = radius;
		result.volume = volume;
		result.looping = looping;
		return result;
	}

	/**
	 * Get / set the Sound Resource that this SoundNode will play. */
	Sound getSound()
	{	return sound;
	}	
	void setSound(Sound sound) /// ditto
	{	this.sound = sound;
	}
	void setSound(char[] filename) /// ditto
	{	setSound(ResourceManager.sound(filename));
	}

	/**
	 * Get the volume of this sound as it would be heard at an arbitrary position.
	 * Params:
	 *     position = 3D Coordinates
	 * Returns: The volume at position.  Multiply this by the SoundNode's. */
	float getVolumeAtPosition(Vec3f position)
	{	if (timer.paused())
			return 0;
		
		float dist = getWorldPosition().distance(position);
		float result = radius/dist;
		if (result<256) 
			return result;
		else return 256; // Prevent insanely loud volumes.
	}
	unittest
	{	
		auto s = new SoundNode();
		s.setPosition(Vec3f(2, 1, 0));
		s.radius = 12;
		s.play(); // otherwise the function will always return 0.
		assert(s.getVolumeAtPosition(Vec3f(2,  7, 0)) == 2.0f); // distance of 6
		assert(s.getVolumeAtPosition(Vec3f(2, 13, 0)) == 1.0f); // distance of 12
		assert(s.getVolumeAtPosition(Vec3f(2, 25, 0)) == 0.5f); // distance of 24
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
	
	/*
	 * Stop playing the sound when
	 * This should be protected, but making it anything but public causes it not to be called.
	 * Most likely a D bug. */
	override void ancestorChange(Node old_ancestor)
	{	super.ancestorChange(old_ancestor); // must be called first so scene is set.
		
		// Update scene's list of sounds
		Scene old_scene = old_ancestor ? old_ancestor.getScene() : null;	
		if (old_scene !is scene)
		{	if (old_scene)
				old_scene.removeSound(this);
			if (scene)
				scene.addSound(this);
		}
	}
}