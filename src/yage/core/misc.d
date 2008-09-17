/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * Miscellaneous core types, functions, and templates that have no other place.
 */

module yage.core.misc;

import std.file;
import std.math;
import std.path;
import std.random;
import std.string;
import std.stdio;

/// Given relative path rel_path, returns an absolute path.
char[] absPath(char[] rel_path)
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

/**
 * Resolve "../", "./", "//" and other redirections from any path.
 * This function also ensures correct use of path separators for the current platform.*/
char[] cleanPath(char[] path)
{	char[] sep = "/";

	path = replace(path, "\\", sep);
	path = replace(path, sep~"."~sep, sep);		// remove "./"

	char[][] paths = std.string.split(path, sep);
	char[][] result;

	foreach (char[] token; paths)
	{	switch (token)
		{	case "":
				break;
			case "..":
				if (result.length)
				{	result.length = result.length-1;
					break;
				}
			default:
				result~= token;
		}
	}
	path = std.string.join(result, sep);
	delete paths;
	delete result;
	return path;
}

/// Probaly won't work on multicore machines.
long getCPUCount()
{	uint loword, hiword;
	asm
	{	rdtsc;
		mov hiword, EDX;
		mov loword, EAX;
	}
	return ((cast(long)hiword) << 32) + loword;
}


/// Print out the bits that make a 32-bit number
void printBits(void* a)
{	for (int i=31; i>=0; i--)
	{	bool r = cast(bool)(*cast(int*)a & (1<<i));
		printf("%d",r);
	}
	printf("\n");
}
