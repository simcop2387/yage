/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.sound;

import std.mmfile;
import std.c.time;
import std.c.stdio;
import std.string;
import derelict.openal.al;
import derelict.ogg.vorbistypes;
import derelict.ogg.vorbisfile;
import yage.core.timer;
import yage.resource.resource;
import yage.system.log;


/** A Sound is a represenation of sound data in system memory.
 *  Sounds use a SoundFile as a member variable, which abstracts away
 *  the differences between different sound formats.
 *  During initialization, a Sound loads the sound data from a file and
 *  passes it on to OpenAL for playback, as it's needed. */
class Sound
{	protected:

	ubyte		format;  		// wav, ogg, etc.
	SoundFile	sound_file;		// see doc for SoundFile
	uint		al_format;		// Number of channels and uncompressed bool-rate.

	uint[]		buffers;		// holds the OpenAL id name of each buffer for the song
	uint[]		buffers_ref;	// counts how many SoundNodes are using each buffer
	uint		buffer_num;		// total number of buffers
	uint		buffer_size;	// size of each buffer in bytes, always a multiple of 4.
	uint		buffers_per_sec = 25;// ideal is between 5 and 500.  Higher values give more seek precision.
									// but limit the number of sounds that can be playing concurrently.

	public:

	/** Load a sound from a file.
	 *  Note that the file is not closed until the destructor is called.
	 *  \param source Filename of the sound to load.*/
	this(char[] filename)
	{
		char[] source = Resource.resolvePath(filename);

		// Get first four bytes of sound file to determine type
		// And then load the file.  sound_file will have all of our important info
		MmFile file = new MmFile(source);
		if (file[0..4]=="RIFF")
			sound_file = new WaveFile(source);
		else if (file[0..4]=="OggS")
			sound_file = new VorbisFile(source);
		else throw new Exception("Unrecognized sound format '"~cast(char[])file[0..4]~"' for file '"~source~"'.");
		delete file;

		// Determine OpenAL format
		if (sound_file.channels==1 && sound_file.bools==8)  		al_format = AL_FORMAT_MONO8;
		else if (sound_file.channels==1 && sound_file.bools==16) al_format = AL_FORMAT_MONO16;
		else if (sound_file.channels==2 && sound_file.bools==8)  al_format = AL_FORMAT_STEREO8;
		else if (sound_file.channels==2 && sound_file.bools==16) al_format = AL_FORMAT_STEREO16;
		else throw new Exception("Sound must be 8 or 16 bool and mono or stero format.");

		// Calculate the parameters for our buffers
		int one_second_size = (sound_file.bools/8)*sound_file.frequency*sound_file.channels;
		float seconds = sound_file.size/cast(double)one_second_size;
		buffer_num = cast(int)(seconds*buffers_per_sec);
		buffer_size= one_second_size/buffers_per_sec;
		int sample_size = sound_file.channels*sound_file.bools/8;
		buffer_size = (buffer_size/sample_size)*sample_size;	// ensure a multiple of our sample size
		buffers.length = buffers_ref.length = buffer_num;	// allocate empty buffers
	}

	/// Tell OpenAL to release the sound, close the file, and delete associated memory.
	~this()
	{	freeBuffers(0, buffer_num);	// ensure every buffer is released
		delete sound_file;
	}

	/// Get the frequency of the sound (often 22050 or 44100)
	uint getFrequency()
	{	return sound_file.frequency;
	}

	/** Get a pointer to the array of OpenAL buffer id's used for this sound.
	 *  allocBuffers() and freeBuffers() are used to assign and release buffers from the sound source.*/
	uint[] getBuffers()
	{	return buffers;
	}

	/// Get the number of buffers this sound was divided into
	uint getBuffersLength()
	{	return buffers.length;
	}

	/// Get the number of buffers created for each second of this sound
	uint getBuffersPerSecond()
	{	return buffers_per_sec;
	}

	/// Get the length of the sound in seconds
	double getLength()
	{	return (8.0*sound_file.size)/(sound_file.bools*sound_file.frequency*sound_file.channels);
	}

	/// Return the size of the uncompressed sound data, in bytes.
	uint getSize()
	{	return sound_file.size;
	}

	/// Get the filename this Sound was loaded from.
	char[] getSource()
	{	return sound_file.source;
	}

	///
	uint[] getBuffers(int first, int last)
	{	first = first % buffers.length;
		last = last % buffers.length;

		// If we're wrapping around
		if (first > last)
			return buffers[first..length]~buffers[0..last];
		else
			return buffers[first..last];
	}

	/** Return an array of OpenAL Buffers starting at first.
	 *  This can accept buffers outside of the range of buffers and
	 *  will wrap them around to support easy looping. */
	void allocBuffers(int first, int number)
	{	// Loop through each of the buffers that will be returned
		for (int j=first; j<first+number; j++)
		{	// Allow inputs that are out of range to loop around
			int i = j % buffers.length;

			// If this buffer hasn't yet been bound
			if (buffers_ref[i]==0)
			{	// Generate a buffer
				alGenBuffers(1, &buffers[i]);
				//printf("Newly generated buffer %d is %d\n", i, buffers[i]);
				ubyte[] data = sound_file.getBuffer(i*buffer_size, buffer_size);
				alBufferData(buffers[i], al_format, &data[0], cast(ALsizei)data.length, getFrequency());
			}
			// Increment reference count
			buffers_ref[i]++;
		}
	}

