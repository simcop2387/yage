#!dmd -run
/**
 * License: Boost 1.0
 * Copyright (c) 2009-2010 Eric Poggel
 * 
 * This is a customized version of CDC for building Yage. 
 * See the main() function for yage-specific customizations
 * 
 * See: <a href="http://dsource.org/projects/cdc/">The CDC Project</a>
 */

const char[] app = "demo1"; // set which program to build against yage.
//const char[] app = "demo2";
//const char[] app = "demo3";
//const char[] app = "tests/integration/main.d";

/**
 * Use to implement your own custom build script, or pass args on to defaultBuild() 
 * to use this file as a generic build script like bud or rebuild. */
int main(char[][] args)
{	
	// Operate cdc as a generic build script
	//return defaultBuild(args);
	// Commented out, and instead we add custom build instructions for Yage:
	
	// Get platform
	version (Win32)
		char[] platform = "win32";
	version (Win64)
		char[] platform = "win64";
	version (linux)
	{	version (X86)
			char[] platform = "linux32";
		version (X86_64)
			char[] platform = "linux64";
	}
	
	// Parse Options
	char[][] options1;  // options for both derelict and yage
	char[][] options2;  // options for only yage
	bool help, ddoc, verbose, startyage, debug_, lib;
	bool badArg = false;
	foreach (char[] arg; args)
	{	switch(String.toLower(arg))
		{	case "-ddoc": 			ddoc = true; options2 ~= ["-D", "-Dd../doc"]; break;
			case "-debug": 			debug_=true; options1 ~= ["-debug", "-g"]; break;
			case "-lib": 			lib=true; break;
			case "-profile": 		options1 ~= ["-profile"]; break;
			case "-startyage": 		startyage=true; break;
			case "-help":	 		help=true; break;
			case "-verbose": 		verbose=true; break;
			
			/* for linux execution */
			case ".\\buildyage.exe":			
			case "./buildyage":
			case "buildyage":		break;  // These areguments are passed in by default on linux
			default: System.trace("\n" ~ arg ~ " is not a supported argument.\n"); badArg=true;
	}	}
	if (debug_)
		options1 ~= ["-unittest"];
	else
		options1 ~= ["-O", "-inline", "-release"];

	// Show Options
	if (help)
	{
		System.trace("   -ddoc        Generate documentation in the doc folder");
		System.trace("   -debug       Include debugging symbols and enable stack tracing");
		System.trace("                on Windows. Otherwise optimize, inline functions, ");
		System.trace("                and remove unittests/asserts (a release build).");
		System.trace("   -help        Print this message.");
		//System.trace("   -lib         Create a yage lib file in the lib folder.");
		System.trace("   -profile     Compile in profiling code.");
		System.trace("   -startyage   Run when finished.");
		System.trace("   -verbose     Print all commands as they're being executed.");
		System.trace("");
		System.trace("Example:  dmd -run buildyage.d -release -startyage");
		return 0;
	}
	System.trace("");
	System.trace("Use '-help' to get the complete list of options.");
	System.trace("Building Yage...");

	long startTime = System.time();
	
	// Build derelict into a lib if not built.
	char[] debugstr = debug_ ? "-d" : "";
	char[] derelictLib = "../lib/derelict-"~compiler~"-"~platform~debugstr~lib_ext;
	if (!FS.exists(derelictLib))
		CDC.compile(["derelict"], ["-of"~derelictLib, "-lib"] ~ options1, null, "../src", verbose);
	
	// Build derelict.lib and yage source into yage.lib if not built.  Unlike Derelict, this lib is deleted and recreated every build since Yage changes frequently.	
	createEmbeddedResources();
	
	char[] yageLib;
	if (lib) // Compiling yage into a separate lib adds about 40% to the build time
	{	yageLib = "yage-"~compiler~"-"~platform~debugstr~lib_ext;
		CDC.compile(["yage"], ["-of../lib/"~yageLib, "-lib"] ~ options1, null, "../src", verbose);
		CDC.compile([app, yageLib, derelictLib], ["-of../bin/yage3d"] ~ options1 ~ options2, null, "../src", verbose);
	} else
		CDC.compile([app, "yage", derelictLib], ["-of../bin/yage3d"] ~ options1 ~ options2, null, "../src", verbose);
	
	// Remove leftover files.
	foreach (file; ["cdc", "cdc.exe", "cdc.o", "cdc.obj", "cdc.map"])
		FS.remove(file);

	// Print success
	System.trace("The build completed successfully in {} seconds.",  (System.time() - startTime)/1_000f);
	if (lib)
		System.trace(`{} has been placed in ../lib`, yageLib);
	System.trace(`yage3d{} executable has been placed in ../bin`, bin_ext);
	if (ddoc)
		System.trace(`Documentation files have been placed in ../doc`, bin_ext);
	
	if (startyage)
	{	FS.chDir("../bin"); // TODO: allow System.execute to accept relative path
		version(Windows)
			System.execute("yage3d.exe");
		else
			System.execute("./yage3d");
	}
	return 0; // success
}

