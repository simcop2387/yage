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
 * * Neither the names 'Derelict', 'DerelictGL', nor the names of its contributors
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
module derelict.opengl.gl;

public
{
    import derelict.opengl.gltypes;
    import derelict.opengl.glfuncs;
    import derelict.opengl.gl12;
    import derelict.opengl.gl13;
    import derelict.opengl.gl14;
    import derelict.opengl.gl15;
    import derelict.opengl.gl20;
    import derelict.opengl.gl21;
}

private
{
    import std.string;

    import derelict.util.loader;
    import derelict.util.exception;

    version(Windows)
        import derelict.opengl.wgl;
    else version(linux)
        version = UsingGLX;

    version(UsingGLX)
        import derelict.opengl.glx;
}

private void loadAll(SharedLib lib) {
    loadPlatformGL(lib);
    loadGL(lib);
}

enum GLVersion
{
    VersionNone,
    Version11 = 11,
    Version12 = 12,
    Version13 = 13,
    Version14 = 14,
    Version15 = 15,
    Version20 = 20,
    Version21 = 21,
    HighestSupported = 21
}


private
{
    GenericLoader GLLoader;

    typedef bool function(char[]) ExtensionLoader;
    ExtensionLoader[] loaders;
    bool versionsOnce           = false;
    bool extensionsOnce         = false;
    int numExtensionsLoaded     = 0;

    version(Windows)
    {
        import std.c.windows.windows;

        version(DigitalMars)
        {
            pragma(lib, "gdi32.lib");
        }

        extern(Windows) export int GetPixelFormat(HDC hdc);
        int currentPixelFormat      = 0;
    }

    bool isLoadRequired()
    {
        version(Windows)
        {
            HDC hdc = wglGetCurrentDC();
            if(hdc is null)
                throw new Error("Could not obtain a device context for the current OpenGL context");

            if(0  == currentPixelFormat)
            {
                currentPixelFormat = GetPixelFormat(hdc);
                return true;
            }

            int newFormat = GetPixelFormat(hdc);
            if(0 == newFormat)
                throw new Error("Could not determine current pixel format");

            bool ret = true;
            if(newFormat == currentPixelFormat)
                ret = false;
            currentPixelFormat = newFormat;
            return ret;
        }
        else
            return false;
    }
}

struct DerelictGL
{
    static void setup(char[] winLibs, char[] linLibs, char[] macLibs, void function(SharedLib) userLoad, char[] versionStr = "")
    {
        GLLoader.setup(winLibs, linLibs, macLibs, userLoad, versionStr);
    }

    static void load(char[] libNameString = null)
    {
        GLLoader.load(libNameString);
    }

    static char[] versionString()
    {
        return GLLoader.versionString();
    }

    static void unload()
    {
        GLLoader.unload();
    }

    static bool hasValidContext()
    {
        version(Windows)
        {
            if(wglGetCurrentContext() is null)
                return false;
        }
        else version(UsingGLX)
        {
            if(glXGetCurrentContext() is null)
                return false;
        }
        return true;
    }

    static void loadVersions(GLVersion minVersion)
    {
        version(Windows)
        {
            if(!hasValidContext)
                throw new Error("You must create an OpenGL context before attempting to load OpenGL versions later than 1.1");
        }

        if(versionsOnce)
        {
            if(!isLoadRequired())
                return;
        }
        else
            versionsOnce = true;

        if(GLVersion.VersionNone == maxVersionAvail)
            setVersion();
         
        if(GLVersion.Version11 == maxVersionAvail)
        {
	        loadedVersion = GLVersion.Version11;
        	return;
    	}

        try
        {
            // version 1.2
            if(minVersion >= GLVersion.Version12)
                loadVersion(&loadGL12, GLVersion.Version12);

            // version 1.3
            if(minVersion >= GLVersion.Version13)
                loadVersion(&loadGL13, GLVersion.Version13);

            // version 1.4
            if(minVersion >= GLVersion.Version14)
                loadVersion(&loadGL14, GLVersion.Version14);

            // version 1.5
            if(minVersion >= GLVersion.Version15)
                loadVersion(&loadGL15, GLVersion.Version15);

            // version 2.0
            if(minVersion >= GLVersion.Version20)
                loadVersion(&loadGL20, GLVersion.Version20);
                
            // version 2.1
            if(minVersion >= GLVersion.Version21)
            	loadVersion(&loadGL21, GLVersion.Version21);
        }
        catch(SharedLibProcLoadException slple)
        {
            if(maxVersionAvail >= minVersion)
                return;
            else
                throw slple;
        }
    }

    static int loadExtensions()
    {
        if(!hasValidContext)
                throw new Error("You must create an OpenGL context before attempting to load OpenGL extensions");

        if(extensionsOnce)
        {
            if(!isLoadRequired())
                return numExtensionsLoaded;
        }
        else
            extensionsOnce = true;

        char[] extString = toString(glGetString(GL_EXTENSIONS));

        int count;
        foreach(ExtensionLoader loader; loaders)
        {
            if(loader(extString))
                ++count;
        }
        numExtensionsLoaded = count;

        return count;
    }

    static GLVersion availableVersion()
    {
        if(GLVersion.VersionNone == maxVersionAvail)
        {
            setVersion();
            loadVersions(maxVersionAvail);
        }

        return loadedVersion;
    }

    static char[] versionString(GLVersion glv)
    {
        static char vstrings[GLVersion.max + 1][] = [GLVersion.VersionNone:"Unknown",
            GLVersion.Version11:"Version 1.1", GLVersion.Version12:"Version 1.2",
            GLVersion.Version13:"Version 1.3", GLVersion.Version14:"Version 1.4",
            GLVersion.Version15:"Version 1.5", GLVersion.Version20:"Version 2.0",
            GLVersion.Version21:"Version 2.1"];
        return  vstrings[glv];
    }

    static void registerExtensionLoader(ExtensionLoader loader)
    {
        loaders ~= loader;
    }


    private static GLVersion maxVersionAvail    = GLVersion.VersionNone;
    private static GLVersion loadedVersion      = GLVersion.VersionNone;

    private static void setVersion()
    {
        if(!hasValidContext)
            throw new Error("You must create an OpenGL context before attempting to check the OpenGL version");

        char *cstr = glGetString(GL_VERSION);
        char[] str = toString(cstr);

        if(str.find("2.1") == 0)
            maxVersionAvail = GLVersion.Version21;
        else if(str.find("2.0") == 0)
            maxVersionAvail = GLVersion.Version20;
        else if(str.find("1.5") == 0)
            maxVersionAvail = GLVersion.Version15;
        else if(str.find("1.4") == 0)
            maxVersionAvail = GLVersion.Version14;
        else if(str.find("1.3") == 0)
            maxVersionAvail = GLVersion.Version13;
        else if(str.find("1.2") == 0)
            maxVersionAvail = GLVersion.Version12;
        else if(str.find("1.1") == 0)
            maxVersionAvail = GLVersion.Version11;
        else if(str.find("1.0") == 0)
            throw new Error("Unsupported OpenGL version \"" ~ str ~ "\"");
        else
        {
            // assume a new version of OpenGL that we haven't added support for
            // yet -- maxVersionAvail will be the highest that DerelictGL supports
            maxVersionAvail = GLVersion.HighestSupported;
        }

    }

    private static void loadVersion(void function(SharedLib) loadFunc, GLVersion glv)
    {
        loadFunc(glLib);
        loadedVersion = glv;
        return true;
    }
}


static this () {
    DerelictGL.setup (
        "opengl32.dll",
        "libGL.so",
        "",
        &loadAll
    );
}

