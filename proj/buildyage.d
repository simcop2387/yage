#!dmd -run
/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty: none
 *
 * Builds the yage game engine and optionally the html documentation.
 * This is a mess, but a working mess.  Once more of this script is modified
 * to use the newer build.d, it will be less of a mess.
 * 
 * It first builds derelict into a lib if it hasn't already been,
 * and then builds all of the files in src_path.
 *
 * Examples:
 * ------
 * dmd -run buildme.d -release -clean -ddoc -run
 * dmd -run buildme.d -gdc
 * ------
 *
 * This script has been tested with:
 * DMD on Windows
 * DMD on X86 Linux
 * GDC on X86 Linux
 */

import std.c.process;
import std.stdio;
import std.file;
import std.path;
import std.perf;
import std.string;

// Set options for compilation.
// Paths are relative to the build script.
char[]   mod_path = "../src";				// The root folder of all modules
char[][] src_path = ["yage", "demo1"];		// Array of folders to look for source files
char[][] imp_path = ["derelict"];			// Build everything in this path into a lib for future builds.
char[]   lib_path = "../lib";				// Folder where libraries are placed.

char[] obj_path = "../bin/.obj";			// Folder for object files
char[] bin_path = "../bin";					// Folder where executable binary will be placed
char[] bin_name = "yage3d";					// executable binary name
char[] doc_path = "../doc/api";				// Folder for html documentation, if ddoc flag is set
char[] cur_path;							// Folder of this script, set automatically

// OS dependant strings
version (Windows)
{	char[] bin_ext = ".exe";
	char[] lib_ext = ".lib";
} else
{	char[] bin_ext = "";
	char[] lib_ext = ".a";
}

version (Windows)
{	alias HighPerformanceCounter PerformanceCounter;
}


class Util
{

	/**
	 * Get an absolute path from a relative path. */
	static char[] absPath(char[] rel_path)
	{	// Remove filename
		char[] filename;
		int index = rfind(rel_path, sep);
		if (index != -1)
		{	filename = rel_path[rfind(rel_path, sep)..length];
			rel_path = replace(rel_path, filename, "");
		}

		char[] cur_path = getcwd();
		try {	// if can't chdir, rel_path is current path.
			chdir(rel_path);
		} catch {};
		char[] result = getcwd();
		chdir(cur_path);
		return result~filename;
	}
	
	static bool exec(...)
	{	char[] command;
		void putchar(dchar c)
		{	command~= c;
		}
		std.format.doFormat(&putchar, _arguments, cast(char*)_argptr);
		if (Build.verbose)
			writefln(command);
		return !system(toStringz(command));
	}
	
	static void remove(char[] file)
	{	if (exists(file))
			std.file.remove(file);		
	}
	
	/**
	 * Recursively get all sources in directory and subdirectories that have an extension in exts
	 * @param directory Absolute or relative path to the current directory
	 * @param exts Array of extensions to match
	 * @return An array of paths (including filename) relative to directory. */
	static char[][] recls(char[] directory, char[][] exts)
	{	char[][] result;
		foreach(char[] filename; listdir(directory).sort)
		{	char[] name = directory~sep~filename;
			if(isdir(name))
				result ~= recls(name, exts);
			else if (isfile(name))
			{	// if filename is longer than ext and filename's extention is ext.
				foreach (char[] ext; exts)
					if (filename.length>=ext.length && filename[(length-ext.length)..length]==ext)
					{	char[] t = name;
						if (t[0..2] == "."~sep)
							t = t[2..length]; // remove any "./" prefix.
						result~= t;
			}		}
		}
		return result;
	}

	/**
	 * Recursively get all directories in a path, except hidden ones
	 * @param directory An absolute path, or relative path from the current directory.
	 * @return an array of relative paths from directory. */ 
	static char[][] recls(char[] directory=".")
	{	char[][] result;
		result ~= directory;
		foreach(char[] filename; listdir(directory).sort)
			if(isdir(directory~sep~filename) && filename[0] != '.')
				result ~= recls(directory~sep~filename);		
		return result;
	}
	