	/** Mark the range of buffers for freeing.
	 *  This will decrement the reference count for each of the buffers
	 *  and will release it once it's at zero. */
	void freeBuffers(int first, int number)
	{	for (int j=first; j<first+number; j++)
		{	// Allow inputs that are out of range to loop around
			int i = j % buffers.length;

			// Decrement reference count
			if (buffers_ref[i]==0)
				continue;
			buffers_ref[i]--;

			// If this buffer has no references to it, delete it
			if (buffers_ref[i]==0)
			{	alDeleteBuffers(1, &buffers[i]);
				if (alIsBuffer(buffers[i]))
					throw new Exception("Sound buffer "~.toString(i)~" of '"~sound_file.source~
										"' could not be deleted; probably because it is in use.\n");
		}	}
	}

	/// Print useful information about the loaded sound file.
	void print()
	{	sound_file.print();
		printf("size of buffer: %d bytes\n", buffer_size);
		printf("number of buffers: %d bytes\n", buffer_num);
		printf("buffers per second: %d bytes\n", buffers_per_sec);
	}
}



/** SoundFile is an abstract class for loading and seeking
 *  sound data in a multimedia file.  A file is opened and closed
 *  in its constructor / destructor and getBuffer() can be used for fetching any data.
 *  To add support for a new sound file format, create a class
 *  that inherits from SoundFile and override its methods. */
private abstract class SoundFile
{
	ubyte	channels;
	int		frequency;	// 22050hz, 44100hz?
	int		bools;		// 8bool, 16bool?
	int		size;		// in bytes
	char[]	source;
	char[][]comments;	// Header info from audio file (not used yet)

	/// Load the given file and parse its headers
	this(char[] filename)
	{	source = filename;
		Log.write("Loading sound '" ~ source ~ "'.");
	}

	/** Return a buffer of uncompressed sound data.
	 *  Both parameters are measured in bytes. */
	ubyte[] getBuffer(int offset, int size)
	{	return null;
	}

	/// Print useful information about the loaded sound file.
	void print()
	{	printf("Sound: '%.*s'\n", source);
		printf("channels: %d\n", channels);
		printf("sample rate: %dhz\n", frequency);
		printf("sample bools: %d\n", bools);
		printf("sample length: %d bytes\n", size);
		printf("sample length: %f seconds\n", (8.0*size)/(bools*frequency*channels));
	}
}


/// A Wave implementation of SoundFile
private class WaveFile : SoundFile
{
	MmFile	file;

	/// Open a wave file and store attributes from its headers
	this(char[] filename)
	{	super(filename);
		file = new MmFile(filename);

		// First 4 bytes of Wave file should be "RIFF"
		if (file[0..4] != "RIFF")
			throw new Exception("'"~filename~"' is not a RIFF file.");
		// Skip size value (4 bytes)
		if (file[8..12] != "WAVE")
			throw new Exception("'"~filename~"' is not a WAVE file.");
		// Skip "fmt ", format length, format tag (10 bytes)
		channels 	= (cast(ushort[])file[22..24])[0];
		frequency	= (cast(uint[])file[24..28])[0];
		// Skip average bytes per second, block align, bytes by capture (6 bytes)
		bools		= (cast(ushort[])file[34..36])[0];
		// Skip 'data' (4 bytes)
		size		= (cast(uint[])file[40..44])[0];
	}

	/// Free the file we loaded
	~this()
	{	delete file;
	}

	/** Return a buffer of uncompressed sound data.
	 *  Both parameters are measured in bytes. */
	ubyte[] getBuffer(int offset, int _size)
	{	if (offset+_size > size)
			return null;
		return cast(ubyte[])file[(44+offset)..(44+offset+_size)];
	}

}

/// An Ogg Vorbis implementation of SoundFile
private class VorbisFile : SoundFile
{
	OggVorbis_File vf;		// struct for our open ov file.
	int current_section;	// used interally by ogg vorbis
	FILE *file;
	ubyte[] buffer;			// used for returning data

	/// Open an ogg vorbis file and store attributes from its headers
	this(char[] filename)
	{	super(filename);

		// Open the file
		file = fopen(toStringz(filename), "rb");
		int status = ov_open(file, &vf, null, 0);

		version(linux){}
		else  // this returns false errors on linux?
		{	if(status < 0)
				throw new Exception("'"~filename~"' is not an ogg vorbis file.\n");
		}
		vorbis_info *vi = ov_info(&vf, -1);

		// Get relevant data from the file
		channels = vi.channels;
		frequency = vi.rate;
		bools = 16;	// always 16-bool for ov?
		size = ov_pcm_total(&vf, -1)*(bools/8)*channels;
	}

	/// Free memory and close file
	~this()
	{	ov_clear(&vf);
		fclose(file);
		delete buffer;
	}

	/** Return a buffer of uncompressed sound data.
	 *  Both parameters are measured in bytes. */
	ubyte[] getBuffer(int offset, int _size)
	{	if (offset+_size > size)
			return null;
		ov_pcm_seek(&vf, offset/(bools/8)/channels);
		buffer.length = _size;
		int ret = 0;
		while (ret<_size)	// because it may take several requests to fill our buffer
			ret += ov_read(&vf, cast(byte*)buffer[ret..length], _size-ret, 0, 2, 1, &current_section);
		return buffer;
	}
}





