/*
 * Copyright (c) 2004-2007 Derelict Developers
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 * * Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the distribution.
 *
 * * Neither the names 'Derelict', 'DerelictVorbis', nor the names of its contributors
 *   may be used to endorse or promote products derived from this software
 *   without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
module derelict.ogg.vorbisfile;




//==============================================================================
// Loader
//==============================================================================

private {
    version(Tango)
    {
        import tango.stdc.stdio;
    }
    else
    {
        import std.c.stdio;
    }
    import derelict.util.loader;
    import derelict.ogg.oggtypes;
    import derelict.ogg.vorbistypes;
}


void loadVorbisFile(SharedLib lib)
{

    bindFunc(ov_clear)("ov_clear", lib);
    //bindFunc(ov_open)("ov_open", lib);    // rewritten below because of incompatibility between compilers with FILE struct
    bindFunc(ov_open_callbacks)("ov_open_callbacks", lib);

    bindFunc(ov_test)("ov_test", lib);
    bindFunc(ov_test_callbacks)("ov_test_callbacks", lib);
    bindFunc(ov_test_open)("ov_test_open", lib);

    bindFunc(ov_bitrate)("ov_bitrate", lib);
    bindFunc(ov_bitrate_instant)("ov_bitrate_instant", lib);
    bindFunc(ov_streams)("ov_streams", lib);
    bindFunc(ov_seekable)("ov_seekable", lib);
    bindFunc(ov_serialnumber)("ov_serialnumber", lib);

    bindFunc(ov_raw_total)("ov_raw_total", lib);
    bindFunc(ov_pcm_total)("ov_pcm_total", lib);
    bindFunc(ov_time_total)("ov_time_total", lib);

    bindFunc(ov_raw_seek)("ov_raw_seek", lib);
    bindFunc(ov_pcm_seek)("ov_pcm_seek", lib);
    bindFunc(ov_pcm_seek_page)("ov_pcm_seek_page", lib);
    bindFunc(ov_time_seek)("ov_time_seek", lib);
    bindFunc(ov_time_seek_page)("ov_time_seek_page", lib);

    bindFunc(ov_raw_seek_lap)("ov_raw_seek_lap", lib);
    bindFunc(ov_pcm_seek_lap)("ov_pcm_seek_lap", lib);
    bindFunc(ov_pcm_seek_page_lap)("ov_pcm_seek_page_lap", lib);
    bindFunc(ov_time_seek_lap)("ov_time_seek_lap", lib);
    bindFunc(ov_time_seek_page_lap)("ov_time_seek_page_lap", lib);

    bindFunc(ov_raw_tell)("ov_raw_tell", lib);
    bindFunc(ov_pcm_tell)("ov_pcm_tell", lib);
    bindFunc(ov_time_tell)("ov_time_tell", lib);

    bindFunc(ov_info)("ov_info", lib);
    bindFunc(ov_comment)("ov_comment", lib);

    bindFunc(ov_read_float)("ov_read_float", lib);
    bindFunc(ov_read)("ov_read", lib);
    bindFunc(ov_crosslap)("ov_crosslap", lib);

    bindFunc(ov_halfrate)("ov_halfrate", lib);
    bindFunc(ov_halfrate_p)("ov_halfrate_p", lib);

} // loadVorbisFile()


GenericLoader DerelictVorbisFile;
static this() {
    DerelictVorbisFile.setup(
        "vorbisfile.dll",
        "libvorbisfile.so, libvorbisfile.so.3, libvorbisfile.so.3.1.0",
        "",
        &loadVorbisFile
    );
}


//==============================================================================
// Functions
//==============================================================================
extern (C)
{

    typedef int function(OggVorbis_File *vf) pfov_clear;
    //typedef int function(FILE *f, OggVorbis_File *vf, char *initial, long ibytes) pfov_open;
    typedef int function(void *datasource, OggVorbis_File *vf, char *initial, int  ibytes, ov_callbacks callbacks) pfov_open_callbacks;
    pfov_clear              ov_clear;
    //pfov_open             ov_open; // rewritten below because of incompatibility between compilers with FILE struct
    pfov_open_callbacks     ov_open_callbacks;

    typedef int function(FILE *f,OggVorbis_File *vf, byte *initial, int  ibytes) pfov_test;
    typedef int function(void *datasource, OggVorbis_File *vf, char *initial, int  ibytes, ov_callbacks callbacks) pfov_test_callbacks;
    typedef int function(OggVorbis_File *vf) pfov_test_open;
    pfov_test               ov_test;
    pfov_test_callbacks     ov_test_callbacks;
    pfov_test_open          ov_test_open;

    typedef int function(OggVorbis_File *vf,int i) pfov_bitrate;
    typedef int function(OggVorbis_File *vf) pfov_bitrate_instant;
    typedef int function(OggVorbis_File *vf) pfov_streams;
    typedef int function(OggVorbis_File *vf) pfov_seekable;
    typedef int function(OggVorbis_File *vf,int i) pfov_serialnumber;
    pfov_bitrate            ov_bitrate;
    pfov_bitrate_instant    ov_bitrate_instant;
    pfov_streams            ov_streams;
    pfov_seekable           ov_seekable;
    pfov_serialnumber       ov_serialnumber;

    typedef ogg_int64_t function(OggVorbis_File *vf,int i) pfov_raw_total;
    typedef ogg_int64_t function(OggVorbis_File *vf,int i) pfov_pcm_total;
    typedef double function(OggVorbis_File *vf,int i) pfov_time_total;
    pfov_raw_total          ov_raw_total;
    pfov_pcm_total          ov_pcm_total;
    pfov_time_total         ov_time_total;

    typedef int function(OggVorbis_File *vf,ogg_int64_t pos) pfov_raw_seek;
    typedef int function(OggVorbis_File *vf,ogg_int64_t pos) pfov_pcm_seek;
    typedef int function(OggVorbis_File *vf,ogg_int64_t pos) pfov_pcm_seek_page;
    typedef int function(OggVorbis_File *vf,double pos) pfov_time_seek;
    typedef int function(OggVorbis_File *vf,double pos) pfov_time_seek_page;
    pfov_raw_seek           ov_raw_seek;
    pfov_pcm_seek           ov_pcm_seek;
    pfov_pcm_seek_page      ov_pcm_seek_page;
    pfov_time_seek          ov_time_seek;
    pfov_time_seek_page     ov_time_seek_page;

    typedef int function(OggVorbis_File *vf,ogg_int64_t pos) pfov_raw_seek_lap;
    typedef int function(OggVorbis_File *vf,ogg_int64_t pos) pfov_pcm_seek_lap;
    typedef int function(OggVorbis_File *vf,ogg_int64_t pos) pfov_pcm_seek_page_lap;
    typedef int function(OggVorbis_File *vf,double pos) pfov_time_seek_lap;
    typedef int function(OggVorbis_File *vf,double pos) pfov_time_seek_page_lap;
    pfov_raw_seek_lap       ov_raw_seek_lap;
    pfov_pcm_seek_lap       ov_pcm_seek_lap;
    pfov_pcm_seek_page_lap  ov_pcm_seek_page_lap;
    pfov_time_seek_lap      ov_time_seek_lap;
    pfov_time_seek_page_lap ov_time_seek_page_lap;

    typedef ogg_int64_t function(OggVorbis_File *vf) pfov_raw_tell;
    typedef ogg_int64_t function(OggVorbis_File *vf) pfov_pcm_tell;
    typedef double function(OggVorbis_File *vf) pfov_time_tell;
    pfov_raw_tell           ov_raw_tell;
    pfov_pcm_tell           ov_pcm_tell;
    pfov_time_tell          ov_time_tell;

    typedef vorbis_info* function(OggVorbis_File *vf,int link) pfov_info;
    typedef vorbis_comment* function(OggVorbis_File *vf,int link) pfov_comment;
    pfov_info               ov_info;
    pfov_comment            ov_comment;

    typedef int function(OggVorbis_File *vf, float ***pcm_channels, int samples, int *bitstream) pfov_read_float;
    typedef int function(OggVorbis_File *vf, byte *buffer, int length, int bigendianp, int word, int sgned, int *bitstream) pfov_read;
    typedef int function(OggVorbis_File *vf1,OggVorbis_File *vf2) pfov_crosslap;
    pfov_read_float         ov_read_float;
    pfov_read               ov_read;
    pfov_crosslap           ov_crosslap;

    typedef int function(OggVorbis_File *vf,int flag) pfov_halfrate;
    typedef int function(OggVorbis_File *vf) pfov_halfrate_p;
    pfov_halfrate           ov_halfrate;
    pfov_halfrate_p         ov_halfrate_p;


}   // extern(C)

// ov_open is rewritten below because of incompatibility between compilers with FILE struct
// Using this wrapper, it *should* work exactly as it would in c++. --JoeCoder
private extern (C)
{
    size_t Derelict_VorbisRead(void *ptr, size_t byteSize, size_t sizeToRead, void *datasource)
    {   //printf("VorbisRead(%d, %d, %d, %d)\n", ptr, byteSize, sizeToRead, datasource);
        return fread(ptr, byteSize, sizeToRead, cast(FILE*)datasource);
    }
    int Derelict_VorbisSeek(void *datasource, ogg_int64_t offset, int whence)
    {   //printf("VorbisSeek(%d, %d, %d)\n", datasource, offset, whence);
        return fseek(cast(FILE*)datasource, cast(int)offset, whence);
    }
    int Derelict_VorbisClose(void *datasource)
    {   //printf("VorbisClose(%d)\n", datasource);
        return fclose(cast(FILE*)datasource);
    }
    int Derelict_VorbisTell(void *datasource)
    {   //printf("VorbisTell(%d)\n", datasource);
        return ftell(cast(FILE*)datasource);
    }
}

//===============================================
// ov_open
//===============================================
int ov_open(FILE *f, OggVorbis_File *vf, char *initial, long ibytes)
{
    // Fill the ov_callbacks structure
    ov_callbacks    vorbisCallbacks;    // Structure to hold pointers to callback functions
    vorbisCallbacks.read_func  = &Derelict_VorbisRead;
    vorbisCallbacks.close_func = &Derelict_VorbisClose;
    vorbisCallbacks.seek_func  = &Derelict_VorbisSeek;
    vorbisCallbacks.tell_func  = &Derelict_VorbisTell;

    return ov_open_callbacks(f, vf, initial, cast(int)ibytes, vorbisCallbacks);
}





