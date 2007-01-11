/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Either <a href="lgpl.txt">LGPL</a> or <a href="zlib-libpng.txt">zlib/libpng</a>
 */

module yage.core.plane;

import std.math;
import std.stdio;
import yage.core.freelist;
import yage.core.vector;
import yage.core.misc;


/**
 * A class representing a plane in 3D space.  This is defined as a struct instead of a
 * class so it can be created and destroyed without any dynamic memory allocation.*/
struct Plane
{
	union
	{	float v[4] = [0, 0, 0, 0]; // same as x, y, z, d
		struct
		{	float x, y, z, d;

	}	}

	invariant
	{	foreach (float t; v)
			assert(t != float.nan);
	}

	/// Return a Plane with all values at zero.
	static Plane opCall()
	{	return Plane(0, 0, 0, 0);
	}

	/// Return a Plane with the Vec3f component of n and distance of d.
	static Plane opCall(Vec3f n, float d)
	{	return Plane(n.x, n.y, n.z, d);
	}

	/// Return a Plane with a Vec3f component of x, y, z and distance of d.
	static Plane opCall(float x, float y, float z, float d)
	{	Plane p;
		p.x=x;
		p.y=y;
		p.z=z;
		p.d=d;
		return p;
	}

	/** Get the distance from the center of this plane to the given point.
	 *  This is useful for determining which side of the plane the point is on. */
	float getDistance(Vec3f point)
	{	return v[0]*point.v[0] + v[1]*point.v[1] + v[2]*point.v[2] + v[3];
	}

	/// Normalize the plane.  This should be tested for accuracy.
	Plane normalize()
	{	Plane res;
		float l = 1.0/sqrt(x*x + y*y + z*z);
		// should d be scaled also? is it required for frustum culling?
		return Plane(x*l, y*l, z*l, d*l);
	}

	/// Get the element at i
	float opIndex(ubyte i)
	{	return v[i];
	}

	/// Assign value to the element at i
	float opIndexAssign(float value, ubyte i)
	{	return v[i] = value;
	}

	/// Print the values of this Plane to the standard output.
	void print()
	{	writefln("Plane: ", toString());
	}

	/// Set the values of the plane.
	void set(float _x, float _y, float _z, float distance)
	{	v[0] = _x;  v[1] = _y;  v[2] = _z;
		v[3] = distance;
	}

	/// Set the values of the plane.
	void set(Vec3f normal, float distance)
	{	v[0..3] = normal.v[0..3];
		v[3] = distance;
	}

	/// Set the values of the plane.
	void set(float[] values)
	{	v[0..4] = values[0..4];
	}

	/// Return a string representation of this Plane for human reading.
	char[] toString()
	{	return formatString("<%.4fx %.4fy %.4fz> + %.4f", v[0], v[1], v[2], v[3]);
	}



}
