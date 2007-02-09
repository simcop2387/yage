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
 * * Neither the names 'Derelict', 'DerelictUtil', nor the names of its contributors
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
module derelict.util.loader;

private
{
    import derelict.util.exception;
    import std.string;
}

version(linux)
{
    version = Nix;
}
else version(Unix)
{
    version = Nix;
}

version (DerelictUseStdLoader) {
    import std.loader;

    //==============================================================================
    class SharedLib
    {
    public:
        char[] name()
        {
            return _name;
        }

    private:
        char[]      _name;

        void* delegate(in char[] symbolName)    getSymbolDg;
        Object theLib;

        private void unload() {
            if (theLib) {
                delete theLib;
                theLib = null;
                getSymbolDg = null;
            }
        }


        void* getSymbol(char[] symName) {
            if (theLib !is null) return getSymbolDg(symName);
            else return null;
        }


        this(Object theLib, void* delegate(in char[])   getSymbolDg, char[] name)
        in {
            assert (theLib !is null);
            assert (getSymbolDg !is null);
        }
        body {
            this.theLib = theLib;
            this.getSymbolDg = getSymbolDg;
            this._name = name;
        }
    }
    //==============================================================================
    SharedLib Derelict_LoadSharedLib(char[] libName)
    in
    {
        assert(libName !is null);
    }
    body
    {
        try {
            auto ExeModule exeMod = new ExeModule(libName);
            auto res = new SharedLib(exeMod, &exeMod.getSymbol, libName);
            exeMod = null;      // fool the auto
            return res;
        }
        catch (ExeModuleException exc) {
            throw new SharedLibLoadException(libName);
        }
    }

    //==============================================================================
    SharedLib Derelict_LoadSharedLib(char[][] libNames)
    in
    {
        assert(libNames !is null);
    }
    body
    {
        SharedLibLoadException exception = null;
        SharedLib lib = null;

        foreach(char[] libName; libNames)
        {
            try
            {
                lib = Derelict_LoadSharedLib(libName);
            }
            catch(SharedLibLoadException slle)
            {
                exception = slle;
            }
        }
        if(lib is null)
            throw exception;

        return lib;
    }

    //==============================================================================
    void Derelict_UnloadSharedLib(SharedLib lib)
    {
        if(lib !is null) lib.unload();
    }
    //==============================================================================
    void* Derelict_GetProc(SharedLib lib, char[] procName)
    in
    {
        assert(lib !is null);
        assert(procName !is null);
    }
    body
    {
        void* proc = lib.getSymbol(procName);
        if (proc is null) {
            Derelict_HandleMissingProc(lib._name, procName);
        }
        return proc;
    }
    //==============================================================================
}
//==============================================================================
else {
    private alias void* SharedLibHandle;

    //==============================================================================
    class SharedLib
    {
    public:
        char[] name()
        {
            return _name;
        }

    private:
        SharedLibHandle _handle;
        char[] _name;

        this(SharedLibHandle handle, char[] name)
        {
            _handle = handle;
            _name = name;
        }
    }
    //==============================================================================
    SharedLib Derelict_LoadSharedLib(char[] libName)
    in
    {
        assert(libName !is null);
    }
    body
    {
        return Platform_LoadSharedLib(libName);
    }

    //==============================================================================
    SharedLib Derelict_LoadSharedLib(char[][] libNames)
    in
    {
        assert(libNames !is null);
    }
    body
    {
        SharedLibLoadException exception = null;
        SharedLib lib = null;

        foreach(char[] libName; libNames)
        {
            try
            {
                lib = Derelict_LoadSharedLib(libName);
            }
            catch(SharedLibLoadException slle)
            {
                exception = slle;
            }
        }
        if(lib is null)
            throw exception;

        return lib;
    }

    //==============================================================================
    void Derelict_UnloadSharedLib(SharedLib lib)
    {
        if(lib !is null && lib._handle !is null)
            Platform_UnloadSharedLib(lib);
    }
    //==============================================================================
    void* Derelict_GetProc(SharedLib lib, char[] procName)
    in
    {
        assert(lib !is null);
        assert(procName !is null);
    }
    body
    {
        if(lib._handle is null)
            throw new InvalidSharedLibHandleException(lib._name);
        return Platform_GetProc(lib, procName);
    }
    //==============================================================================
    version(Windows)
    {
        private import std.c.windows.windows;

        SharedLib Platform_LoadSharedLib(char[] libName)
        {
            HMODULE hlib = LoadLibraryA(toStringz(libName));
            if(null is hlib)
                throw new SharedLibLoadException(libName);

            return new SharedLib(hlib, libName);
        }

        void Platform_UnloadSharedLib(SharedLib lib)
        {
            FreeLibrary(cast(HMODULE)lib._handle);
            lib._handle = null;
        }

        void* Platform_GetProc(SharedLib lib, char[] procName)
        {
            void* proc = GetProcAddress(cast(HMODULE)lib._handle, toStringz(procName));
            if(null is proc)
                Derelict_HandleMissingProc(lib._name, procName);

            return proc;
        }

    }
    else version(Nix)
    {
        version(linux)
        {
            private import std.c.linux.linux;
        }
        else
        {
            extern(C)
            {
                /* From <dlfcn.h>
                *  See http://www.opengroup.org/onlinepubs/007908799/xsh/dlsym.html
                */

                const int RTLD_NOW = 2;

                void *dlopen(char* file, int mode);
                int dlclose(void* handle);
                void *dlsym(void* handle, char* name);
                char* dlerror();
            }
        }

        SharedLib Platform_LoadSharedLib(char[] libName)
        {
            void* hlib = dlopen(toStringz(libName), RTLD_NOW);
            if(null is hlib)
                throw new SharedLibLoadException("Failed to load shared library " ~ libName);

            return new SharedLib(hlib, libName);
        }

        void Platform_UnloadSharedLib(SharedLib lib)
        {
            dlclose(lib._handle);
            lib._handle = null;
        }

        void* Platform_GetProc(SharedLib lib, char[] procName)
        {
            void* proc = dlsym(lib._handle, toStringz(procName));
            if(null is proc)
                Derelict_HandleMissingProc(lib._name, procName);

            return proc;
        }
    }
    else
    {
        static assert(0);
    }
}