// Yage-specific function for creating yage/resource/embed/embed.d from other files in the same folder.
void createEmbeddedResources()
{
	// TODO: Only re-embed files if the date changes?
	char[] path = "../src/yage/resource/embed";
	
	char[] source = 
		"module yage.resource.embed.embed;\r\n\r\n"
		"/// Yage's build script generates this struct automatically from the other files in the resource/embed folder."
		"\r\nstruct Embed {\r\n";
	
	foreach (file; FS.listDir(path))
	{
		// Skip the output file
		if (file=="embed.d")
			continue;
		
		char[] contents = cast(char[])FS.read(path~"/"~file);
		char[] encodedContents = "";
		foreach (c; contents)
		{	// Encode as a binary-safe D string
			if (c =='\t')
				encodedContents ~= "\\t";
			else if (c =='\r')
				encodedContents ~= "\\r";
			else if (c =='\n')
				encodedContents ~= "\\n";			
			else if (c=='"' || c=='\\')
				encodedContents ~= "\\"~c;
			else if (c < 32 || 126 < c) // embed invalid utf-8 characters as hex
			{	char[] encode = "0123456789ABCDEF";
				encodedContents ~= "\\x"~encode[c/16]~encode[c%16];
			}
			else
				encodedContents ~= c;			
		}
		
		// Add to the struct as a static member.p
		source ~= "\tstatic char[] " ~ String.replace(String.replace(file, " ", "_"), ".", "_") ~ " = \"" ~
			encodedContents ~ "\"; /// embedded version of "~file~"\r\n";		
	}
	source ~= "}";
	
	FS.write(path ~ "/embed.d", source);
}

/*
 * ----------------------------------------------------------------------------
 * CDC Code, modify with caution
 * ----------------------------------------------------------------------------
 */

// Imports
version(Tango)
{	import tango.core.Array : find;
	import tango.core.Exception : ProcessException;
	import tango.core.Thread;
	import tango.io.device.File;
	import tango.io.FilePath;
	import tango.io.FileScan;
	import tango.io.FileSystem;
	import tango.io.Stdout;
	import tango.sys.Environment;
	import tango.text.convert.Format;
	import tango.text.Regex;
	import tango.text.Util;
	import tango.text.Ascii;
	import tango.time.Clock;
	import tango.util.Convert;
	extern (C) int system(char *);  // Tango's process hangs sometimes
	//import tango.core.tools.TraceExceptions; // enable to get stack trace in buildyage.d on internal failure
} else
{	import std.date;
	import std.string : join, find, replace, tolower;
	import std.stdio : writefln;
	import std.path : sep, getDirName, getName, addExt;
	import std.file : chdir, copy, isdir, isfile, listdir, mkdir, exists, getcwd, remove, write;
	import std.format;
	import std.regexp;
	import std.traits;
	import std.c.process;
	import std.c.time;
}

/// This is always set to the name of the default compiler, which is the compiler used to build cdc.
version (DigitalMars)
	string compiler = "dmd";
version (GNU)
	string compiler = "gdc"; /// ditto
