/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Either <a href="lgpl.txt">LGPL</a> or <a href="zlib-libpng.txt">zlib/libpng</a>
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
extern (C) void *memcpy(void *, void *, uint);

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

unittest
{	assert(almostEqual(0, 0.0001));
	assert(almostEqual(0, -0.0001));
	assert(almostEqual(1, 1.000099));
	assert(almostEqual(1000, 1000.1));
	assert(!almostEqual(10000, 10001.01));
	//assert(almostEqual(float.infinity, float.infinity));
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


/// An improved, D compatible, scanf()
char[] formatString(...)
{	char[] res;
    void putchar(dchar c)
    {	res~= c;
    }
    std.format.doFormat(&putchar, _arguments, _argptr);
    return res;
}


/**
 * Convert a hexadecimal string to an unsigned int.
 * Throws:
 * Exception if hex contains an invalid hexadecimal character. */
uint hexToUint(char[] hex)
{	uint result = 0, digit;
	for (int i=0; i<hex.length; i++)
	{	digit=0;
		if (47 < hex[i] && hex[i] < 58)
			digit = (hex[i]-48);
		else if (64 < hex[i] && hex[i] < 71)
			digit = (hex[i]-55);
		else if (96 < hex[i] && hex[i] < 103)
			digit = (hex[i]-87);
		else
			throw new Exception("Invalid character '" ~ hex[i] ~"' for hexToUint()");
		result+=digit*pow(16, cast(float)hex.length-i-1);;
	}
	return result;
}

/**
 * Convert an array of float color values (0-1) to hexadecimal. */
char[] floatToHex(float[] vec)
{	char[] result;
	foreach (float v; vec)
		result ~= formatString("%.2X", cast(ubyte)(v*255));
	return result;
}
/**
 * Returns the first integer n such that 2^n >= abs(x).
 * input of 9 returns 16 */
uint nextPow2(uint input)
{	return cast(uint)pow(2, ceil(log2(input)));	// a bool shift would be faster.
}

/// Map a value from one range to another
float map(float v, float oldmin, float oldmax, float newmin, float newmax)
{	return ((newmax-newmin)*v/(oldmax-oldmin))+newmin;
}

/// Set the type for the max function.
template maxType(T)
{	/// Return the maximum from an array of type T.
	T max(T[] a ...)
	{	T max=a[0];
		foreach (T x; a)
			if (x>max)
				max=x;
		return max;
	}
}

/// Return the maximum of an the array.
int maxi(int[] a ...)
{	return maxType!(int).max(a);
}
/// ditto
long maxl(long[] a ...)
{	return maxType!(long).max(a);
}
/// ditto
float maxf(float[] a ...)
{	return maxType!(float).max(a);
}
/// ditto
double maxd(double[] a ...)
{	return maxType!(double).max(a);
}

/// Set the type for the max function.
template minType(T)
{	/// Return the maximum from an array of type T.
	T min(T[] a ...)
	{	T min=a[0];
		foreach (T x; a)
			if (x<min)
				min=x;
		return min;
	}
}

/// Return the minimum of an the array.
int mini(int[] a ...)
{	return minType!(int).min(a);
}
/// ditto
long minl(long[] a ...)
{	return minType!(long).min(a);
}
/// ditto
float minf(float[] a ...)
{	return minType!(float).min(a);
}
/// ditto
double mind(double[] a ...)
{	return minType!(double).min(a);
}

/// Clamp v between l and u
float clampf(float v, float lower, float upper)
{	if (v<lower) return lower;
	if (v>upper) return upper;
	return v;
}

/**
 * Convert a string to 0 or 1.
 * "true", "yes", "on", "y", "t", and "1" will all return true,
 * "false", "no", "off", "n", "f", and "0" will all return false,
 * and an Exception is thrown for any other value.*/
bool strToBool(char[] word)
{	switch (tolower(word))
	{	case "true":
		case "yes":
		case "on":
		case "y":
		case "t":
		case "1":
			return true;
		case "false":
		case "no":
		case "off":
		case "n":
		case "f":
		case "0":
			return false;
		default:
			throw new Exception("strToBool() cannot parse '" ~ word ~"'.");
}	}


/// Convert 1 to "true" and 0 to "false".
char[] boolToString(bool a)
{	if (a) return "true";
	return "false";
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

/// Encode characters such as &, <, >, etc. as their xml/html equivalents
char[] xmlEncode(char[] src)
{   char[] tempStr;
	tempStr = replace(src    , "&", "&amp;");
	tempStr = replace(tempStr, "<", "&lt;");
	tempStr = replace(tempStr, ">", "&gt;");
	return tempStr;
}

/// Convert xml-encoded special characters such as &amp;amp; back to &amp;.
char[] xmlDecode(char[] src)
{	char[] tempStr;
	tempStr = replace(src    , "&amp;", "&");
	tempStr = replace(tempStr, "&lt;",  "<");
	tempStr = replace(tempStr, "&gt;",  ">");
	return tempStr;
}

