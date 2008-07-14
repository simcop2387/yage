/*
 * Copyright (c) 2004-2008 Derelict Developers
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
 * * Neither the names 'Derelict', 'DerelictOgg', nor the names of its contributors
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
module derelict.ogg.ogg;

private 
{
	import derelict.util.loader;
	import derelict.ogg.oggtypes;
}

private void loadOgg(SharedLib lib)
{
    // Ogg BITSTREAM PRIMITIVES: bitstream
    bindFunc(oggpack_writeinit)("oggpack_writeinit", lib);
    bindFunc(oggpack_writetrunc)("oggpack_writetrunc", lib);
    bindFunc(oggpack_writealign)("oggpack_writealign", lib);
    bindFunc(oggpack_writecopy)("oggpack_writecopy", lib);
    bindFunc(oggpack_reset)("oggpack_reset", lib);
    bindFunc(oggpack_writeclear)("oggpack_writeclear", lib);
    bindFunc(oggpack_readinit)("oggpack_readinit", lib);
    bindFunc(oggpack_write)("oggpack_write", lib);
    bindFunc(oggpack_look)("oggpack_look", lib);
    bindFunc(oggpack_look1)("oggpack_look1", lib);
    bindFunc(oggpack_adv)("oggpack_adv", lib);
    bindFunc(oggpack_adv1)("oggpack_adv1", lib);
    bindFunc(oggpack_read)("oggpack_read", lib);
    bindFunc(oggpack_read1)("oggpack_read1", lib);
    bindFunc(oggpack_bytes)("oggpack_bytes", lib);
    bindFunc(oggpack_bits)("oggpack_bits", lib);
    bindFunc(oggpack_get_buffer)("oggpack_get_buffer", lib);

    /* These function prototypes appear twice in ogg.h and look exactly the same.  Not sure why.
    bindFunc(oggpack_writeinit)("oggpack_writeinit", lib);
    bindFunc(oggpack_writetrunc)("oggpack_writetrunc", lib);
    bindFunc(oggpack_writealign)("oggpack_writealign", lib);
    bindFunc(oggpack_writecopy)("oggpack_writecopy", lib);
    bindFunc(oggpack_reset)("oggpack_reset", lib);
    bindFunc(oggpack_writeclear)("oggpack_writeclear", lib);
    bindFunc(oggpack_readinit)("oggpack_readinit", lib);
    bindFunc(oggpack_write)("oggpack_write", lib);
    bindFunc(oggpack_look)("oggpack_look", lib);
    bindFunc(oggpack_look1)("oggpack_look1", lib);
    bindFunc(oggpack_adv)("oggpack_adv", lib);
    bindFunc(oggpack_adv1)("oggpack_adv1", lib);
    bindFunc(oggpack_read)("oggpack_read", lib);
    bindFunc(oggpack_read1)("oggpack_read1", lib);
    bindFunc(oggpack_bytes)("oggpack_bytes", lib);
    bindFunc(oggpack_bits)("oggpack_bits", lib);
    bindFunc(oggpack_get_buffer)("oggpack_get_buffer", lib);
    */

    // Ogg BITSTREAM PRIMITIVES: encoding
    bindFunc(ogg_stream_packetin)("ogg_stream_packetin", lib);
    bindFunc(ogg_stream_pageout)("ogg_stream_pageout", lib);
    bindFunc(ogg_stream_flush)("ogg_stream_flush", lib);

    // Ogg BITSTREAM PRIMITIVES: decoding
    bindFunc(ogg_sync_init)("ogg_sync_init", lib);
    bindFunc(ogg_sync_clear)("ogg_sync_clear", lib);
    bindFunc(ogg_sync_reset)("ogg_sync_reset", lib);
    bindFunc(ogg_sync_destroy)("ogg_sync_destroy", lib);

    bindFunc(ogg_sync_buffer)("ogg_sync_buffer", lib);
    bindFunc(ogg_sync_wrote)("ogg_sync_wrote", lib);
    bindFunc(ogg_sync_pageseek)("ogg_sync_pageseek", lib);
    bindFunc(ogg_sync_pageout)("ogg_sync_pageout", lib);
    bindFunc(ogg_stream_pagein)("ogg_stream_pagein", lib);
    bindFunc(ogg_stream_packetout)("ogg_stream_packetout", lib);
    bindFunc(ogg_stream_packetpeek)("ogg_stream_packetpeek", lib);

    // Ogg BITSTREAM PRIMITIVES: general
    bindFunc(ogg_stream_init)("ogg_stream_init", lib);
    bindFunc(ogg_stream_clear)("ogg_stream_clear", lib);
    bindFunc(ogg_stream_reset)("ogg_stream_reset", lib);
    bindFunc(ogg_stream_reset_serialno)("ogg_stream_reset_serialno", lib);
    bindFunc(ogg_stream_destroy)("ogg_stream_destroy", lib);
    bindFunc(ogg_stream_eos)("ogg_stream_eos", lib);

    bindFunc(ogg_page_checksum_set)("ogg_page_checksum_set", lib);

    bindFunc(ogg_page_version)("ogg_page_version", lib);
    bindFunc(ogg_page_continued)("ogg_page_continued", lib);
    bindFunc(ogg_page_bos)("ogg_page_bos", lib);
    bindFunc(ogg_page_eos)("ogg_page_eos", lib);
    bindFunc(ogg_page_granulepos)("ogg_page_granulepos", lib);
    bindFunc(ogg_page_serialno)("ogg_page_serialno", lib);
    bindFunc(ogg_page_pageno)("ogg_page_pageno", lib);
    bindFunc(ogg_page_packets)("ogg_page_packets", lib);

    bindFunc(ogg_packet_clear)("ogg_packet_clear", lib);
}// LoadOgg


