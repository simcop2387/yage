#!~/bin/dmd -run
/**
 * Authors: Eric Poggel
 * Date: October 16, 2006
 * Copyright: Public Domain
 * Warranty: none
 *
 * Builds the yage game engine and optionally the html documentation, but
 * feel free to use this script for whatever.
 *
 * Examples:
 * ------
 * dmd -run buildme.d -release -clean -ddoc -run
 * dmd -run buildme.d -gdc
 * ------
 *
 * TODO:
 * Test on Linux.
 */

import std.c.process;
import std.stdio;
import std.file;
import std.path;
import std.perf;
import std.string;

version (Windows)
{	alias HighPerformanceCounter PerformanceCounter;
}

// Set options for compilation.
// Paths are relative to the build script.
char[] src_path = "../src";			// Path to .d source files
char[] imp_path = "../src";			// Semicolon delimited list of paths to look for imports
char[] ign_path = "../src/derelict";// Semicolon delimited list of paths to exclude source files
char[] lib_path = "../lib";			// libraries and library "headers"
char[] obj_path = "../bin/obj";		// temporary directory for object files
char[] bin_path = "../bin";			// folder where executable binary will be placed
char[] bin_name = "yage";			// executable binary name
char[] doc_path = "../doc/api";	// folder for html documentation, if ddoc flag is set
char[] cur_path;					// Path of this script, set automatically

// Options
bool _debug, _release, nolink, profile, ddoc, _clean, verbose, run, gdc;

// OS dependant strings
version (Windows)
{	char[] bin_ext = ".exe";
	char[] lib_ext = ".lib";
}else
{	char[] bin_ext = "";
	char[] lib_ext = ".a";
}

// Return the full path of all files in directory and all subdirectories with extension ext
char[][] scan(char[] directory, char[] ext)
{	char[][] res;
	foreach(char[] filename; listdir(directory))
	{	if(isdir(directory~sep~filename))
			res ~= scan(directory~sep~filename, ext);
		else if (isfile(directory~sep~filename))
		{	// if filename is longer than ext and filename's extention is ext.
			if (filename.length>=ext.length && filename[(length-ext.length)..length]==ext)
			{	char[] t = directory~sep~filename;
				if (t[0..2] == "."~sep)
					t = t[2..length];
				res~= t;
		}	}
	}
	return res;
}

// Return all directories in a path, except hidden ones
char[][] recls(char[] directory=".")
{	char[][] result;
	result ~= directory;
	foreach(char[] filename; listdir(directory))
	{	if(isdir(directory~sep~filename) && filename[0]!='.')
			result ~= recls(directory~sep~filename);
	}
	return result;
}

/// Given relative path rel_path, returns an absolute path.
char[] abs_path(char[] rel_path)
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

// Get all source files, ignoring those in the ignore path
char[][] getSources(bool include_ddoc=false)
{	// Get sources minus the ignore directory.
	char[][] all = scan(".", ".d");
	if (include_ddoc)
		all ~= scan(".", ".ddoc");
	char[][] sources;
	foreach(char[] src; all)
		if (find(abs_path(src), ign_path)== -1)
			sources ~= src;
	return sources;
}

// Delete all object files
void clean()
{	if (verbose)
		writefln("[Cleaning]");	

	// Remove all intermediate files
	char[][] files = scan(obj_path, ".obj")~scan(obj_path, ".o")~scan(obj_path, ".map")~scan(obj_path, bin_ext);
	foreach(char[] file; files)
		//try {
			std.file.remove(file);
		//} catch {}

	// Remove all intermediate folders
	char[][] folders = recls(obj_path);
	for(int i=folders.length-1; i>-0; i--)
		//try {
			rmdir(folders[i]);
		//} catch {}
}

// Compile sources in src_path to objects in obj_path
bool compile(bool _debug=false, bool _release=false, bool profile=false, bool ddoc=false, bool verbose=false)
{	if (verbose)
		writefln("[Compiling]");
		
	// Get the source files and set compiler flags
	chdir(src_path);

	// Get sources minus the ignore directory.
	char[][] sources = getSources(ddoc);
	char[][] libs = scan(lib_path, lib_ext);
	char[][] flags;
	if (gdc)
	{	if (_debug)
		{	flags~="fdebug";
			flags~="g";
		}
		else if (_release)
		{	flags~="O3";
			flags~="finline";
			flags~="frelease";
		}
		if (profile)
			flags~="profile";
		if (ddoc)
		{	flags~="fdoc";
			flags~="fdoc-dir"~doc_path;
		}
		if (!_release)
			flags~="funittest";
		flags~="I"~imp_path;
		//flags~="od"~obj_path;			// Set the object output directory
		//flags~="op";					// Preserve path of object files, otherwise duplicate names will overwrite one another!
		flags~="o"~bin_name~bin_ext;	// output filename
	
	}
	else
	{	if (_debug)
		{	flags~="debug";
			flags~="g";

		}
		else if (_release)
		{	flags~="O";
			flags~="inline";
			flags~="release";
		}
		if (profile)
			flags~="profile";
		if (ddoc)
		{	flags~="D";
			flags~="Dd"~doc_path;
		}
		if (!_release)
			flags~="unittest";
		flags~="I"~imp_path;
		flags~="od"~obj_path;	// Set the object output directory
		flags~="op";			// Preserve path of object files, otherwise duplicate names will !
		flags~="of"~bin_name~bin_ext;	// output filename
		flags~="quiet";
	}
	if (nolink)
		flags~="c";				// do not link		

	// Create folders for the documentation
	if (ddoc)
	{	char[][] paths = recls();
		foreach (char[] path; paths)
		{	path = doc_path~sep~path;
			if (!exists(path))
				mkdir(path);
	}	}

	char[] compiler = gdc ? "gdc" : "dmd";
	char[] compile = compiler ~ " -" ~ std.string.join(flags, " -") ~ " " ~ std.string.join(sources, " ") ~ " " ~ std.string.join(libs, " ");
	if (verbose)
		writefln(compile);
		
	bool success = !system(toStringz(compile));
	return success;
}