	static char[] swritef(...)
	{	char[] res;
		void putchar(dchar c)
		{	res~= c;
		}
		std.format.doFormat(&putchar, _arguments, cast(char*)_argptr);
		return res;
	}
}

class Build
{
	// Options
	static bool _debug, _release, profile, ddoc, _clean, verbose, run, silent, gdc;
	
	static char[][] sources;	// All source files to include in build.
	static char[][] libs;		// All lib files to include in build.
	
	
	static bool all()
	{	makePaths();
		getFiles();
		clean();
		buildLibs();
		
		
		// Clean docs and generate candydoc module
		if (ddoc)
			try
			{	docsPreProcess();
			} catch (Exception e)
			{	writefln(e);
				writefln("Error with optional documentation step.  Continuing.");
			}
		
		// Compile
		if (!compile())
		{	writefln("Compile failed.  Please fix the errors and try again.");
			return 1;
		}

		
		// Move the output files		
		// Executable binary
		char[] target = bin_path~sep~bin_name~bin_ext;			
		Util.remove(target); // remove old binary
		std.file.rename(mod_path~sep~bin_name~bin_ext, target);
		
		// Remove the .map file
		target = obj_path~sep~bin_name~".map";
		Util.remove(target);	// shouldn't this have been removed in the initial clean?
		if (std.file.exists(mod_path~sep~bin_name~".map"))
			std.file.rename(mod_path~sep~bin_name~".map", target); // ?

		// Move Docs
		if (ddoc)
			try
			{	docsPostProcess();
			} catch (Exception e)
			{	writefln(e);
				writefln("Error with optional documentation step.  Continuing.");
			}

		// Clean
		if (_clean)
			try
			{	clean();
			} catch (Exception e)
			{	writefln(e);
				writefln("Error with optional clean step.  Continuing.");
			}
		
		return 0;
	}
	
	static public void makePaths()
	{
		// Create the paths we write to if they don't exist
		if (!exists(bin_path))	mkdir(bin_path);
		if (!exists(obj_path))	mkdir(obj_path);
		if (!exists(doc_path))	mkdir(doc_path);
		if (!exists(lib_path))	mkdir(lib_path);

		// Create absolute paths
		cur_path = getcwd();
		mod_path = Util.absPath(mod_path);		
		obj_path = Util.absPath(obj_path);
		bin_path = Util.absPath(bin_path);
		doc_path = Util.absPath(doc_path);
	}
	
	// Fill the arrays of source and library files to include in the build.
	static void getFiles()
	{	sources = null;
		
		// Get a list of all files as absolute paths
		chdir(mod_path);
		foreach (char[] path; src_path)
		{	if (ddoc) // this division won't be necessary once we use the build.d script for everything.
				sources ~= Util.recls(path, [".d", ".ddoc"]);
			else
				sources ~= Util.recls(path, [".d"]);
		}
	
	}
	
	static void buildLibs()
	{	libs = null;
	
		version (Windows) char[] env="win32";
		version (linux) char[] env="linux";
		char[] compiler = gdc ? "gdc" : "dmd";
		char[] offlag = gdc ? "o" : "of";
		char[] flags  = gdc ? "" : "-O -inline -release";
		
		scope(exit)
			clean2();
		
		void clean2()
		{	Util.remove(cur_path~sep~"build");
			Util.remove(cur_path~sep~"build.s");
			Util.remove(cur_path~sep~"build.o");
			Util.remove(cur_path~sep~"build.obj");
			Util.remove(cur_path~sep~"build.map");
		}
		
		// Create builder
		chdir(cur_path);
		Util.exec("%s %s build.d -%sbuild%s", compiler, flags, offlag, bin_ext);
		
		// Convert everything in imp_path into a lib in lib_path
		foreach(path; imp_path)
		{
			char[] lib_name = Util.swritef("%s-%s-%s%s", path, compiler, env, lib_ext);
			
			chdir(mod_path);
			if (!exists(lib_path~sep~lib_name))
			{	Util.exec("\".."~sep~"proj"~sep~"build%s\" %s -lib -%s%s", bin_ext, path, offlag, lib_name);
				std.file.rename(lib_name, lib_path~sep~lib_name); // move to lib folder
			}
			
			libs ~= lib_path~sep~lib_name;
		}		
	}