version (LDC)
	string compiler = "ldmd";  /// ditto

version (Windows)
{	const string[] obj_ext = [".obj", ".o"]; /// An array of valid object file extensions for the current.
	const string lib_ext = ".lib"; /// Library extension for the current platform.
	const string bin_ext = ".exe"; /// executable file extension for the current platform.
}
else
{	const string[] obj_ext = [".o"]; /// An array of valid object file extensions for the current.
	const string lib_ext = ".a"; /// Library extension for the current platform.
	const string bin_ext = ""; /// Executable file extension for the current platform.
}

/**
 * Program entry point.  Parse args and run the compiler.*/
int defaultBuild(string[] args)
{	args = args[1..$];// remove self-name from args

	string root;
	string[] options;
	string[] paths;
	string[] run_args;
	bool verbose;

	// Populate options, paths, and run_args from args
	bool run;
	foreach (arg; args)
	{	switch (arg)
		{	case "-verbose": verbose = true; break;
			case "-dmd": compiler = "dmd"; break;
			case "-gdc": compiler = "gdc"; break;
			case "-ldc": compiler = "ldc"; break;
			case "-run": run = true; options~="-run";  break;
			default:
				if (String.starts(arg, "-root"))
				{	root = arg[5..$];
					continue;
				}

				if (arg[0] == '-' && (!run || !paths.length))
					options ~= arg;
				else if (!run || FS.exists(arg))
					paths ~= arg;
				else if (run && paths.length)
					run_args ~= arg;
	}	}

	// Compile
	CDC.compile(paths, options, run_args, root, verbose);

	return 0; // success
}

/**
 * A library for compiling d code.
 * Example:
 * --------
 * // Compile all source files in src/core along with src/main.d, link with all library files in the libs folder,
 * // generate documentation in the docs folder, and then run the resulting executable.
 * CDC.compile(["src/core", "src/main.d", "libs"], ["-D", "-Dddocs", "-run"]);
 * --------
 */
