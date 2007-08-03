#!dmd -run
/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty: none
 *
 * Builds the yage game engine and optionally the html documentation, but
 * feel free to use this script for whatever.
 * 
 * This script can either use precompiled derelict libraries in the lib folder
 * or build the derelict source directly with the engine.  The former is
 * of course faster, but the latter can be achieved by setting ign_path and
 * lib_path to empty strings in the compilation options below.
 * 
 * This script can easily be expanded to compile and generate docs for most
 * things by changing the path variables below.
 *
 * Examples:
 * ------
 * dmd -run buildme.d -release -clean -ddoc -run
 * dmd -run buildme.d -gdc
 * ------
 *
 * TODO:
 * Test with GDC on Linux.
 */

import std.c.process;
import std.stdio;
import std.file;
import std.path;
import std.perf;
import std.string;

// Set options for compilation.
// Paths are relative to the build script.
char[]   mod_path = "../src";						// The root folder of all modules
char[][] src_path = ["../src/yage", "../src/demo2"];// Array of folders to look for source files
char[][] imp_path = ["../src/derelict"];			// Array of folders to look for imports
char[][] lib_path = ["../lib"];						// Array of folders to scan for libraries

char[] obj_path = "../bin/.obj";					// Folder for object files
char[] bin_path = "../bin";							// Folder where executable binary will be placed
char[] bin_name = "demo2";							// executable binary name
char[] doc_path = "../doc/api";						// Folder for html documentation, if ddoc flag is set
char[] cur_path;									// Folder of this script, set automatically

// OS dependant strings
version (Windows)
{	char[] bin_ext = ".exe";
	char[] lib_ext = ".lib";
}else
{	char[] bin_ext = "";
	char[] lib_ext = ".a";
}

version (Windows)
{	alias HighPerformanceCounter PerformanceCounter;
}


class Util
{
	// Return the full path of all files in directory and all subdirectories with extension ext
	static char[][] scan(char[] directory, char[][] exts)
	{	char[][] res;
		foreach(char[] filename; listdir(directory))
		{	char[] name = directory~sep~filename;
			if(isdir(name))
				res ~= scan(name, exts);
			else if (isfile(name))
			{	// if filename is longer than ext and filename's extention is ext.
				foreach (char[] ext; exts)
					if (filename.length>=ext.length && filename[(length-ext.length)..length]==ext)
					{	char[] t = name;
						if (t[0..2] == "."~sep)
							t = t[2..length];
						res~= t;
			}		}
		}
		return res;
	}

	// Return all directories in a path, except hidden ones
	static char[][] recls(char[] directory=".")
	{	char[][] result;
		result ~= directory;
		foreach(char[] filename; listdir(directory))
		{	if(isdir(directory~sep~filename) && filename[0]!='.')
				result ~= recls(directory~sep~filename);
		}
		return result;
	}

	// Given relative path rel_path, returns an absolute path.
	static char[] absPath(char[] rel_path)
	{
		// Remove filename
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
}

class Build
{
	// Options
	static bool _debug, _release, nolink, profile, ddoc, _clean, verbose, run, silent, gdc;
	
	static char[][] sources;	// All source files to include in build.
	static char[][] libs;		// All lib files to include in build.
	
	
	static bool all()
	{	makePaths();
		getFiles();
		clean();
		
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
		if (!nolink)
		{	// Executable binary
			char[] target = bin_path~sep~bin_name~bin_ext;			
			if (std.file.exists(target))
				std.file.remove(target); // remove old binary
			std.file.rename(mod_path~sep~bin_name~bin_ext, target);
			
			// Remove the .map file
			target = obj_path~sep~bin_name~".map";
			if (std.file.exists(target))
				std.file.remove(target);	// shouldn't this have been removed in the initial clean?
			if (std.file.exists(mod_path~sep~bin_name~".map"))
				std.file.rename(mod_path~sep~bin_name~".map", target);
		}

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

		// Create absolute paths
		cur_path = getcwd();
		mod_path = Util.absPath(mod_path);		
		obj_path = Util.absPath(obj_path);
		bin_path = Util.absPath(bin_path);
		doc_path = Util.absPath(doc_path);
		
		foreach (inout char[] path; src_path)  path = Util.absPath(path);
		foreach (inout char[] path; imp_path)  path = Util.absPath(path);
		foreach (inout char[] path; lib_path)  path = Util.absPath(path);
	}
	
