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
module derelict.ogg.vorbistypes;

private
{
    import derelict.ogg.oggtypes;
}

enum
{
    OV_FALSE      = -1,
    OV_EOF        = -2,
    OV_HOLE       = -3,
    OV_EREAD      = -128,
    OV_EFAULT     = -129,
    OV_EIMPL      = -130,
    OV_EINVAL     = -131,
    OV_ENOTVORBIS = -132,
    OV_EBADHEADER = -133,
    OV_EVERSION   = -134,
    OV_ENOTAUDIO  = -135,
    OV_EBADPACKET = -136,
    OV_EBADLINK   = -137,
    OV_ENOSEEK    = -138,
}

struct vorbis_info
{   int _version; // Renamed from "version", since that's a keyword in D
    int channels;
    int rate;
    int bitrate_upper;
    int bitrate_nominal;
    int bitrate_lower;
    int bitrate_window;

    void *codec_setup;
}

struct vorbis_dsp_state
{   int analysisp;
    vorbis_info *vi;

    float **pcm;
    float **pcmret;
    int      pcm_storage;
    int      pcm_current;
    int      pcm_returned;

    int  preextrapolate;
    int  eofflag;

    int  lW;
    int  W;
    int  nW;
    int  centerW;

    ogg_int64_t granulepos;
    ogg_int64_t sequence;

    ogg_int64_t glue_bits;
    ogg_int64_t time_bits;
    ogg_int64_t floor_bits;
    ogg_int64_t res_bits;

    void       *backend_state;
}


struct vorbis_block
{
    float  **pcm;
    oggpack_buffer opb;
    int   lW;
    int   W;
    int   nW;
    int   pcmend;
    int   mode;
    int         eofflag;
    ogg_int64_t granulepos;
    ogg_int64_t sequence;
    vorbis_dsp_state *vd;
    void               *localstore;
    int                 localtop;
    int                 localalloc;
    int                 totaluse;
    alloc_chain *reap;
    int  glue_bits;
    int  time_bits;
    int  floor_bits;
    int  res_bits;

    void *internal;
}

struct alloc_chain
{     void *ptr;
      alloc_chain *next;
}

struct vorbis_comment
{
    char **user_comments;
    int   *comment_lengths;
    int    comments;
    char  *vendor;
}

extern (C)
{
    struct ov_callbacks
    {
        size_t function(void* ptr, size_t size, size_t nmemb, void* datasource ) read_func;
        int function(void* datasource, ogg_int64_t offset, int whence ) seek_func;
        int function(void* datasource ) close_func;
        int function(void* datasource ) tell_func;
    }
}

enum
{
    NOTOPEN   =0,
    PARTOPEN  =1,
    OPENED    =2,
    STREAMSET =3,
    INITSET   =4,
}

struct OggVorbis_File
{   void            *datasource;
    int              seekable;
    ogg_int64_t      offset;
    ogg_int64_t      end;
    ogg_sync_state   oy;
    int              links;
    ogg_int64_t     *offsets;
    ogg_int64_t     *dataoffsets;
    int             *serialnos;
    ogg_int64_t     *pcmlengths;
    vorbis_info     *vi;
    vorbis_comment  *vc;
    ogg_int64_t      pcm_offset;
    int              ready_state;
    int              current_serialno;
    int              current_link;
    double           bittrack;
    double           samptrack;
    ogg_stream_state os;
    vorbis_dsp_state vd;
    vorbis_block     vb;

    ov_callbacks callbacks;
}

int vorbis_encode_init(vorbis_info *vi,
                    int  channels,
                    int  rate,
                    int  max_bitrate,
                    int  nominal_bitrate,
                    int  min_bitrate);

int vorbis_encode_setup_managed(vorbis_info *vi,
                    int  channels,
                    int  rate,
                    int  max_bitrate,
                    int  nominal_bitrate,
                    int  min_bitrate);

int vorbis_encode_setup_vbr(vorbis_info *vi,
                    int channels,
                    int rate,
                    float base_quality
                    );

int vorbis_encode_init_vbr(vorbis_info *vi,
                    int channels,
                    int rate,
                    float base_quality
                    );

int vorbis_encode_setup_init(vorbis_info *vi);
int vorbis_encode_ctl(vorbis_info *vi,int number, void *arg);

// deprecated rate management supported only for compatability
enum
{
    OV_ECTL_RATEMANAGE_GET       =0x10,
    OV_ECTL_RATEMANAGE_SET       =0x11,
    OV_ECTL_RATEMANAGE_AVG       =0x12,
    OV_ECTL_RATEMANAGE_HARD      =0x13,
}

struct ovectl_ratemanage_arg {
    int    management_active;

    int    bitrate_hard_min;
    int    bitrate_hard_max;
    double bitrate_hard_window;

    int    bitrate_av_lo;
    int    bitrate_av_hi;
    double bitrate_av_window;
    double bitrate_av_window_center;
};

// new rate setup
enum
{
    OV_ECTL_RATEMANAGE2_GET      =0x14,
    OV_ECTL_RATEMANAGE2_SET      =0x15,
}

struct ovectl_ratemanage2_arg {
    int    management_active;

    int    bitrate_limit_min_kbps;
    int    bitrate_limit_max_kbps;
    int    bitrate_limit_reservoir_bits;
    double bitrate_limit_reservoir_bias;

    int    bitrate_average_kbps;
    double bitrate_average_damping;
};

enum
{
    OV_ECTL_LOWPASS_GET          =0x20,
    OV_ECTL_LOWPASS_SET          =0x21,
    OV_ECTL_IBLOCK_GET           =0x30,
    OV_ECTL_IBLOCK_SET           =0x31,
}