struct CDC
{
	/**
	 * Compile d code using same compiler that compiled CDC.
	 * Params:
	 *     paths = Array of source and library files and folders.  Folders are recursively searched.
	 *     options = Compiler options.
	 *     run_args = If -run is specified, pass these arguments to the generated executable.
	 *     root = Use this folder as the root of all paths, instead of the current folder.  This can be relative or absolute.
	 *     verbose = Print each command before it's executed.
	 * Returns:
	 *     Array of commands that were executed.
	 * TODO: Add a dry run option to just return an array of commands to execute. */
	static string[] compile(string[] paths, string[] options=null, string[] run_args=null, string root=null, bool verbose=false)
	{	Log.operations = null;
		Log.verbose = verbose;

		// Change to root directory and back again when done.
		string cwd = FS.getDir();
		if (root.length)
		{	if (!FS.exists(root))
				throw new Exception(`Directory specified for -root "` ~ root ~ `" doesn't exist.`);
			FS.chDir(root);
		}
		scope(exit)
			if (root.length)
				FS.chDir(cwd);

		// Convert src and lib paths to files
		string[] sources;
		string[] libs;
		string[] ddocs;
		foreach (src; paths)
			if (src.length)
			{	if (!FS.exists(src))
					throw new Exception(`Source file/folder "` ~ src ~ `" does not exist.`);
				if (FS.isDir(src)) // a directory of source or lib files
				{	sources ~= FS.scan(src, [".d"]);
					ddocs ~= FS.scan(src, [".ddoc"]);
					libs ~= FS.scan(src, [lib_ext]);
				} else if (FS.isFile(src)) // a single file
				{
					scope ext = src[String.rfind(src, ".")..$];
					if (".d" == ext)
						sources ~= src;
					else if (lib_ext == ext)
						libs ~= src;
				}
			}

		// Add dl.a for dynamic linking on linux
		version (linux)
			libs ~= ["-L-ldl"];

		// Combine all options, sources, ddocs, and libs
		CompileOptions co = CompileOptions(options, sources);
		options = co.getOptions(compiler);
		if (compiler=="gdc")
			foreach (ref d; ddocs)
				d = "-fdoc-inc="~d;
		else foreach (ref l; libs)
			version (GNU) // or should this only be version(!Windows)
				l = `-L`~l; // TODO: Check in dmd and gdc

		// Create modules.ddoc and add it to array of ddoc's
		if (co.D)
		{	string modules = "MODULES = \r\n";
			sources.sort;
			foreach(string src; sources)
			{	src = String.split(src, "\\.")[0]; // get filename
				src = String.replace(String.replace(src, "/", "."), "\\", ".");
				modules ~= "\t$(MODULE "~src~")\r\n";
			}
			FS.write("modules.ddoc", modules);
			ddocs ~= "modules.ddoc";
			scope(failure) FS.remove("modules.ddoc");
		}
		
		string[] arguments = options ~ sources ~ ddocs ~ libs;

		// Compile
		if (compiler=="gdc")
		{
			// Add support for building libraries to gdc.
			if (co.lib || co.D || co.c) // GDC must build incrementally if creating documentation or a lib.
			{
				// Remove options that we don't want to pass to gcd when building files incrementally.
				string[] incremental_options;
				foreach (option; options)
					if (option!="-lib" && !String.starts(option, "-o"))
						incremental_options ~= option;

				// Compile files individually, outputting full path names
				string[] obj_files;
				foreach(source; sources)
				{	string obj = String.replace(source, "/", ".")[0..$-2]~".o";
					string ddoc = obj[0..$-2];
					if (co.od)
						obj = co.od ~ FS.sep ~ obj;
					obj_files ~= obj;
					string[] exec = incremental_options ~ ["-o"~obj, "-c"] ~ [source];
					if (co.D) // ensure doc files are always fully qualified.
						exec ~= ddocs ~ ["-fdoc-file="~ddoc~".html"];
					System.execute(compiler, exec); // throws ProcessException on compile failure
				}

				// use ar to join the .o files into a lib and cleanup obj files (TODO: how to join on GDC windows?)
				if (co.lib)
				{	FS.remove(co.of); // since ar refuses to overwrite it.
					System.execute("ar", "cq "~ co.of ~ obj_files);
				}

				// Remove obj files if -c or -od not were supplied.
				if (!co.od && !co.c)
					foreach (o; obj_files)
						FS.remove(o);
			}

			if (!co.lib && !co.c)
			{
				// Remove documentation arguments since they were handled above
				string[] nondoc_args;
				foreach (arg; arguments)
					if (!String.starts(arg, "-fdoc") && !String.starts(arg, "-od"))
						nondoc_args ~= arg;

				executeCompiler(compiler, nondoc_args);
			}
		}
		else // (compiler=="dmd" || compiler=="ldc")
		{	
			executeCompiler(compiler, arguments);		
			// Move all html files in doc_path to the doc output folder and rename with the "package.module" naming convention.
			if (co.D)
			{	foreach (string src; sources)
				{	
					if (src[$-2..$] != ".d")
						continue;

					string html = src[0..$-2] ~ ".html";
					string dest = String.replace(String.replace(html, "/", "."), "\\", ".");
					if (co.Dd.length)
					{	
						dest = co.Dd ~ FS.sep ~ dest;
						html = co.Dd ~ FS.sep ~ html;
					}
					if (html != dest) // TODO: Delete remaining folders where source files were placed.
					{	FS.copy(html, dest);
						FS.remove(html);
			}	}	}
		}

		// Remove extra files
		string basename = co.of[String.rfind(co.of, "/")+1..$];
		FS.remove(String.changeExt(basename, ".map"));
		if (co.D)
			FS.remove("modules.ddoc");
		if (co.of && !(co.c || co.od))
			foreach (ext; obj_ext)
				FS.remove(String.changeExt(co.of, ext)); // delete object files with same name as output file that dmd sometimes leaves.

		// If -run is set.
		if (co.run)
		{	System.execute("./" ~ co.of, run_args);
			version(Windows) // Hack: give dmd windows time to release the lock.
				if (compiler=="dmd")
					System.sleep(.1);
			FS.remove(co.of); // just like dmd
		}

		return Log.operations;
	}

