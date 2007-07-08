/**
 * Copyright:  (c) 2005-2007 Eric Poggel
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

// Just because it's so useful
// extern (C) void *memcpy(void *, void *, uint);

const float PI_180 = 0.01745329251994;	// PI / 180
const float _180_PI = 57.2957795130823; // 180 / pi


/**
 * Allow for easy bool-by-bool conversion from one two-byte type to another.
 * Example:
 * --------------------------------
 * short a;
 * word w;
 * w.s = a;
 * char c = w.c[1];	// c is the second byte of a.
 * --------------------------------*/
union word
{	short s;		/// Union of various types.
	ushort us;		/// ditto
	byte[2] b;		/// ditto
	ubyte[2] ub;	/// ditto
	char[2] c;		/// ditto
	
	/// Convert ushort to word
	static word opApply(ushort us)
	{	word res;
		res.us = us;
		return res;
	}
}

/// Allow for easy bool-by-bool conversion from one four-byte type to another
struct dword
{	union
	{	int i;			/// Union of various types.
		uint ui;		/// ditto
		float f;		/// ditto
		short[2] s;		/// ditto
		ushort[2] us;	/// ditto
		byte[4] b;		/// ditto
		ubyte[4] ub;	/// ditto
		char[4] c;		/// ditto
	}

	/// Convert uint to dword
	static dword opApply(uint ui)
	{	dword res;
		res.ui = ui;
		return res;
	}
}

/// Allow for easy bool-by-bool conversion from one eight-byte type to another.
union qword
{	long l;			/// Union of various types.
	ulong ul;		/// ditto
	double d;		/// ditto
	float[2] f;		/// ditto
	int[2] i;		/// ditto
	uint[2] ui;		/// ditto
	short[4] s;		/// ditto
	ushort[4] us;	/// ditto
	byte[8] b;		/// ditto
	ubyte[8] ub;	/// ditto
	char[8] c;		/// ditto
}

/**
 * Check if two floats are almost equal, that is, they differ no more than
 * fudge from one another, relatively speaking.  If fudge is 0.0001 (the default)
 * Then 10000 and 10001 will compare equally and so will 1.000 and 1.0001; but if
 * either of those differ more, they are not considered equal.  Also,
 * numbers with an absolute difference less than or equal to fudge will always
 * compare equal.  This allows 0.00001 and 0 to be almost equal. */
bool almostEqual(float a, float b, float fudge=0.0001)
{	if (fabs(a-b) <= fudge)
		return true;

	if (fabs(b) > fabs(a))
	{	if (fabs((a-b)/b) <= fudge)
			return true;
	}else
		if (fabs((a-b)/b) <= fudge)
			return true;
	return false;
}
unittest
{	assert(almostEqual(0, 0.0001));
	assert(almostEqual(0, -0.0001));
	assert(almostEqual(1, 1.000099));
	assert(almostEqual(1000, 1000.1));
	assert(!almostEqual(10000, 10001.01));
	//assert(almostEqual(float.infinity, float.infinity));
}

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

/// Clamp v between l and u
T clamp(T)(T v, T lower, T upper)
{	if (v<lower) return lower;
	if (v>upper) return upper;
	return v;
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

/**
 * Returns the first integer n such that 2^n >= input.
 * Example:
 * nextPow2(9); // returns 16 */
uint nextPow2(uint input)
{	if (0 == input)
		return 1;
	int msb = std.intrinsic.bsr(input);	// get first bit set, starting with most significant.
	if ((1 << msb) == input)				// If already equal to a power of two
		return input;
	return 2 << msb;
}
unittest
{	assert(nextPow2(9) == 16);
	assert(nextPow2(1) == 1);	// 2^0 == 1
	assert(nextPow2(16) == 16);
}

/// Map a value from one range to another
float map(float v, float oldmin, float oldmax, float newmin, float newmax)
{	return ((newmax-newmin)*v/(oldmax-oldmin))+newmin;
}


/// Return the maximum of all arguments 
T[0] max(T...)(T a)
{	typeof(a[0]) max = a[0];
	foreach(T x; a)
		if (x>max)
			max = x;
	return max;
}
unittest
{	assert(max(3, 4, -1) == 4);
}

/// Return the minimum of all arguments.
T[0] min(T...)(T a)
{	typeof(a[0]) min = a[0];
	foreach (T x; a)
		if (x<min)
			min = x;
	return min;
}
unittest
{	assert(min(3, 4, -1) == -1);
}


///
long getCPUCount()
{	uint loword, hiword;
	asm
	{	rdtsc;
		mov hiword, EDX;
		mov loword, EAX;
	}
	return ((cast(long)hiword) << 32) + loword;
}


/// Print out the bools that make a 32-bool number
void printBits(void* a)
{	for (int i=31; i>=0; i--)
	{	bool r = cast(bool)(*cast(int*)a & (1<<i));
		printf("%d",r);
	}
	printf("\n");
}

/// Generate a random number between min and max.
float random(float min, float max)
{	return (rand()/4294967296.0f)*(max-min)+min;
}

