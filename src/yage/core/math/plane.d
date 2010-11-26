/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.core.math.plane;

import tango.math.Math;
import tango.text.convert.Format;
import yage.core.math.vector;
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

	///
	void *ptr()
	{	return v.ptr;
	}

	/// Return a string representation of this Plane for human reading.
	char[] toString()
	{	return "{" ~ Format.convert("x: {}, y: {}, z: {}, d: {}", x, y, z, d) ~ "}";
	}
	unittest
	{	assert(Plane().toString() == "{x: 0.00, y: 0.00, z: 0.00, d: 0.00}");		
	}
}