	// A wrapper around execute to write compile options to a file, to get around max arg lenghts on Windows.
	private static void executeCompiler(string compiler, string[] arguments)
	{	try {
			version (Windows)
			{	FS.write("compile", String.join(arguments, " "));
				scope(exit)
					FS.remove("compile");
				System.execute(compiler~" ", ["@compile"]);
			} else
				System.execute(compiler, arguments);
		} catch (ProcessException e)
		{	throw new Exception("Compiler failed.");
		}
	}

	/*
	 * Store compilation options that must be handled differently between compilers
	 * This also implicitly enables -of and -op for easier handling. */
	private struct CompileOptions
	{
		bool c;				// do not link
		bool D;				// generate documentation
		string Dd;			// write documentation file to this directory
		string Df;			// write documentation file to this filename
		bool lib;			// generate library rather than object files
		bool o;				// do not write object file
		string od;			// write object & library files to this directory
		string of;			// name of output file.
		bool run;
		string[] run_args;	// run immediately afterward with these arguments.

		private string[] options; // stores modified options.

		/*
		 * Constructor */
		static CompileOptions opCall(string[] options, string[] sources)
		{	CompileOptions result;
			foreach (i, option; options)
			{
				if (option == "-c")
					result.c = true;
				else if (option == "-D" || option == "-fdoc")
					result.D = true;
				else if (String.starts(option, "-Dd"))
					result.Dd = option[3..$];
				else if (String.starts(option, "-fdoc-dir="))
					result.Df = option[10..$];
				else if (String.starts(option, "-Df"))
					result.Df = option[3..$];
				else if (String.starts(option, "-fdoc-file="))
					result.Df = option[11..$];
				else if (option == "-lib")
					result.lib = true;
				else if (option == "-o-" || option=="-fsyntax-only")
					result.o = true;
				else if (String.starts(option, "-of"))
					result.of = option[3..$];
				else if (String.starts(option, "-od"))
					result.od = option[3..$];
				else if (String.starts(option, "-o") && option != "-op")
					result.of = option[2..$];
				else if (option == "-run")
					result.run = true;

				if (option != "-run") // run will be handled specially to allow for it to be used w/ multiple source files.
					result.options ~= option;
			}

			// Set the -o (output filename) flag to the first source file, if not already set.
			string ext = result.lib ? lib_ext : bin_ext; // This matches the default behavior of dmd.
			if (!result.of.length && !result.c && !result.o && sources.length)
			{	result.of = String.split(String.split(sources[0], "/")[$-1], "\\.")[0] ~ ext;
				result.options ~= ("-of" ~ result.of);
			}
			version (Windows)
			{	if (String.find(result.of, ".") <= String.rfind(result.of, "/"))
					result.of ~= bin_ext;

				//Stdout(String.find(result.of, ".")).newline;
			}
			// Exception for conflicting flags
			if (result.run && (result.c || result.o))
				throw new Exception("flags '-c', '-o-', and '-fsyntax-only' conflict with -run");

			return result;
		}

		/*
		 * Translate DMD/LDC compiler options to GDC options.
		 * This function is incomplete. (what about -L? )*/
		string[] getOptions(string compiler)
		{	string[] result = options.dup;

			if (compiler != "gdc")
			{
				version(Windows)
					foreach (ref option; result)
						if (String.starts(option, "-of")) // fix -of with / on Windows
							option = String.replace(option, "/", "\\");

				if (!String.contains(result, "-op"))
					return result ~ ["-op"]; // this ensures ddocs don't overwrite one another.
				return result;
			}

			// is gdc
			string[string] translate;
			translate["-Dd"] = "-fdoc-dir=";
			translate["-Df"] = "-fdoc-file=";
			translate["-debug="] = "-fdebug=";
			translate["-debug"] = "-fdebug"; // will this still get selected?
			translate["-inline"] = "-finline-functions";
			translate["-L"] = "-Wl";
			translate["-lib"] = "";
			translate["-O"] = "-O3";
			translate["-o-"] = "-fsyntax-only";
			translate["-of"] = "-o ";
			translate["-unittest"] = "-funittest";
			translate["-version"] = "-fversion=";
			translate["-w"] = "-wall";

			// Perform option translation
			foreach (ref option; result)
			{	if (String.starts(option, "-od")) // remove unsupported -od
					option = "";
				if (option =="-D")
					option = "-fdoc";
				else
					foreach (before, after; translate) // Options with a direct translation
						if (option.length >= before.length && option[0..before.length] == before)
						{	option = after ~ option[before.length..$];
							break;
						}
			}
			return result;
		}
		unittest {
			string[] sources = [cast(string)"foo.d"];
			string[] options = [cast(string)"-D", "-inline", "-offoo"];
			scope result = CompileOptions(options, sources).getOptions("gdc");
			assert(result[0..3] == [cast(string)"-fdoc", "-finline-functions", "-o foo"]);
		}
	}
}

