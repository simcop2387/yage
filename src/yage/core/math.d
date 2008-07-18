/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * Math functions not in the standard library.
 */
module yage.core.math;

import std.math;
import std.random;
import std.intrinsic;

public const float PI_180 = 0.01745329251994;	// PI / 180
public const float _180_PI = 57.2957795130823; // 180 / pi


/**
 * Check if two floats are almost equal, that is, they differ no more than
 * fudge from one another, relatively speaking.  If fudge is 0.0001 (the default)
 * Then 10000 and 10001 will compare equally and so will 1.000 and 1.0001; but if
 * either of those differ more, they are not considered equal.  Also,
 * numbers with an absolute difference less than or equal to fudge will always
 * compare equal.  This allows 0.00001 and 0 to be almost equal. */
bool almostEqual(float a, float b, float fudge=0.0001)
{	
	if (fabs(a-b) <= fudge)
		return true;

	if (fabs(b) > fabs(a))
	{	if (fabs((a-b)/b) <= fudge)
			return true;
	}else
		if (fabs((a-b)/b) <= fudge)
			return true;
	return false;
	
	//return fdim(a, b) < fudge;
}
unittest
{	assert(almostEqual(0, 0.0001));
	assert(almostEqual(0, -0.0001));
	assert(almostEqual(1, 1.000099));
	assert(almostEqual(1000, 1000.1));
	assert(!almostEqual(10000, 10001.01));
	//assert(almostEqual(float.infinity, float.infinity));
}


/// Clamp v between l and u
T clamp(T)(T v, T lower, T upper)
{	if (v<lower) return lower;
	if (v>upper) return upper;
	return v;
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


/// Generate a random number between min and max.
float random(float min, float max)
{	return (rand()/4294967296.0f)*(max-min)+min;
}