	// Delete all object files
	static void clean()
	{	if (verbose)
			writefln("[Cleaning]");	

		// Remove all intermediate files
		char[][] files = Util.recls(obj_path, [".obj", ".o", ".map", bin_ext]);
		foreach(char[] file; files)
			if (std.file.exists(file))
				std.file.remove(file);

		// Remove all intermediate folders
		char[][] folders = Util.recls(obj_path);
		for(int i=folders.length-1; i>-0; i--)
			if (std.file.exists(folders[i]))
				rmdir(folders[i]);
	}


	// Compile sources in src_path to objects in obj_path
	static bool compile()
	{	if (verbose)
			writefln("[Compiling]");

		// Build flags
		char[][] flags;
		flags~= "-I"~std.string.join(imp_path, ";");
		if (gdc)
		{	if (_debug)
			{	flags~="-fdebug";
				flags~="-g";
			}
			else if (_release)
			{	flags~="-O3";
				flags~="-finline-functions";
				flags~="-frelease";
			}
			if (profile)
				flags~="-profile";
			if (ddoc)
			{	flags~="-fdoc";
				flags~="-fdoc-dir"~doc_path;
			}
			if (!_release)
				flags~="-funittest";			
			flags~="-od"~obj_path;		// Set the object output directory
			flags~="-op";					// Preserve path of object files, otherwise duplicate names will overwrite one another!
			flags~="-o"~bin_name~bin_ext;	// output filename		
		}
		else
		{	if (_debug)
			{	flags~="-debug";
				flags~="-gc";
			}
			else if (_release)
			{	flags~="-O";
				flags~="-inline";
				flags~="-release";
			}
			if (profile)
				flags~="-profile";
			if (ddoc)
			{	flags~="-D";
				flags~="-Dd"~doc_path;
			}
			if (!_release)
				flags~="-unittest";
			flags~="-od"~obj_path;	// Set the object output directory
			flags~="-op";			// Preserve path of object files, otherwise duplicate names will occur!
			flags~="-of"~bin_name~bin_ext;	// output filename			
			flags~="-quiet";
		}
		
		char[][] args = flags ~ sources ~ libs;	
		char[] compiler = gdc ? "gdc" : "dmd";				
		
		chdir(mod_path);
		bool success;
		version (Windows) // Since windows is limited to 8190 chars per command
		{	std.file.write("compile", std.string.join(args," "));
			char[] exec = compiler ~ " @compile";	// we write args out to a file in case they're too long for system to execute.
			
			success = Util.exec(exec);
			std.file.remove("compile");
		}
		else
		{	char[] dl = gdc ? " -ldl" : " -L-ldl"; // link with the dl library for derelict.		
			char[] exec = compiler ~" " ~ std.string.join(args," ") ~ dl;
		
			success = Util.exec(exec);
		}
		return success;
	}
	