// Log actions of functions in this module.
private struct Log
{
	static bool verbose;
	static string[] operations;

	static void add(string operation)
	{	if (verbose)
			System.trace("CDC:  " ~ operation);
		operations ~= operation;
	}
}

/// This is a brief, tango/phobos neutral system library.
struct System
{
	/**
	 * Execute execute an arbitrary command-line program and print its output
	 * Params:
	 *     command = The command to execute, e.g. "dmd"
	 *     args = Array of string arguments to pass to this command.
	 * Throws: ProcessException on failure or status code 1.
	 * TODO: Return output (stdout/stderr) instead of directly printing it. */
	static void execute(string command, string[] args=null)
	{	Log.add(command~` `~String.join(args, ` `));
		version (Windows)
			if (String.starts(command, "./"))
				command = command[2..$];

		version (Tango)
		{	/+ // hangs in Tango 0.99.9
			scope p = new Process(true);
			scope(exit)
				p.close();
			p.execute(command, args);

			Stdout.copy(p.stdout).flush; // adds extra line returns?
			Stdout.copy(p.stderr).flush;
			scope result = p.wait();
			if (result.status != Process.Result.Exit)
				throw new ProcessException(result.toString());
			+/

			string execute = command ~ " " ~ String.join(args, " ") ~ "\0";
			int status = system(execute.ptr);
			if (status != 0)
				throw new ProcessException(String.format("Process '%s' exited with status %s", command, status));
		} else		
		{
			command = command ~ " " ~ String.join(args, " ");
			bool success =  !system((command ~ "\0").ptr);
			if (!success)
				throw new ProcessException(String.format("Process '%s' exited with status 1", command));
		}
	}

	/// Get the current number of milliseconds since Jan 1 1970.
	static long time()
	{	version (Tango)
			return Clock.now.unix.millis;
		else
			return getUTCtime();
	}

	/// Print output to the console.  Uses String.format internally and therefor accepts the same arguments.
	static void trace(T...)(string message, T args)
	{	version (Tango)
			Stdout(String.format(message, args)).newline;
		else
			writefln(String.format(message, args));
	}

	/// Sleep for the given number of seconds.
	static void sleep(double seconds)
	{	version (Tango)
			Thread.sleep(seconds);
		else
		{	version (GNU)
				sleep(cast(int)seconds);
			version (D_Version2)
				sleep(cast(int)(seconds/1_000));
			else
				usleep(cast(int)(seconds/1_000_000));
		}
	}
}

/// This is a brief, tango/phobos neutral filesystem library.
struct FS
{
	/// Path separator character of the current platform
	version (Windows)
		static const string sep ="\\";
	else
		static const string sep ="/";

	/// Convert a relative path to an absolute path.
	static string abs(string rel_path)
	{	version (Tango)
			return (new FilePath).absolute(rel_path).toString();
		else
		{	// Remove filename
			string filename;
			int index = rfind(rel_path, FS.sep);
			if (index != -1)
			{   filename = rel_path[index..length];
				rel_path = replace(rel_path, filename, "");
			}

			string cur_path = getcwd();
			try {   // if can't chdir, rel_path is current path.
				chdir(rel_path);
			} catch {};
			string result = getcwd();
			chdir(cur_path);
			return result~filename;
		}
	}

