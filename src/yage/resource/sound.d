/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.sound;

import tango.io.device.FileMap; // TODO REMOVE THIS FROM WAVEFILE
//import tango.io.device.File;
//import tango.stdc.stdio : FILE, fopen;
import std.stdio;
import tango.text.convert.Format;
import tango.stdc.stringz;
import derelict.openal.al;
import derelict.vorbis.vorbis;
import derelict.vorbis.enc;
import derelict.vorbis.file;
import yage.core.array;
import yage.core.timer;
import yage.core.object2;
import yage.core.math.vector;
import yage.resource.manager;
import yage.system.log;
import yage.system.sound.all;

import yage.scene.sound;


/** 
 * A Sound is a represenation of sound data in system memory.
 * Sounds use a SoundFile as a member variable, which abstracts away the differences between different sound formats.
 * During initialization, a Sound loads the sound data from a file and
 * passes it on to OpenAL for playback, as it's needed. */
class Sound
{	
	protected ubyte		format;  		// wav, ogg, etc.
	protected SoundFile	sound_file;		// see doc for SoundFile
	protected uint		al_format;		// Number of channels and uncompressed bit-rate.
	
	protected uint[]	buffers;		// holds the OpenAL id name of each buffer for the song
	protected uint[]	buffers_ref;	// counts how many SoundNodes are using each buffer
	protected uint		buffer_num;		// total number of buffers
	protected uint		buffer_size;	// size of each buffer in bytes, always a multiple of 4.
	protected uint		buffers_per_sec = 25;// ideal is between 5 and 500.  Higher values give more seek precision.
									// but limit the number of sounds that can be playing concurrently.

	/** 
	 * Load a sound from a file.
	 * Note that the file is not closed until the destructor is called.
	 * Params: source=Filename of the sound to load.*/
	this(string filename)
	{
		string source = ResourceManager.resolvePath(filename);
		
		if (filename[$-4..$] == ".wav") {
		        sound_file = new WaveFile(source);
		} else if (filename[$-4..$] == ".ogg") {
                        sound_file = new VorbisFile(source);
                } else throw new ResourceException("Unrecognized sound format '"~filename~"' for file '"~source~"'.");

		// Determine OpenAL format
		if (sound_file.channels==1 && sound_file.bits==8)  		al_format = AL_FORMAT_MONO8;
		else if (sound_file.channels==1 && sound_file.bits==16) al_format = AL_FORMAT_MONO16;
		else if (sound_file.channels==2 && sound_file.bits==8)  al_format = AL_FORMAT_STEREO8;
		else if (sound_file.channels==2 && sound_file.bits==16) al_format = AL_FORMAT_STEREO16;
		else throw new ResourceException("Sound must be 8 or 16 bit and mono or stero format.");

		// Calculate the parameters for our buffers
		int one_second_size = (sound_file.bits/8)*sound_file.frequency*sound_file.channels;
		float seconds = sound_file.size/cast(double)one_second_size;
		buffer_num = cast(int)(seconds*buffers_per_sec);
		buffer_size= one_second_size/buffers_per_sec;
		int sample_size = sound_file.channels*sound_file.bits/8;
		buffer_size = (buffer_size/sample_size)*sample_size;	// ensure a multiple of our sample size
		buffers.length = buffers_ref.length = buffer_num;	// allocate empty buffers
	}

	/// Release sound buffers.
	~this()
	{	dispose();
	}	
	
	void dispose() /// ditto
	{	freeBuffers(0, buffer_num);	// ensure every buffer is released
		buffer_num = 0;
		delete sound_file;
	}

	/// Get the frequency of the sound (often 22050 or 44100)
	uint getFrequency()
	{	return sound_file.frequency;
	}

	/** 
	 * Get a pointer to the array of OpenAL buffer id's used for this sound.
	 * allocBuffers() and freeBuffers() are used to assign and release buffers from the sound source.*/
	uint[] getBuffers()
	{	return buffers;
	}

	/// Get the number of buffers this sound was divided into
	ulong getBuffersLength()
	{	return buffers.length;
	}

	/// Get the number of buffers created for each second of this sound
	uint getBuffersPerSecond()
	{	return buffers_per_sec;
	}

