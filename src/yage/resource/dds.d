//---------------------------------------------------------------------
/*
 luigi/themes/dxut.d -- A clone of the DXUT texture-based theme.

 Copyright (C) 2006 William V. Baxter III

 This software is provided 'as-is', without any express or implied
 warranty.  In no event will the authors be held liable for any
 damages arising from the use of this software.

 Permission is granted to anyone to use this software for any
 purpose, including commercial applications, and to alter it and
 redistribute it freely, subject to the following restrictions:

 1. The origin of this software must not be misrepresented; you must
 not claim that you wrote the original software. If you use this
 software in a product, an acknowledgment in the product
 documentation would be appreciated but is not required.
 2. Altered source versions must be plainly marked as such, and must
 not be misrepresented as being the original software.
 3. This notice may not be removed or altered from any source distribution.

 William Baxter wbaxter@gmail.com
 
 Modified by Eric Poggel for use in Yage (the license above is the zlib/libpng license).
 */
module yage.resource.dds;


import tango.stdc.stdio;
import tango.stdc.string;
import core.bitop;
import tango.stdc.stringz;

import derelict.opengl3.gl3;
// TODO Older declarations that I'm still looking into
/*import derelict.gl3;
import derelict.gl3.extension.arb.texture_compression;
import derelict.gl3.extension.ext.texture_compression_dxt1;
import derelict.gl3.extension.ext.texture_compression_s3tc;*/

import yage.core.format;
import yage.core.object2;
import yage.system.log;

//============================================================================
//DDS TEXTURE UTILITIES

//Struct & defines modified from directx sdk's ddraw.h
const uint DDS_CAPS = 0x00000001L;
const uint DDS_HEIGHT = 0x00000002L;
const uint DDS_WIDTH = 0x00000004L;
const uint DDS_RGB = 0x00000040L;
const uint DDS_PIXELFORMAT = 0x00001000L;
const uint DDS_LUMINANCE = 0x00020000L;
const uint DDS_ALPHAPIXELS = 0x00000001L;
const uint DDS_ALPHA = 0x00000002L;
const uint DDS_FOURCC = 0x00000004L;
const uint DDS_PITCH = 0x00000008L;
const uint DDS_COMPLEX = 0x00000008L;
const uint DDS_TEXTURE = 0x00001000L;
const uint DDS_MIPMAPCOUNT = 0x00020000L;
const uint DDS_LINEARSIZE = 0x00080000L;
const uint DDS_VOLUME = 0x00200000L;
const uint DDS_MIPMAP = 0x00400000L;
const uint DDS_DEPTH = 0x00800000L;
const uint DDS_CUBEMAP = 0x00000200L;
const uint DDS_CUBEMAP_POSITIVEX = 0x00000400L;
const uint DDS_CUBEMAP_NEGATIVEX = 0x00000800L;
const uint DDS_CUBEMAP_POSITIVEY = 0x00001000L;
const uint DDS_CUBEMAP_NEGATIVEY = 0x00002000L;
const uint DDS_CUBEMAP_POSITIVEZ = 0x00004000L;
const uint DDS_CUBEMAP_NEGATIVEZ = 0x00008000L;

align(1)
	struct DDSInfo {
		uint size; // size of the structure
		uint flags; // determines what fields are valid
		uint height; // height of surface to be created
		uint width; // width of input surface
		uint linearSize; // Formless late-allocated optimized surface size
		uint depth; // Depth for volume textures
		uint mipMapCount; // number of mip-map levels requested
		uint alphaBitDepth; // depth of alpha buffer requested
		uint[10] unused;
		uint pixFmtSize; // size of pixelformat structure
		uint pixFmtFlags; // pixel format flags
		char[4] fourCC; // (FOURCC code)
		uint RGBBitCount; // how many bits per pixel
		uint RBitMask; // mask for red bit
		uint GBitMask; // mask for green bits
		uint BBitMask; // mask for blue bits
		uint RGBAlphaBitMask; // mask for alpha channel
		uint caps; // capabilities of surface wanted
		uint caps2;
		uint caps3;
		uint caps4;
		uint textureStage; // stage in multitexture cascade
	}

///
struct DDSImageData {
	int width;
	int height;
	ubyte components;
	uint format;
	int numMipMaps;
	ubyte[] pixels;