	/// Set the current working directory.
	static void chDir(string path)
	{	Log.add(`cd "`~path~`"`);
		version (Tango)
			Environment.cwd(path);
		else .chdir(path);
	}

	/// Copy a file from source to destination
	static void copy(string source, string destination)
	{	Log.add(`copy "`~source~`" "`~destination~`"`);
		version (Tango)
		{	scope from = new File(source);
			scope to = new File(destination, File.WriteCreate);
			to.output.copy (from);
			to.close;
			from.close;
		}
		else
			.copy(source, destination);
	}

	/// Does a file exist?
	static bool exists(string path)
	{	version (Tango)
			return FilePath(path).exists();
		else return !!.exists(path);
	}

	/// Get the current working directory.
	static string getDir()
	{	version (Tango)
			return Environment.cwd();
		else return getcwd();
	}

	/// Is a path a directory?
	static bool isDir(string path)
	{	version (Tango)
			return FilePath(path).isFolder();
		else return !!.isdir(path);
	}

	/// Is a path a file?
	static bool isFile(string path)
	{	version (Tango)
			return FilePath(path).isFile();
		else return !!.isfile(path);
	}

	/// Get an array of all files/folders in a path.
	/// TODO: Fix with LDC + Tango
	static string[] listDir(string path)
	{	version (Tango)
		{	string[] result;
			foreach (dir; FilePath(path).toList())
				result ~= FilePath(dir.toString()).file();
			return result;
		}
		else return .listdir(path);
	}

	/// Create a directory.  Returns false if the directory already exists.
	static bool mkDir(string path)
	{	if (!FS.exists(path))
		{	version(Tango)
				FilePath(path).create();
			else
				mkdir(path);
			return true;
		}
		return false;
	}

	/// Argument for FS.scan() function.
	static enum ScanMode
	{	FILES = 1, ///
		FOLDERS = 2, ///
		BOTH = 3 ///
	}

	/**
	 * Recursively get all files in directory and subdirectories that have an extension in exts.
	 * This may return files in a different order depending on whether Tango or Phobos is used.
	 * Params:
	 *     directory = Absolute or relative path to the current directory
	 *     exts = Array of extensions to match
	 *     mode = files, folders, or both
	 * Returns: An array of paths (including filename) relative to directory.
	 * BUGS: LDC fails to return any results. */
	static string[] scan(string folder, string[] exts=null, ScanMode mode=ScanMode.FILES)
	{	string[] result;
		if (exts is null)
			exts = [""];
		foreach(string filename; FS.listDir(folder))
		{	string name = folder~"/"~filename; // FS.sep breaks gdc windows.
			if(FS.isDir(name))
				result ~= scan(name, exts, mode);
			if (((mode & ScanMode.FILES) && FS.isFile(name)) || ((mode & ScanMode.FOLDERS) && FS.isDir(name)))
			{	// if filename is longer than ext and filename's extention is ext.
				foreach (string ext; exts)
					if (filename.length>=ext.length && filename[(length-ext.length)..length]==ext)
						result ~= name;
		}	}
		return result;
	}

	/**
	 * Remove a file or a folder along with all files/folders in it.
	 * Params: path = Path to remove, can be a file or folder.
	 * Return: true on success, or false if the path didn't exist. */
	static bool remove(string path)
	{
		Log.add(`remove "`~path~`"`);
		if (!FS.exists(path))
			return false;
		version (Tango)
			FilePath(path).remove();
		else
			.remove(path);
		return true;
	}
	unittest {
		assert (!remove("foo/bar/ding/dong/do.txt")); // a non-existant file
		Log.operations = null;
	}
	
	static ubyte[] read(string filename)
	{	version (Tango)
			return cast(ubyte[])File.get(filename);
		else
			return cast(ubyte[])std.file.read(filename); // wonder if this works
	}