	/// Get the length of the sound in seconds
	double getLength()
	{	return (8.0*sound_file.size)/(sound_file.bits*sound_file.frequency*sound_file.channels);
	}

	/// Return the size of the uncompressed sound data, in bytes.
	uint getSize()
	{	return sound_file.size;
	}

	/// Get the filename this Sound was loaded from.
	string getSource()
	{	return sound_file.source;
	}

	/// TODO: convert last to be number, to be consistent with alloBuffers and FreeBuffers?
	uint[] getBuffers(ulong first, ulong last)
	{	first = first % buffers.length;
		last = last % buffers.length;
		
		// If we're wrapping around
		if (first > last)
			return buffers[first..buffers.length]~buffers[0..last];
		else
			return buffers[first..last];
	}

	/** 
	 * Create openAL buffers in the buffers array for the given range.
	 * As sounds request buffers, a reference counters are incremented/decremented for each buffer, 
	 * and the openAL buffers are destroyed when the reference counter reaches zero. 
	 * This can accept buffers outside of the range of buffers and will wrap them around to support easy looping. */
	void allocBuffers(ulong first, ulong number)
	{	// Loop through each of the buffers that will be returned
		for (ulong j=first; j<first+number; j++)
		{	// Allow inputs that are out of range to loop around
			ulong i = j % buffers.length;

			// If this buffer hasn't yet been bound
			if (buffers_ref[i]==0)
			{	
				//synchronized(ALContext.getMutex())
				{	OpenAL.genBuffers(1, &buffers[i]);
					ubyte[] data = sound_file.getBuffer(i*buffer_size, buffer_size);
					OpenAL.bufferData(buffers[i], al_format, &data[0], cast(ALsizei)data.length, getFrequency());
				}
			}
			// Increment reference count
			buffers_ref[i]++;
		}
	}

	/**
	 * Mark the range of buffers for freeing.
	 * This will decrement the reference count for each of the buffers
	 * and will release it once it's at zero. */
	void freeBuffers(ulong first, int number)
	{	
		for (ulong j=first; j<first+number; j++)
		{	// Allow inputs that are out of range to loop around
			ulong i = j % buffers.length;

			// Decrement reference count
			if (buffers_ref[i]==0)
				continue;
			buffers_ref[i]--;

			// If this buffer has no references to it, delete it
			if (buffers_ref[i]==0)
			{	
				synchronized(OpenAL.getMutex())
					if (OpenAL.isBuffer(buffers[i]))
					{	OpenAL.deleteBuffers(1, &buffers[i]); /// TODO, delete multiple buffers at once?
						if (OpenAL.isBuffer(buffers[i]))
							throw new ResourceException(
								"OpenAL Sound buffer %d of '%s' could not be deleted; probably because it is in use.\n", 
								i, sound_file.source);
					} else
						throw new ResourceException( // this should never happen.
							"OpenAL Sound buffer %d of '%s' cannot be deleted because it is has not been allocated.\n", 
							i, sound_file.source);
		}	}
	}

	/// Print useful information about the loaded sound file.
	override string toString()
	{	return std.string.format("size of buffer: %l bytes\nsize of buffer: %l bytes\nbuffers per second: %l bytes\n", 
			buffer_size, buffer_num, buffers_per_sec
		);
	}
}

/** SoundFile is an abstract class for loading and seeking
 *  sound data in a multimedia file.  A file is opened and closed
 *  in its constructor / destructor and getBuffer() can be used for fetching any data.
 *  To add support for a new sound file format, create a class
 *  that inherits from SoundFile and override its methods. */
private abstract class SoundFile
{
	ushort	channels;
	int		frequency;	// 22050hz, 44100hz?
	int		bits;		// 8bit, 16bit?
	int		size;		// in bytes
	string	source;
	string[]comments;	// Header info from audio file (not used yet)

	/// Load the given file and parse its headers
	this(string filename)
	{	source = filename;
		Log.info("Loading sound '" ~ source ~ "'.");
	}

	/** Return a buffer of uncompressed sound data.
	 *  Both parameters are measured in bytes. */
	ubyte[] getBuffer(ulong offset, uint size)
	{	return null;
	}