	string toString() {
		return yage.core.format.format("{
			 width = %s;
			 height = %s;
			 components = %s;
			 format = %s;
			 numMipMaps = %s;
			 pixels.sizeof = %s;
			}",
			width, height, components, format, numMipMaps, pixels.length);
	}
}

/**
 * Load the contents of a DDS file into the DDSImageData struct.
 * Currently, only DXT1, DXT3, and DXT5 are supported. */
DDSImageData* loadDDSTextureFile(ubyte[] fileContents) {
	uint bswapLE(inout uint v) {
		version(BigEndian)
			v = bswap(v);
		return v;
	}
	int factor;
	int bufferSize;
	
	// Verify the file is a true .dds file
	if(cast(string)fileContents[0..4] != "DDS ") 
		throw new ResourceException("The file doesn't appear to be a valid .dds file!");
	
	// Get the surface descriptor
	DDSInfo ddsinfo;
	memcpy(&ddsinfo, fileContents[4..$].ptr, ddsinfo.sizeof); // TODO: size check
	int nread = ddsinfo.sizeof;
	bswapLE(ddsinfo.size);
	
	auto pDDSdata = new DDSImageData;
	
	// This .dds loader supports the loading of compressed formats DXT1, DXT3 
	// and DXT5.
	
	bswapLE(ddsinfo.width);
	bswapLE(ddsinfo.height);
	bswapLE(ddsinfo.depth);
	if(ddsinfo.depth == 0)
		ddsinfo.depth = 1;
	uint block_size = ((ddsinfo.width + 3) / 4) * ((ddsinfo.height + 3) / 4) * ddsinfo.depth;
	switch(ddsinfo.fourCC) {
		case "DXT1":
			pDDSdata.format = GL_COMPRESSED_RGBA_S3TC_DXT1_EXT;
			factor = 2;
			block_size *= 8;
			break;
			/*
			 case "DXT2":
			 pDDSdata.format = GL_COMPRESSED_RGBA_S3TC_DXT2_EXT;
			 factor = 4;
			 block_size *= 16;
			 break;
			 */
		case "DXT3":
			pDDSdata.format = GL_COMPRESSED_RGBA_S3TC_DXT3_EXT;
			factor = 4;
			block_size *= 16;
			break;
			/*
			 case "DXT4":
			 pDDSdata.format = GL_COMPRESSED_RGBA_S3TC_DXT4_EXT;
			 factor = 4;
			 block_size *= 16;
			 break;
			 */
		case "DXT5":
			pDDSdata.format = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
			factor = 4;
			block_size *= 16;
			break;
		default:
			throw new ResourceException("Cannot parse DXT texture since it's not DXT1, DXT3, or DXT5.");
	}
	//
	// How big will the buffer need to be to load all of the pixel data 
	// including mip-maps?
	bswapLE(ddsinfo.flags);
	bswapLE(ddsinfo.linearSize);
	bswapLE(ddsinfo.mipMapCount);
	if(!(ddsinfo.flags & (DDS_LINEARSIZE | DDS_PITCH)) || ddsinfo.linearSize == 0) {
		ddsinfo.flags |= DDS_LINEARSIZE;
		ddsinfo.linearSize = block_size;
	}
	if(ddsinfo.linearSize == 0) {
		throw new ResourceException("linearSize is 0!");
	}
	if(ddsinfo.mipMapCount > 1)
		bufferSize = ddsinfo.linearSize * factor;
	else
		bufferSize = ddsinfo.linearSize;
	pDDSdata.pixels.length = bufferSize;
	
	// Ensure we don't memcpy past the end of the file
	// This is very hackish but somehow it still makes DXT5 textures work when they otherwise fail.
	fileContents = fileContents[4+ddsinfo.sizeof..$];
	if (bufferSize > fileContents.length)
		bufferSize = fileContents.length;
	
	memcpy(pDDSdata.pixels.ptr, fileContents.ptr, bufferSize);	
	
	// need to do an endian swap on pixels for big-endian systems?
	pDDSdata.width = ddsinfo.width;
	pDDSdata.height = ddsinfo.height;
	pDDSdata.numMipMaps = ddsinfo.mipMapCount;
	if(pDDSdata.numMipMaps == 0)
		pDDSdata.numMipMaps = 1;
	if(ddsinfo.fourCC == "DXT1")
		pDDSdata.components = 3;
	else
		pDDSdata.components = 4;
	return pDDSdata;
}