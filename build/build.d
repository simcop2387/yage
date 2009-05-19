/**
 * Copyright:  BSD, LGPL, or Public Domain, take your pick
 * Authors:    Eric Poggel
 * Warranty:   none
 *
 * This is an experimental build script for any D project.
 * Unlike Bud or Rebuild, it's extremely lightweight, contained in a single file,
 * and can be run a as a script, allowing maximum portability.
 * All arguments are the same as dmd, except source and lib files can be replaced by source and lib paths, as many as necessary.
 * This also adds the -lib option to gdc
 *
 * If you want to build yage, use build-yage.d
 *
 * Example:
 * dmd -run build.d project/source/folder -ofMyProject.exe
 *
 * Bugs:
 * Hasn't been tested with paths that include spaces, probably need to fix.
 */

import std.c.process;
import std.file;
import std.path;
import std.perf;
import std.stdio;
import tango.text.Util;
import tango.text.convert.Format;

class Build
{
	char[][] sources;
	char[][] ddocs;
	char[][] libs;
	char[][] options;

	const char[][] source_ext = [".d"];
	const char[][] ddoc_ext = [".ddoc"];
	version (Windows)
		const char[][] lib_ext = [".lib", ".obj"];
	else
		const char[][] lib_ext = [".a", ".o"];

	/**
	 * Create a new Build class from command line arguments.
	 * Params:
	 *     arguments = array of source paths, lib paths, and arguments (same as dmd's arguments).	 */
	this(char[][] arguments)
	{	foreach (arg; arguments)
		if (arg.length)
		{	if (arg[0] == '-') // source or lib path
				options ~= arg;
			else
			{	if (isdir(arg)) // a directory of source or lib files
				{	version (GNU) // ddoc has to be added separately for gdc.
					{	sources ~= Util.recls(arg, source_ext);
						ddocs ~= Util.recls(arg, ddoc_ext);
					}
					else
						sources ~= Util.recls(arg, source_ext~ddoc_ext);
					libs ~= Util.recls(arg, lib_ext);
				} else // a single file
				{	auto ext = "."~getExt(arg);
					if (contains(source_ext, ext))
						sources ~= arg;
					else if (contains(lib_ext, ext))
						libs ~= arg;
	}	}	}	}

	bool compile()
	{
		bool success;

		char[] arguments =
			std.string.join(options, " ") ~ " " ~
			std.string.join(sources, " ") ~ " " ~
			std.string.join(libs, " ");

		version (Windows)
		{
			// we write args out to a file in case they're too long for system to execute.
			std.file.write("compile", arguments);
			version (GNU)
			{	/// TODO
			}
			else
			{	success = Util.exec("dmd @compile");
			}
			std.file.remove("compile");
		}
		else
		{
			version (GNU)
			{
				// Add support for building libraries to gdc.
				if (contains(options, "-lib"))
				{
					// Remove options that we don't want to pass to gcd when building files incrementally.
					char[][] gdc_options;
					foreach_reverse (option; options)
						if (option!="-lib" && (option.length >2 && option[0..2] != "-o"))
							gdc_options ~= option;

					// Compile files individually, outputting full path names
					success = true;
					char[][] ofiles;
					foreach(source; sources)
					{	char[] o = substitute(source, sep, "-")[0..length-2]~".o";
						ofiles ~= o;
						char[] exec = "gdc " ~ source ~ " -o " ~ o ~ " -c ";// ~ std.string.join(gdc_options, " ");
						success = success && Util.exec(exec);
						if (!success)
							break;
					}

					// Find the specified by the output option, or use sources[0]
					if (success)
					{	char[] output = sources[0];
						foreach (option; options) // note that gdc accepts -o filename, but this script disallows the space.
							if (option.length >= 2 && option[0..2] == "-o")
								output = option[2..length];

						// use ar to join the .o files into a lib
						success = success && Util.exec("ar cq "~output~" " ~ std.string.join(ofiles, " "));
					}

					// Cleanup .o files
					foreach (o; ofiles)
						if (exists(o))
							std.file.remove(o);

				} else // not gdc -lib
				{	char[] ddoc_args = ddocs.length ? "-fdoc-inc=" ~ std.string.join(ddocs, " -fdoc-inc=") : "";
					char[] exec = "gdc " ~ arguments ~ " -ldl " ~ ddoc_args;

					writefln(exec);
					success = Util.exec(exec);
				}
			}
			else // DMD
			{	//writefln("dmd " ~ arguments ~ " -L-ldl");
				success = Util.exec("dmd " ~ arguments ~ " -L-ldl");
			}
		}
		return success;
	}
}

/**
 * dmd -run build.d src-path1, src-path2, lib-path, ... { -switch }
 * Params:
 *     args =
 */
int main(char[][] args)
{
	// Start timing
	version (Windows)
		alias HighPerformanceCounter PerformanceCounter;
	PerformanceCounter hpc = new PerformanceCounter();
	hpc.start();

	// Compile
	auto build = new Build(args);
	bool success = build.compile();

	// Stop timing
	if (success)
	{	hpc.stop();
		float time = hpc.microseconds()/1000000.0f;
		writefln("The build completed successfully in %.2f seconds.", time);
	} else
		writefln("The build failed.");
	return !success;
}



class Util
{
	static bool exec(char[] command, ...)
	{	command = Format.convert(_arguments, _argptr, command);
		bool success =  !system((command ~ "\0").ptr);
		if (!success)
			throw new Exception(command);
		return true;
	}

	/**
	 * Recursively get all sources in directory and subdirectories that have an extension in exts
	 * @param directory Absolute or relative path to the current directory
	 * @param exts Array of extensions to match
	 * @return An array of paths (including filename) relative to directory. */
	static char[][] recls(char[] directory, char[][] exts)
	{	char[][] result;
		foreach(char[] filename; listdir(directory))
		{	char[] name = directory~sep~filename;
			if(isdir(name))
				result ~= recls(name, exts);
			else if (isfile(name))
			{	// if filename is longer than ext and filename's extention is ext.
				foreach (char[] ext; exts)
					if (filename.length>=ext.length && filename[(length-ext.length)..length]==ext)
					{	char[] t = name;
						if (t[0..2] == "."~sep)
							t = t[2..length];
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
		foreach(char[] filename; listdir(directory))
			if(isdir(directory~sep~filename) && filename[0] != '.')
				result ~= recls(directory~sep~filename);
		return result;
	}
}