	static void docsPreProcess()
	{	if (verbose)
			writefln("[Pre Processing Docs]");	

		// Clean out any previous docs
		chdir(doc_path);
		foreach (char[] doc; Util.recls(".", [".html"]))
			std.file.remove(doc);
		
		// Create modules.ddoc
		chdir(mod_path);
		foreach (char[] path; src_path)
		{	if (std.file.exists(path~"/candy.ddoc"))
			{	chdir(path);
				char[] modules = "MODULES = \r\n";
				foreach(char[] src; Util.recls("./", [".d"]))
				{	src = split(src, ".")[0];		// remove extension
					src = path~replace(src, sep, ".");	// replace path separator with dot.
					modules ~= "\t$(MODULE "~src~")\r\n";
				}
				// Create modules.ddoc
				std.file.write("modules.ddoc", modules);
				sources ~= replace(path~"/modules.ddoc", mod_path~sep, "");	// Add newly created modules.ddoc to sources
			}				
		}
		
		
		// Create folders for the documentation
		/*
		chdir(mod_path);
		if (ddoc)
		{	char[][] paths = Util.recls();
			foreach (char[] path; paths)
			{	path = doc_path~sep~path;
				if (!exists(path))
					mkdir(path);
		}	}
		*/
	}

	/**
	 * Rename and move documentation files, and delete intermediate candydoc files.*/
	static void docsPostProcess()
	{	if (verbose)
			writefln("[Post Processing Docs]");

		// Move all html files in doc_path to the same folder and rename with the "package.module" naming convention.
		chdir(doc_path);
		char[][] docs = Util.recls(".", [".html"]);
		foreach (char[] doc; docs)
		{	char[] dest = replace(doc, sep, ".");
			if (doc != dest)
			{	copy(doc, dest);
				std.file.remove(doc);
		}	}

		// Delete all intermediate folders except the candydoc folder
		char[][] folders = Util.recls(doc_path);
		for(int i=folders.length-1; i>-0; i--)
		{	// Only delete if empty
			if (listdir(folders[i]).length == 0)
				rmdir(folders[i]);
		}

		// Delete modules.ddoc
		foreach (char[] path; src_path)
			Util.remove(path~"/modules.ddoc");	
	}
}

int main(char[][] args)
{	
	// Parse arguments
	foreach (char[] arg; args)
	{	switch(tolower(arg))
		{	case "-debug": 		Build._debug 	= true; break;
			case "-release": 	Build._release 	= true; break;
			case "-profile": 	Build.profile 	= true; break;
			case "-ddoc": 		Build.ddoc 		= true; break;
			case "-clean": 		Build._clean 	= true; break;
			case "-run": 		Build.run 		= true; break;
			case "-silent": 	Build.silent 	= true; break;
			case "-verbose": 	Build.verbose 	= true; break;
			case "-gdc": 		Build.gdc 		= true; break;
			default: break;
		}
	}

	writefln("Building Yage...");
	if (!Build.silent)
	{	writefln("If you're curious, the options are:");
		writefln("   -clean     Delete all intermediate object files.");
		writefln("   -ddoc      Generate documentation in "~doc_path);
		writefln("   -debug     Include debugging symbols.");
		writefln("   -gdc       Compile using gdc instead of dmd.");
		writefln("   -profile   Compile in profiling code.");
		writefln("   -release   Optimize, inline expand functions, and remove unit tests/asserts.");
		writefln("   -run       Run when finished.");
		writefln("   -silent    Hide this helpful message.");
		writefln("   -verbose   Print all commands as they're being executed.");
		writefln("Example:  dmd -run buildme.d -clean -release -run");
	}
	
	// Start timing
	PerformanceCounter hpc = new PerformanceCounter();
	hpc.start();
	
	// Build everything
	if (Build.all() != 0)
		return 1;
	
	// Completed message and time
	hpc.stop();
	float time = hpc.microseconds()/1000000.0f;
	writefln("The build completed successfully in %.2f seconds.", time);
	writefln("`", bin_name, bin_ext, "' has been placed in '", bin_path, "'.");

	// Run
	if (Build.run)
	{	chdir(bin_path);
		
		version(Windows)
			Util.exec(bin_name ~ bin_ext);
		else
			Util.exec("./", bin_name, bin_ext);
		chdir(cur_path);
	}
	
	return 0;
}