GenericLoader DerelictOgg;
static this() {
    DerelictOgg.setup(
        "ogg.dll",
        "libogg.so, libogg.so.0",
        "",
        &loadOgg
    );
}


extern (C)
{
    // Ogg BITSTREAM PRIMITIVES: bitstream
    typedef void function(oggpack_buffer *b) pfoggpack_writeinit;
    typedef void function(oggpack_buffer *b, int  bits) pfoggpack_writetrunc;
    typedef void function(oggpack_buffer *b) pfoggpack_writealign;
    typedef void function(oggpack_buffer *b, void *source, int bits) pfoggpack_writecopy;
    typedef void function(oggpack_buffer *b) pfoggpack_reset;
    typedef void function(oggpack_buffer *b) pfoggpack_writeclear;
    typedef void function(oggpack_buffer *b, ubyte *buf, int bytes) pfoggpack_readinit;
    typedef void function(oggpack_buffer *b, uint value, int bits) pfoggpack_write;
    typedef int  function(oggpack_buffer *b, int bits) pfoggpack_look;
    typedef int  function(oggpack_buffer *b) pfoggpack_look1;
    typedef void function(oggpack_buffer *b, int bits) pfoggpack_adv;
    typedef void function(oggpack_buffer *b) pfoggpack_adv1;
    typedef int  function(oggpack_buffer *b, int bits) pfoggpack_read;
    typedef int  function(oggpack_buffer *b) pfoggpack_read1;
    typedef int  function(oggpack_buffer *b) pfoggpack_bytes;
    typedef int  function(oggpack_buffer *b) pfoggpack_bits;
    typedef ubyte *function(oggpack_buffer *b) pfoggpack_get_buffer;
    pfoggpack_writeinit         oggpack_writeinit;
    pfoggpack_writetrunc        oggpack_writetrunc;
    pfoggpack_writealign        oggpack_writealign;
    pfoggpack_writecopy         oggpack_writecopy;
    pfoggpack_reset             oggpack_reset;
    pfoggpack_writeclear        oggpack_writeclear;
    pfoggpack_readinit          oggpack_readinit;
    pfoggpack_write             oggpack_write;
    pfoggpack_look              oggpack_look;
    pfoggpack_look1             oggpack_look1;
    pfoggpack_adv               oggpack_adv;
    pfoggpack_adv1              oggpack_adv1;
    pfoggpack_read              oggpack_read;
    pfoggpack_read1             oggpack_read1;
    pfoggpack_bytes             oggpack_bytes;
    pfoggpack_bits              oggpack_bits;
    pfoggpack_get_buffer        oggpack_get_buffer;

    // Ogg BITSTREAM PRIMITIVES: encoding
    typedef int     function(ogg_stream_state *os, ogg_packet *op) pfogg_stream_packetin;
    typedef int     function(ogg_stream_state *os, ogg_page *og) pfogg_stream_pageout;
    typedef int     function(ogg_stream_state *os, ogg_page *og) pfogg_stream_flush;
    pfogg_stream_packetin       ogg_stream_packetin;
    pfogg_stream_pageout        ogg_stream_pageout;
    pfogg_stream_flush          ogg_stream_flush;

    // Ogg BITSTREAM PRIMITIVES: decoding
    typedef int     function(ogg_sync_state *oy) pfogg_sync_init;
    typedef int     function(ogg_sync_state *oy) pfogg_sync_clear;
    typedef int     function(ogg_sync_state *oy) pfogg_sync_reset;
    typedef int     function(ogg_sync_state *oy) pfogg_sync_destroy;
    pfogg_sync_init             ogg_sync_init;
    pfogg_sync_clear            ogg_sync_clear;
    pfogg_sync_reset            ogg_sync_reset;
    pfogg_sync_destroy          ogg_sync_destroy;

    typedef byte*   function(ogg_sync_state *oy, int size) pfogg_sync_buffer;
    typedef int     function(ogg_sync_state *oy, int bytes) pfogg_sync_wrote;
    typedef int     function(ogg_sync_state *oy,ogg_page *og) pfogg_sync_pageseek;
    typedef int     function(ogg_sync_state *oy, ogg_page *og) pfogg_sync_pageout;
    typedef int     function(ogg_stream_state *os, ogg_page *og) pfogg_stream_pagein;
    typedef int     function(ogg_stream_state *os,ogg_packet *op) pfogg_stream_packetout;
    typedef int     function(ogg_stream_state *os,ogg_packet *op) pfogg_stream_packetpeek;
    pfogg_sync_buffer           ogg_sync_buffer;
    pfogg_sync_wrote            ogg_sync_wrote;
    pfogg_sync_pageseek         ogg_sync_pageseek;
    pfogg_sync_pageout          ogg_sync_pageout;
    pfogg_stream_pagein         ogg_stream_pagein;
    pfogg_stream_packetout      ogg_stream_packetout;
    pfogg_stream_packetpeek     ogg_stream_packetpeek;

    // Ogg BITSTREAM PRIMITIVES: general
    typedef int     function(ogg_stream_state *os,int serialno) pfogg_stream_init;
    typedef int     function(ogg_stream_state *os) pfogg_stream_clear;
    typedef int     function(ogg_stream_state *os) pfogg_stream_reset;
    typedef int     function(ogg_stream_state *os,int serialno) pfogg_stream_reset_serialno;
    typedef int     function(ogg_stream_state *os) pfogg_stream_destroy;
    typedef int     function(ogg_stream_state *os) pfogg_stream_eos;
    pfogg_stream_init           ogg_stream_init;
    pfogg_stream_clear          ogg_stream_clear;
    pfogg_stream_reset          ogg_stream_reset;
    pfogg_stream_reset_serialno ogg_stream_reset_serialno;
    pfogg_stream_destroy        ogg_stream_destroy;
    pfogg_stream_eos            ogg_stream_eos;

    typedef void    function(ogg_page *og) pfogg_page_checksum_set;
    pfogg_page_checksum_set     ogg_page_checksum_set;

    typedef int     function(ogg_page *og) pfogg_page_version;
    typedef int     function(ogg_page *og) pfogg_page_continued;
    typedef int     function(ogg_page *og) pfogg_page_bos;
    typedef int     function(ogg_page *og) pfogg_page_eos;
    typedef ogg_int64_t function(ogg_page *og) pfogg_page_granulepos;
    typedef int     function(ogg_page *og) pfogg_page_serialno;
    typedef int     function(ogg_page *og) pfogg_page_pageno;
    typedef int     function(ogg_page *og) pfogg_page_packets;
    pfogg_page_version          ogg_page_version;
    pfogg_page_continued        ogg_page_continued;
    pfogg_page_bos              ogg_page_bos;
    pfogg_page_eos              ogg_page_eos;
    pfogg_page_granulepos       ogg_page_granulepos;
    pfogg_page_serialno         ogg_page_serialno;
    pfogg_page_pageno           ogg_page_pageno;
    pfogg_page_packets          ogg_page_packets;

    typedef void    function(ogg_packet *op) pfogg_packet_clear;
    pfogg_packet_clear          ogg_packet_clear;


}   // Extern (C)

































