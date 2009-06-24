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
	// Show Options
	Stdout("Building Yage...");
	{	Stdout("If you're curious, the options are:").newline;
		Stdout("   -ddoc      Generate documentation in doc/api").newline;
		Stdout("   -debug     Include debugging symbols.").newline;
		Stdout("   -profile   Compile in profiling code.").newline;
		Stdout("   -release   Optimize, inline expand functions, and remove unit tests/asserts.").newline;
		Stdout("   -run       Run when finished.").newline;		
		Stdout("   -verbose   Print all commands as they're being executed.").newline;
		Stdout("Example:  dmd -run buildyage.d -release -run").newline;
	}
	
	// Parse Options
	char[][] options1;
	char[][] options2;
	foreach (char[] arg; args)
	{	switch(toLower(arg))
		{	case "-ddoc": 		options2 ~= ["-D -Dd../doc/api"]; break;
			case "-debug": 		options1 ~= ["-debug"];; break;
			case "-profile": 	options1 ~= ["-profile"]; break;
			case "-release": 	options2 ~= ["-O", "-inline", "-release"]; break;
			case "-run": 		options2 ~= ["-run"]; break;
			case "-verbose": 	options1 ~= ["-verbose"]; break;
			default: break;
	}	}
	
	// create cdc
	execute(compiler, ["cdc.d"]);
	StopWatch timer;
	timer.start();

	// Build derelict if not built.
	char[] derelict = "../lib/derelict-"~compiler~"-"~platform~lib_ext;
	if (!FilePath(derelict).exists())
		execute("./cdc", ["-root../src", "-of"~derelict, "-lib", "derelict"] ~ options1);

	// Build yage
	execute("./cdc", ["-root../src", "-of../bin/yage3d", "yage", "demo1", derelict] ~ options1 ~ options2);

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
void execute(char[] command, char[][] args=null)
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
	if (result.status)
		throw new Exception("Building Yage failed!");
}

