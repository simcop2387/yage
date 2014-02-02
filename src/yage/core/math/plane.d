/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.core.math.plane;

import tango.math.IEEE;
import tango.math.Math;
import tango.text.convert.Format;
import yage.core.math.vector;
import yage.core.misc;
import std.string;

/**
 * A class representing a plane in 3D space */
struct Plane
{
	union
	{	float v[4] = [0, 0, 0, 0]; // same as x, y, z, d
		struct
		{	float x, y, z, d;
		}
		Vec3f normal;
	}

	invariant()
	{	foreach (float t; v)
		{	assert(!isNaN(t), "Plane has NaN"); // format("<%s>", v));
			assert(t!=float.infinity, "Plane has infinity"); // format("<%s>", v));
		}
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
	
	// Untested, doesn't deal with parallel planes (no instersection)
	Vec3f intersect(Plane plane1, Plane plane2)
	{
		Vec3f cp01 = normal.cross(plane1.normal);
		float det = cp01.dot(plane2.normal);
		
		// Parallel planes, no intersection
		//if (det < 0.0001)
		//	return false;
		
		Vec3f cp12 = plane1.normal.cross(plane1.normal) * d;
		Vec3f cp20 = plane2.normal.cross(normal) * plane1.d;
		
		return cp12 + cp20 + (cp01*plane2.d) / det;
	}

	/// Normalize the plane.  TODO:  This should be tested for accuracy.
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

	///
	void *ptr()
	{	return v.ptr;
	}

	/// Return a string representation of this Plane for human reading.
	string toString()
	{	return std.string.format("x: %f, y: %f, z: %f, d: %f", x, y, z, d); 
	}
	unittest
	{	assert(Plane().toString() == "{x: 0.00, y: 0.00, z: 0.00, d: 0.00}");		
	}
}
