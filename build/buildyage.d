#!dmd -run
/**
 * Copyright:  Public Domain
 * Authors:    Eric Poggel
 * Warranty:   none
 *
 * Builds the yage game engine and optionally the html documentation, using cdc.
 *
 * It first builds derelict into a lib if it hasn't already been,
 * and then builds the rest of yage, linking with it.
 */

import tango.io.Stdout;
import tango.io.FilePath;
import tango.sys.Process;
import tango.text.Ascii;
import tango.text.Util;
import tango.time.StopWatch;

const char[] app = "demo1"; // change to the demo to run.

// Get compiler
version (DigitalMars)
	char[] compiler = "dmd";
version (GNU)
	char[] compiler = "gdc";
version (LDC)
	char[] compiler = "ldc";

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

// Get extensions
version (Windows)
{	char[] bin_ext = ".exe";
	char[] lib_ext = ".lib";
}
else
{	char[] bin_ext = "";
	char[] lib_ext = ".a";
}

// Program entry point
int main(char[][] args)
{
	// Parse Options
	char[][] options1;	// options for both derelict and yage
	char[][] options2;  // options for only yage
	bool silent;
	bool release;
	foreach (char[] arg; args)
	{	switch(toLower(arg))
		{	case "-ddoc": 		options2 ~= ["-D -Dd../doc/api"]; break;
			case "-debug": 		options1 ~= ["-debug"]; break;
			case "-profile": 	options1 ~= ["-profile"]; break;
			case "-release": 	options2 ~= ["-O", "-inline", "-release"]; release = true; break;
			case "-run": 		options2 ~= ["-run"]; break;
			case "-silent": 	silent=true; break;
			case "-verbose": 	options1 ~= ["-verbose"]; break;
			default: break;
	}	}
	if (!release)
		options1 ~= ["-unittest"];

	// Show Options
	if (!silent)
	{	Stdout("Building Yage...");
		Stdout("If you're curious, the options are:").newline;
		Stdout("   -ddoc      Generate documentation in doc/api").newline;
		Stdout("   -debug     Include debugging symbols.").newline;
		Stdout("   -profile   Compile in profiling code.").newline;
		Stdout("   -release   Optimize, inline expand functions, and remove unit tests/asserts.").newline;
		Stdout("   -run       Run when finished.").newline;
		Stdout("   -silent    Don't print this message.").newline;
		Stdout("   -verbose   Print all commands as they're being executed.").newline;
		Stdout("Example:  dmd -run buildyage.d -release -run").newline;
	}

	// create cdc
	if (!execute(compiler, ["cdc.d"]))
		return 1;
	StopWatch timer;
	timer.start();

	// Build derelict if not built.
	char[] derelict = "../lib/derelict-"~compiler~"-"~platform~lib_ext;
	if (!FilePath(derelict).exists())
		if (!execute("./cdc", ["-root../src", "-of"~derelict, "-lib", "derelict"] ~ options1))
			return 1;

	// Build yage
	if (!execute("./cdc", ["-root../src", "-of../bin/yage3d", "yage", app, derelict] ~ options1 ~ options2))
		return 1;

	// Remove leftover files.
	foreach (file; ["cdc", "cdc.exe", "cdc.o", "cdc.obj", "cdc.map"])
		if (FilePath(file).exists())
			FilePath(file).remove();

	// Print success
	Stdout.formatln("The build completed successfully in {} seconds.",  timer.microsec()/1_000_000f);
	Stdout.formatln(`yage3d{} has been placed in ../bin`, bin_ext);

	return 0; // success
}

/**
 * Execute execute an arbitrary command-line program and print its output. */
bool execute(char[] command, char[][] args=null)
{
	Stdout(command ~ " " ~ args.join(" ")).newline;

	// Does "source" begin with "beginning" ?
	bool starts(char[] source, char[] beginning)
	{	return source.length >= beginning.length && source[0..beginning.length] == beginning;
	}

	version (Windows)
		if (starts(command, "./"))
			command = command[2..$];

	scope p = new Process();
	p.copyEnv(true);
	p.args(command, args);
	p.execute();

	Stdout.copy(p.stdout).flush;
	Stdout.copy(p.stderr).flush;

	scope result = p.wait();
	return !result.status;
	
}

