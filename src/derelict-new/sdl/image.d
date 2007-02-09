/*
 * Copyright (c) 2004-2006 Derelict Developers
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
 * * Neither the names 'Derelict', 'DerelictSDLImage', nor the names of its contributors
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
module derelict.sdl.image;

private
{
    import derelict.sdl.sdl;
    import derelict.util.loader;
}

//==============================================================================
// Types
//==============================================================================
alias SDL_SetError          IMG_SetError;
alias SDL_GetError          IMG_GetError;

const Uint8 SDL_IMAGE_MAJOR_VERSION     = 1;
const Uint8 SDL_IMAGE_MINOR_VERSION     = 2;
const Uint8 SDL_IMAGE_PATCHLEVEL        = 3;

//==============================================================================
// Functions
//==============================================================================
extern(C)
{
typedef SDL_version* function() pfIMG_Linked_Version;
pfIMG_Linked_Version            IMG_Linked_Version;

typedef SDL_Surface* function(SDL_RWops*, int, char*) pfIMG_LoadTyped_RW;
typedef SDL_Surface* function(char*) pfIMG_Load;
typedef SDL_Surface* function(SDL_RWops*, int) pfIMG_Load_RW;
typedef int function(int) pfIMG_InvertAlpha;
pfIMG_LoadTyped_RW              IMG_LoadTyped_RW;
pfIMG_Load                      IMG_Load;
pfIMG_Load_RW                   IMG_Load_RW;
pfIMG_InvertAlpha               IMG_InvertAlpha;

typedef int function(SDL_RWops*) pfIsType;
pfIsType                        IMG_isBMP;
pfIsType                        IMG_isPNM;
pfIsType                        IMG_isXPM;
pfIsType                        IMG_isXCF;
pfIsType                        IMG_isPCX;
pfIsType                        IMG_isGIF;
pfIsType                        IMG_isJPG;
pfIsType                        IMG_isTIF;
pfIsType                        IMG_isPNG;
pfIsType                        IMG_isLBM;

typedef SDL_Surface* function(SDL_RWops*) pfLoadFunc;
pfLoadFunc                      IMG_LoadBMP_RW;
pfLoadFunc                      IMG_LoadPNM_RW;
pfLoadFunc                      IMG_LoadXPM_RW;
pfLoadFunc                      IMG_LoadXCF_RW;
pfLoadFunc                      IMG_LoadPCX_RW;
pfLoadFunc                      IMG_LoadGIF_RW;
pfLoadFunc                      IMG_LoadJPG_RW;
pfLoadFunc                      IMG_LoadTIF_RW;
pfLoadFunc                      IMG_LoadPNG_RW;
pfLoadFunc                      IMG_LoadTGA_RW;
pfLoadFunc                      IMG_LoadLBM_RW;

typedef SDL_Surface* function(char**) pfIMG_ReadXPMFromArray;
pfIMG_ReadXPMFromArray          IMG_ReadXPMFromArray;

}

//==============================================================================
// Macros
//==============================================================================
void SDL_IMAGE_VERSION(SDL_version* X)
{
    X.major     = SDL_IMAGE_MAJOR_VERSION;
    X.minor     = SDL_IMAGE_MINOR_VERSION;
    X.patch     = SDL_IMAGE_PATCHLEVEL;
}

//==============================================================================
// Loader
//==============================================================================

private void load(SharedLib lib)
{
    bindFunc(IMG_Linked_Version)("IMG_Linked_Version", lib);
    bindFunc(IMG_LoadTyped_RW)("IMG_LoadTyped_RW", lib);
    bindFunc(IMG_Load)("IMG_Load", lib);
    bindFunc(IMG_Load_RW)("IMG_Load_RW", lib);
    bindFunc(IMG_InvertAlpha)("IMG_InvertAlpha", lib);
    bindFunc(IMG_isBMP)("IMG_isBMP", lib);
    bindFunc(IMG_isPNM)("IMG_isPNM", lib);
    bindFunc(IMG_isXPM)("IMG_isXPM", lib);
    bindFunc(IMG_isXCF)("IMG_isXCF", lib);
    bindFunc(IMG_isPCX)("IMG_isPCX", lib);
    bindFunc(IMG_isGIF)("IMG_isGIF", lib);
    bindFunc(IMG_isJPG)("IMG_isJPG", lib);
    bindFunc(IMG_isTIF)("IMG_isTIF", lib);
    bindFunc(IMG_isPNG)("IMG_isPNG", lib);
    bindFunc(IMG_isLBM)("IMG_isLBM", lib);
    bindFunc(IMG_LoadBMP_RW)("IMG_LoadBMP_RW", lib);
    bindFunc(IMG_LoadPNM_RW)("IMG_LoadPNM_RW", lib);
    bindFunc(IMG_LoadXPM_RW)("IMG_LoadXPM_RW", lib);
    bindFunc(IMG_LoadXCF_RW)("IMG_LoadXCF_RW", lib);
    bindFunc(IMG_LoadPCX_RW)("IMG_LoadPCX_RW", lib);
    bindFunc(IMG_LoadGIF_RW)("IMG_LoadGIF_RW", lib);
    bindFunc(IMG_LoadJPG_RW)("IMG_LoadJPG_RW", lib);
    bindFunc(IMG_LoadTIF_RW)("IMG_LoadTIF_RW", lib);
    bindFunc(IMG_LoadPNG_RW)("IMG_LoadPNG_RW", lib);
    bindFunc(IMG_LoadLBM_RW)("IMG_LoadLBM_RW", lib);
    bindFunc(IMG_ReadXPMFromArray)("IMG_ReadXPMFromArray", lib);
}


GenericLoader DerelictSDLImage;
static this() {
	DerelictSDLImage.setup(
		"SDL_image.dll",
		"libSDL_image.so, libSDL_image-1.2.so, libSDL_image-1.2.so.0",
		"",
		&load
	);
}