//==============================================================================

struct GenericLoader {
    void setup(char[] winLibs, char[] linLibs, char[] macLibs, void function(SharedLib) userLoad, char[] versionStr = "") {
        assert (userLoad !is null);
        this.winLibs = winLibs;
        this.linLibs = linLibs;
        this.macLibs = macLibs;
        this.userLoad = userLoad;
        this.versionStr = versionStr;
    }

    void load(char[] libNameString = null)
    {
        if (myLib !is null) {
            return;
        }

        // make sure the lib will be unloaded at progam termination
        registeredLoaders ~= this;


        if (libNameString is null) {
            version (Windows) {
                libNameString = winLibs;
            }
            else version (linux) {
                libNameString = linLibs;
            }
        }

        char[][] libNames = libNameString.split(",");
        foreach (inout char[] l; libNames) {
            l = l.strip();
        }

        myLib = Derelict_LoadSharedLib(libNames);
        userLoad(myLib);
    }

    char[] versionString()
    {
        return versionStr;
    }

    void unload()
    {
        if (myLib !is null) {
            Derelict_UnloadSharedLib(myLib);
            myLib = null;
        }
    }

    static ~this()
    {
        foreach (x; registeredLoaders) {
            x.unload();
        }
    }

    private {
        static GenericLoader*[] registeredLoaders;

        SharedLib myLib;
        char[] winLibs;
        char[] linLibs;
        char[] macLibs;
        char[] versionStr = "";

        void function(SharedLib) userLoad;
    }
}

//==============================================================================

struct GenericDependentLoader {
    void setup(GenericLoader* dependence, void function(SharedLib) userLoad) {
        assert (dependence !is null);
        assert (userLoad !is null);

        this.dependence = dependence;
        this.userLoad = userLoad;
    }

    private SharedLib myLib() {
        return dependence.myLib;
    }

    void load()
    {
        assert (myLib !is null);
        userLoad(myLib);
    }

    char[] versionString()
    {
        return dependence.versionString;
    }

    void unload()
    {
    }

    private {
        GenericLoader*              dependence;
        void function(SharedLib)    userLoad;
    }
}

//==============================================================================

struct GenericStaticLoader {
    void setup(void function() userLoad = null, char[] versionStr = "") {
        this.userLoad = userLoad;
        this.versionStr = versionStr;
    }

    void load()
    {
        if (userLoad !is null) {
            userLoad();
        }
    }

    char[] versionString()
    {
        return versionString;
    }

    void unload()
    {
    }

    private {
        char[]          versionStr;
        void function() userLoad;
    }
}


//==============================================================================

package struct Binder(T) {
    void opCall(char[] n, SharedLib lib) {
        *fptr = Derelict_GetProc(lib, n);
    }


    private {
        void** fptr;
    }
}


template bindFunc(T) {
    Binder!(T) bindFunc(inout T a) {
        Binder!(T) res;
        res.fptr = cast(void**)&a;
        return res;
    }
}