void docsPreProcess()
{	if (verbose)
		writefln("[Pre Processing Docs]");	

	// Clean out any previous docs
	chdir(doc_path);
	char[][] docs = scan(".", ".html");
	foreach (char[] doc; docs)
		std.file.remove(doc);

	// Build modules file for candydoc
	chdir(src_path);
	char[] modules = "MODULES = \r\n";
	char[][] sources = getSources();
	foreach(inout char[] src; sources)
	{	src = split(src, ".")[0];		// remove extension
		src = replace(src, sep, ".");	// replace path separator with dot.
		modules ~= "\t$(MODULE "~src~")\r\n";
	}
	// Create modules.ddoc
	std.file.write("modules.ddoc", modules);
}

/**
 * Rename and move documentation files, and delete intermediate candydoc files.*/
void docsPostProcess()
{	if (verbose)
		writefln("[Post Processing Docs]");

	// Move all html files in doc_path to the same folder and rename with the "package.module" naming convention.
	chdir(doc_path);
	char[][] docs = scan(".", ".html");
	foreach (char[] doc; docs)
	{	char[] dest = replace(doc, sep, ".");
		if (doc != dest)
		{	copy(doc, dest);
			std.file.remove(doc);
		}
	}

	// Delete all intermediate folders except the candydoc folder
	char[][] folders = recls(doc_path);
	for(int i=folders.length-1; i>-0; i--)
	{	// Only delete if empty
		if (listdir(folders[i]).length == 0)
			rmdir(folders[i]);
	}

	// Delete modules.ddoc
	chdir(src_path);
	std.file.remove("modules.ddoc");
}

int main(char[][] args)
{	writefln("Building Yage...");
	writefln("If you're curious, the options are:");
	writefln("   -clean     Delete all intermediate object files.");
	writefln("   -ddoc      Generate documentation in "~doc_path);
	writefln("   -debug     Include debugging symbols.");
	writefln("   -gdc       Compile using gdc instead of dmd (incomplete).");
	writefln("   -nolink    Compile but do not link.");
	writefln("   -profile   Compile in profiling code.");
	writefln("   -release   Optimize, inline expand functions, and remove unit tests and asserts.");
	writefln("   -run       Run when finished.");
	writefln("   -verbose   Print all commands as they're being executed.");
	writefln("Example:  dmd -run buildme.d -clean -release -run");

	// Create the paths we write to if they don't exist
	if (!exists(bin_path))	mkdir(bin_path);
	if (!exists(obj_path))	mkdir(obj_path);
	if (!exists(doc_path))	mkdir(doc_path);

	// Create absolute paths
	cur_path = getcwd();
	src_path = abs_path(src_path);
	imp_path = abs_path(imp_path);
	ign_path = abs_path(ign_path);
	lib_path = abs_path(lib_path);
	obj_path = abs_path(obj_path);
	bin_path = abs_path(bin_path);
	doc_path = abs_path(doc_path);

	// Parse arguments
	foreach (char[] arg; args)
	{	switch(tolower(arg))
		{	case "-debug": _debug = true; break;
			case "-release": _release = true; break;
			case "-profile": profile = true; break;
			case "-ddoc": ddoc = true; break;
			case "-clean": _clean = true; break;
			case "-nolink": nolink = true; break;
			case "-run": run = true; break;
			case "-verbose": verbose = true; break;
			case "-gdc": gdc = true; break;
			default: break;
		}
	}
	
	// Start timing
	PerformanceCounter hpc = new PerformanceCounter();
	hpc.start();
	
	// Clean
	clean();

	// Clean docs and generate candydoc module
	try
	{	if (ddoc)
			docsPreProcess();
	} catch (Exception e)
	{	writefln(e);
		writefln("Error with optional documentation step.  Continuing.");
	}

	// Compile
	if (!compile(_debug, _release, profile, ddoc, verbose))
	{	writefln("Compile failed.  Please fix the errors and try again.");
		return 1;
	}

	// Move the output files
	if (!nolink)
	{	// Executable binary
		char[] target = bin_path~sep~bin_name~bin_ext;
		if (std.file.exists(target))
			std.file.remove(target); // remove old binary
		std.file.rename(src_path~sep~bin_name~bin_ext, target);
		
		// .map
		target = obj_path~sep~bin_name~".map";
		if (std.file.exists(target))
			std.file.remove(target); // remove old binary
		std.file.rename(src_path~sep~bin_name~".map", target);
	}

	// Move Docs
	try
	{	if (ddoc)
			docsPostProcess();
	} catch (Exception e)
	{	writefln(e);
		writefln("Error with optional documentation step.  Continuing.");
	}

	// Clean
	try
	{	if (_clean)
			clean();
	} catch (Exception e)
	{	writefln(e);
		writefln("Error with optional clean step.  Continuing.");
	}

	// Completed message and time
	hpc.stop();
	float time = hpc.microseconds()/1000000.0f;
	writefln("The build completed successfully in %.2f seconds.", time);
	if (!nolink)
		writefln("`" ~ bin_name ~ bin_ext ~ "' has been placed in '" ~ bin_path ~ "'.");

	// Run
	if (run)
	{	chdir(bin_path);
		system(toStringz(bin_name ~ bin_ext));
		chdir(cur_path);
	}

	return 0;
}