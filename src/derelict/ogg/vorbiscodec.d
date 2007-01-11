/*
 * Copyright (c) 2005-2006 Derelict Developers
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
module derelict.ogg.vorbiscodec;

//==============================================================================
// Loader
//==============================================================================
private {
    import derelict.util.loader;
    import derelict.ogg.oggtypes;
	import derelict.ogg.vorbistypes;
}


private void loadVorbis(SharedLib lib)
{
    // Vorbis PRIMITIVES: general
    bindFunc(vorbis_info_init)("vorbis_info_init", lib);
    bindFunc(vorbis_info_clear)("vorbis_info_clear", lib);
    bindFunc(vorbis_info_blocksize)("vorbis_info_blocksize", lib);
    bindFunc(vorbis_comment_init)("vorbis_comment_init", lib);
    bindFunc(vorbis_comment_add)("vorbis_comment_add", lib);
    bindFunc(vorbis_comment_add_tag)("vorbis_comment_add_tag", lib);
    bindFunc(vorbis_comment_query)("vorbis_comment_query", lib);
    bindFunc(vorbis_comment_query_count)("vorbis_comment_query_count", lib);
    bindFunc(vorbis_comment_clear)("vorbis_comment_clear", lib);
    bindFunc(vorbis_block_init)("vorbis_block_init", lib);
    bindFunc(vorbis_block_clear)("vorbis_block_clear", lib);
    bindFunc(vorbis_dsp_clear)("vorbis_dsp_clear", lib);
    bindFunc(vorbis_granule_time)("vorbis_granule_time", lib);

    // Vorbis PRIMITIVES: analysis/DSP layer
    bindFunc(vorbis_analysis_init)("vorbis_analysis_init", lib);
    bindFunc(vorbis_commentheader_out)("vorbis_commentheader_out", lib);
    bindFunc(vorbis_analysis_headerout)("vorbis_analysis_headerout", lib);

    bindFunc(vorbis_analysis_buffer)("vorbis_analysis_buffer", lib);
    bindFunc(vorbis_analysis_wrote)("vorbis_analysis_wrote", lib);
    bindFunc(vorbis_analysis_blockout)("vorbis_analysis_blockout", lib);
    bindFunc(vorbis_analysis)("vorbis_analysis", lib);

    bindFunc(vorbis_bitrate_addblock)("vorbis_bitrate_addblock", lib);
    bindFunc(vorbis_bitrate_flushpacket)("vorbis_bitrate_flushpacket", lib);

    // Vorbis PRIMITIVES: synthesis layer
    bindFunc(vorbis_synthesis_headerin)("vorbis_synthesis_headerin", lib);

    bindFunc(vorbis_synthesis_init)("vorbis_synthesis_init", lib);
    bindFunc(vorbis_synthesis_restart)("vorbis_synthesis_restart", lib);
    bindFunc(vorbis_synthesis)("vorbis_synthesis", lib);
    bindFunc(vorbis_synthesis_trackonly)("vorbis_synthesis_trackonly", lib);
    bindFunc(vorbis_synthesis_blockin)("vorbis_synthesis_blockin", lib);
    bindFunc(vorbis_synthesis_pcmout)("vorbis_synthesis_pcmout", lib);
    bindFunc(vorbis_synthesis_lapout)("vorbis_synthesis_lapout", lib);
    bindFunc(vorbis_synthesis_read)("vorbis_synthesis_read", lib);
    bindFunc(vorbis_packet_blocksize)("vorbis_packet_blocksize", lib);

    bindFunc(vorbis_synthesis_halfrate)("vorbis_synthesis_halfrate", lib);
    bindFunc(vorbis_synthesis_halfrate_p)("vorbis_synthesis_halfrate_p", lib);
} // loadVorbis()


GenericLoader DerelictVorbis;
static this() {
	DerelictVorbis.setup(
		"vorbis.dll",
		"libvorbis.so, libvorbis.so.0, libvorbis.so.0.3.0",
		"",
		&loadVorbis
	);
}


//==============================================================================
// Functions
//==============================================================================

extern (C)
{
    // Vorbis PRIMITIVES: general
    typedef void    function(vorbis_info *vi) pfvorbis_info_init;
    typedef void    function(vorbis_info *vi) pfvorbis_info_clear;
    typedef int     function(vorbis_info *vi,int zo) pfvorbis_info_blocksize;
    typedef void    function(vorbis_comment *vc) pfvorbis_comment_init;
    typedef void    function(vorbis_comment *vc, byte *comment) pfvorbis_comment_add;
    typedef void    function(vorbis_comment *vc, byte *tag, byte *contents) pfvorbis_comment_add_tag;
    typedef byte*   function(vorbis_comment *vc, byte *tag, int count) pfvorbis_comment_query;
    typedef int     function(vorbis_comment *vc, byte *tag) pfvorbis_comment_query_count;
    typedef void    function(vorbis_comment *vc) pfvorbis_comment_clear;

    typedef int     function(vorbis_dsp_state *v, vorbis_block *vb) pfvorbis_block_init;
    typedef int     function(vorbis_block *vb) pfvorbis_block_clear;
    typedef void    function(vorbis_dsp_state *v) pfvorbis_dsp_clear;
    typedef double  function(vorbis_dsp_state *v, ogg_int64_t granulepos) pfvorbis_granule_time;

    pfvorbis_info_init                  vorbis_info_init;
    pfvorbis_info_clear                 vorbis_info_clear;
    pfvorbis_info_blocksize             vorbis_info_blocksize;
    pfvorbis_comment_init               vorbis_comment_init;
    pfvorbis_comment_add                vorbis_comment_add;
    pfvorbis_comment_add_tag            vorbis_comment_add_tag;
    pfvorbis_comment_query              vorbis_comment_query;
    pfvorbis_comment_query_count        vorbis_comment_query_count;
    pfvorbis_comment_clear              vorbis_comment_clear;
    pfvorbis_block_init                 vorbis_block_init;
    pfvorbis_block_clear                vorbis_block_clear;
    pfvorbis_dsp_clear                  vorbis_dsp_clear;
    pfvorbis_granule_time               vorbis_granule_time;

    // Vorbis PRIMITIVES: analysis/DSP layer
    typedef int     function(vorbis_dsp_state *v,vorbis_info *vi) pfvorbis_analysis_init;
    typedef int     function(vorbis_comment *vc, ogg_packet *op) pfvorbis_commentheader_out;
    typedef int     function(vorbis_dsp_state *v, vorbis_comment *vc, ogg_packet *op, ogg_packet *op_comm, ogg_packet *op_code) pfvorbis_analysis_headerout;
    typedef float** function(vorbis_dsp_state *v,int vals) pfvorbis_analysis_buffer;
    typedef int     function(vorbis_dsp_state *v,int vals) pfvorbis_analysis_wrote;
    typedef int     function(vorbis_dsp_state *v,vorbis_block *vb) pfvorbis_analysis_blockout;
    typedef int     function(vorbis_block *vb,ogg_packet *op) pfvorbis_analysis;
    pfvorbis_analysis_init              vorbis_analysis_init;
    pfvorbis_commentheader_out          vorbis_commentheader_out;
    pfvorbis_analysis_headerout         vorbis_analysis_headerout;
    pfvorbis_analysis_buffer            vorbis_analysis_buffer;
    pfvorbis_analysis_wrote             vorbis_analysis_wrote;
    pfvorbis_analysis_blockout          vorbis_analysis_blockout;
    pfvorbis_analysis                   vorbis_analysis;

    typedef int     function(vorbis_block *vb) pfvorbis_bitrate_addblock;
    typedef int     function(vorbis_dsp_state *vd, ogg_packet *op) pfvorbis_bitrate_flushpacket;
    pfvorbis_bitrate_addblock           vorbis_bitrate_addblock;
    pfvorbis_bitrate_flushpacket        vorbis_bitrate_flushpacket;

    // Vorbis PRIMITIVES: synthesis layer
    typedef int    function(vorbis_info *vi,vorbis_comment *vc, ogg_packet *op) pfvorbis_synthesis_headerin;
    pfvorbis_synthesis_headerin         vorbis_synthesis_headerin;

    typedef int     function(vorbis_dsp_state *v,vorbis_info *vi) pfvorbis_synthesis_init;
    typedef int     function(vorbis_dsp_state *v) pfvorbis_synthesis_restart;
    typedef int     function(vorbis_block *vb,ogg_packet *op) pfvorbis_synthesis;
    typedef int     function(vorbis_block *vb,ogg_packet *op) pfvorbis_synthesis_trackonly;
    typedef int     function(vorbis_dsp_state *v,vorbis_block *vb) pfvorbis_synthesis_blockin;
    typedef int     function(vorbis_dsp_state *v,float ***pcm) pfvorbis_synthesis_pcmout;
    typedef int     function(vorbis_dsp_state *v,float ***pcm) pfvorbis_synthesis_lapout;
    typedef int     function(vorbis_dsp_state *v,int samples) pfvorbis_synthesis_read;
    typedef int     function(vorbis_info *vi,ogg_packet *op) pfvorbis_packet_blocksize;
    pfvorbis_synthesis_init             vorbis_synthesis_init;
    pfvorbis_synthesis_restart          vorbis_synthesis_restart;
    pfvorbis_synthesis                  vorbis_synthesis;
    pfvorbis_synthesis_trackonly        vorbis_synthesis_trackonly;
    pfvorbis_synthesis_blockin          vorbis_synthesis_blockin;
    pfvorbis_synthesis_pcmout           vorbis_synthesis_pcmout;
    pfvorbis_synthesis_lapout           vorbis_synthesis_lapout;
    pfvorbis_synthesis_read             vorbis_synthesis_read;
    pfvorbis_packet_blocksize           vorbis_packet_blocksize;

    typedef int     function(vorbis_info *v,int flag) pfvorbis_synthesis_halfrate;
    typedef int     function(vorbis_info *v) pfvorbis_synthesis_halfrate_p;
    pfvorbis_synthesis_halfrate         vorbis_synthesis_halfrate;
    pfvorbis_synthesis_halfrate_p       vorbis_synthesis_halfrate_p;
} // extern(C)