	/// Print useful information about the loaded sound file.
	override string toString()
	{	return  std.string.format("Sound: '%s'\n"~
			                  "channels: %d\n"~
			                  "sample rate: %d\n"~
			                  "sample bits: %d\n"~
			                  "sample length: %d bytes\n"~
			                  "sample length: %f seconds\n",
			                  source, channels, frequency, bits, size,
			                  (8.0*size)/(bits*frequency*channels));
	}
}


/// A Wave implementation of SoundFile
private class WaveFile : SoundFile
{
	MappedFile file;

	/// Open a wave file and store attributes from its headers
	this(string filename)
	{	super(filename);
		file = new MappedFile(filename);

		// First 4 bytes of Wave file should be "RIFF"
		if (cast(string)file.map[0..4] != "RIFF")
			throw new ResourceException("'"~filename~"' is not a RIFF file.");
		// Skip size value (4 bytes)
		if (cast(string)file.map[8..12] != "WAVE")
			throw new ResourceException("'"~filename~"' is not a WAVE file.");
		// Skip "fmt ", format length, format tag (10 bytes)
		channels 	= (cast(ushort[])file.map[22..24])[0];
		frequency	= (cast(uint[])file.map[24..28])[0];
		// Skip average bytes per second, block align, bytes by capture (6 bytes)
		bits		= (cast(ushort[])file.map[34..36])[0];
		// Skip 'data' (4 bytes)
		size		= (cast(uint[])file.map[40..44])[0];
	}

	/// Free the file we loaded
	~this()
	{	delete file;
	}

	/** Return a buffer of uncompressed sound data.
	 *  Both parameters are measured in bytes. */
	override ubyte[] getBuffer(ulong offset, uint _size)
	{	if (offset+_size > size)
			return null;
		return cast(ubyte[])file.map[(44+offset)..(44+offset+_size)];
	}

}

/// An Ogg Vorbis implementation of SoundFile
private class VorbisFile : SoundFile
{
	OggVorbis_File vf;		// struct for our open ov file.

	int current_section;	// used interally by ogg vorbis
	File file;
	ubyte[] buffer;			// used for returning data

	/// Open an ogg vorbis file and store attributes from its headers
	this(string filename)
	{	super(filename);

		// Open the file
		file = File(filename, "rb");
		int status = ov_open(file.getFP(), &vf, null, 0);

		version(linux){}
		else  // this returns false errors on linux?
		{	if(status < 0)
				throw new ResourceException("'"~filename~"' is not an ogg vorbis file.\n");
		}
		vorbis_info *vi = ov_info(&vf, -1);

		// Get relevant data from the file
		channels = cast(ushort) vi.channels;
		frequency = vi.rate;
		bits = 16;	// always 16-bit for ov?
		size = cast(int) ov_pcm_total(&vf, -1)*(bits/8)*channels;
	}

	/// Free memory and close file
	~this()
	{	// Closing the file is not necessary since ov_clear closes it automatially.
		ov_clear(&vf);
	}

	/** Return a buffer of uncompressed sound data.
	 *  Both parameters are measured in bytes. */
	override ubyte[] getBuffer(ulong offset, uint _size)
	{	if (offset+_size > size)
			return null;
		ov_pcm_seek(&vf, offset/(bits/8)/channels);
		buffer.length = _size;
		int ret = 0;
		while (ret<_size)	// because it may take several requests to fill our buffer
			ret += ov_read(&vf, cast(byte*)buffer[ret..buffer.length], _size-ret, 0, 2, 1, &current_section);
		return buffer;
	}
}

// ----------


// Copies of SoundNode properties to provide lock-free access.
struct SoundCommand
{	Sound sound;
	Vec3f worldPosition;
	Vec3f worldVelocity;
	float pitch;
	float volume;
	float radius;
	float intensity; // used internally for sorting
	float position; // playback position
	size_t id;
	SoundNode soundNode; // original SoundNode.  Must be used behind lock!
	bool looping;
	bool reseek;
}

/**
 * Struct to send to the sound engine for processing. */
struct SoundList
{	ArrayBuilder!(SoundCommand) commands;
	long timestamp;
	Vec3f cameraPosition;
	Vec3f cameraRotation;
	Vec3f cameraVelocity;
}