	// Fill the arrays of source and library files to include in the build.
	static void getFiles()
	{	sources = null;
		libs = null;
		
		// Get a list of all files as absolute paths
		foreach (char[] path; src_path)
		{	sources ~= Util.scan(path, [".d", ".ddoc"]);
			if (ddoc)
				sources ~= Util.scan(path, [".ddoc"]);
		}		
		foreach (char[] path; lib_path)
			libs ~= Util.scan(path, [lib_ext]);

		// Convert from absolute paths to paths relative to mod_path
		foreach (inout char[] source; sources)
			source = replace(source, mod_path~sep, "");
		foreach (inout char[] lib; libs)
			lib = replace(lib, mod_path~sep, "");
	}

	// Delete all object files
	static void clean()
	{	if (verbose)
			writefln("[Cleaning]");	

		// Remove all intermediate files
		char[][] files = 
			Util.scan(obj_path, [".obj"]) ~
			Util.scan(obj_path, [".o"]) ~
			Util.scan(obj_path, [".map"]) ~
			Util.scan(obj_path, [bin_ext]);
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
			
		// Get the source files and set compiler flags
		chdir(mod_path);

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
				flags~="-finline";
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
			//flags~="-od"~obj_path;		// Set the object output directory
			//flags~="-op";					// Preserve path of object files, otherwise duplicate names will overwrite one another!
			flags~="-o"~bin_name~bin_ext;	// output filename		
		}
		else
		{	if (_debug)
			{	flags~="-debug";
				flags~="-g";
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
			flags~="-of"~bin_name~bin_ext;	// output filename
			flags~="-op";			// Preserve path of object files, otherwise duplicate names will occur!
			flags~="-quiet";
		}
		if (nolink)
			flags~="-c";				// do not link		

		// Create folders for the documentation
		if (ddoc)
		{	char[][] paths = Util.recls();
			foreach (char[] path; paths)
			{	path = doc_path~sep~path;
				if (!exists(path))
					mkdir(path);
		}	}
		
		char[][] args = flags ~ sources ~ libs;	
		char[] compiler = gdc ? "gdc" : "dmd";	
		if (verbose)			
			writefln(compiler ~ " " ~ std.string.join(args," "));		
		
		bool success;
		version (Windows) // Since windows is limited to 8190 chars per command
		{	std.file.write("compile", std.string.join(args," "));
			char[] exec = compiler ~ " @compile";	// we write args out to a file in case they're too long for system to execute.
			success = !std.c.process.system(toStringz(exec));
			std.file.remove("compile");
		}
		else
		{	char[] exec = compiler ~" " ~ std.string.join(args," ") ~ " -L-ldl";
			success = !std.c.process.system(toStringz(exec));
		}
		return success;
	}
	

	static void docsPreProcess()
	{	if (verbose)
			writefln("[Pre Processing Docs]");	

		// Clean out any previous docs
		chdir(doc_path);
		char[][] docs = Util.scan(".", [".html"]);
		foreach (char[] doc; docs)
			std.file.remove(doc);
		
		foreach (char[] path; src_path)
		{	if (std.file.exists(path~"/candy.ddoc"))
			{	chdir(path);
				char[] modules = "MODULES = \r\n";
				foreach(char[] src; Util.scan(path, [".d"]))
				{	src = replace(src, mod_path~sep, "");  // Make relative path
					src = split(src, ".")[0];		// remove extension
					src = replace(src, sep, ".");	// replace path separator with dot.
					modules ~= "\t$(MODULE "~src~")\r\n";
				}
				// Create modules.ddoc
				std.file.write("modules.ddoc", modules);
				sources ~= replace(path~"/modules.ddoc", mod_path~sep, "");	// Add newly created modules.ddoc to sources
			}				
		}
	}

	/**
	 * Rename and move documentation files, and delete intermediate candydoc files.*/
	static void docsPostProcess()
	{	if (verbose)
			writefln("[Post Processing Docs]");

		// Move all html files in doc_path to the same folder and rename with the "package.module" naming convention.
		chdir(doc_path);
		char[][] docs = Util.scan(".", [".html"]);
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
			if (std.file.exists(path~"/modules.ddoc"))
				std.file.remove(path~"/modules.ddoc");		
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
			case "-nolink": 	Build.nolink 	= true; break;
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
		writefln("   -gdc       Compile using gdc instead of dmd (has issues).");
		writefln("   -nolink    Compile but do not link.");
		writefln("   -profile   Compile in profiling code.");
		writefln("   -release   Optimize, inline expand functions, and remove unit tests and asserts.");
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
	if (!Build.nolink)
		writefln("`" ~ bin_name ~ bin_ext ~ "' has been placed in '" ~ bin_path ~ "'.");

	// Run
	if (Build.run)
	{	chdir(bin_path);
		std.c.process.system(toStringz(bin_name ~ bin_ext));
		chdir(cur_path);
	}
	
	return 0;
}