	/// Write a file to disk
	static void write(T)(string filename, T[] data)
	{	scope data2 = String.replace(String.replace(String.replace(data, "\n", "\\n"), "\r", "\\r"), "\t", "\\t");
		Log.add(`write "` ~ filename ~ `" "` ~ data2 ~ `"`);
		version (Tango)
			File.set(filename, data);
		else .write(filename, data);
	}

	// test path functions
	unittest
	{	string path = "_random_path_ZZZZZ";
		if (!FS.exists(path))
		{	assert(FS.mkDir(path));
			assert(FS.exists(path));
			assert(String.contains(FS.listDir("./"), path));
			assert(String.contains(FS.scan("./", null, ScanMode.FOLDERS), path));
			assert(FS.remove(path));
			assert(!FS.exists(path));
	}	}
}

/// This is a brief, tango/phobos neutral string library.
struct String
{
	static string changeExt(string filename, string ext)
	{	version(Tango)
			return FilePath(filename).folder() ~ FilePath(filename).name() ~ ext;
		else
			return addExt(filename, ext[1..$]);
	}
	unittest {
		assert(changeExt("foo.a", "b") == "foo.b");
		assert(changeExt("bar/foo", "b") == "bar/foo.b");
	}

	/// Does haystack contain needle?
	static bool contains(T)(T[] haystack, T needle)
	{	version (Tango)
			return .contains(haystack, needle);
		foreach (straw; haystack)
			if (straw == needle)
				return true;
		return false;
	}

	/// Find the first or last instance of needle in haystack, or -1 if not found.
	static int find(T)(T[] haystack, T[] needle)
	{	if (needle.length > haystack.length)
			return -1;
		for (int i=0; i<haystack.length - needle.length+1; i++)
			if (haystack[i..i+needle.length] == needle)
				return i;
		return -1;
	}
	static int rfind(T)(T[] haystack, T[] needle) /// ditto
	{	if (needle.length > haystack.length)
			return -1;
		for (int i=haystack.length - needle.length-1; i>0; i--)
			if (haystack[i..i+needle.length] == needle)
				return i;
		return -1;
	}
	unittest
	{	assert(find("hello world world.", "wo") == 6);
		assert(find("hello world world.", "world.") == 12);
		assert(rfind("hello world world.", "wo") == 12);
		assert(rfind("hello world world.", "world.") == 12);
	}

	/**
	 * Format variables.
	 * Params:
	 *     message = String to apply formatting.  Use %s for variable replacement.
	 *     args = Variable arguments to insert into message.
	 * Example:
	 * --------
	 * String.format("%s World %s", "Hello", 23); // returns "Hello World 23"
	 * --------
	 */
	static string format(T...)(string message, T args)
	{	version (Tango)
		{	message = substitute(message, "%s", "{}");
			return Format.convert(message, args);
		} else
		{	string swritef(...) // wrapper to convert varargs
			{	string res;
				void putchar(dchar c)
				{   res~= c;
				}
				doFormat(&putchar, _arguments, cast(char*)_argptr);
				return res;
			}
			return swritef(message, args);
	}	}
	unittest {
		assert(String.format("%s World %s", "Hello", 23) == "Hello World 23");
		assert(String.format("foo") == "foo");
	}

	/// Join an array of strings using glue.
	static string join(string[] array, string glue)
	{	return .join(array, glue);
	}

	/// In source, repalce all instances of "find" with "repl".
	static string replace(string source, string find, string repl)
	{	version (Tango)
			return substitute(source, find, repl);
		else return .replace(source, find, repl);
	}

	/// Split an array by the regex pattern.
	static string[] split(string source, string pattern)
	{	version (Tango)
			return Regex(pattern).split(source);
		else return .split(source, pattern);
	}

	/// Does "source" begin with "beginning" ?
	static bool starts(string source, string beginning)
	{	return source.length >= beginning.length && source[0..beginning.length] == beginning;
	}

	/// Get the ascii lower-case version of a string.
	static string toLower(string input)
	{	version (Tango)
			return .toLower(input);
		else return tolower(input);
	}

}

// Define ProcessException in Phobos
version(Tango) {}
else
{	class ProcessException : Exception {
		this(string message) { super(message); }
	};
}