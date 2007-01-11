/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Either <a href="lgpl.txt">LGPL</a> or <a href="zlib-libpng.txt">zlib/libpng</a>
 */

module yage.core.vector;

import std.math;
import std.stdio;
import yage.core.matrix;
import yage.core.quatrn;
import yage.core.misc;


/**
 * This is a template to create a vector of any type with any number of elements.
 * Use Vec.v[0..n] to access the vector's elements directly, or a-d to access
 * elements of vector's of size less than or equal to four.
 * Example:
 * --------------------------------
 * Vec!(real, 4) a; // a is a four-component real vector.
 * --------------------------------*/
struct Vec(T, int K)
{	union
	{	T v[K] = 0; // same as x, y, z, etc.
		static if(K==2)
		{	struct { T x, y; }
			struct { T a, b; }
		}
		static if(K==3)
		{	struct { T x, y, z; }
			struct { T a, b, c; }
		}
		static if(K==4)
		{	struct { T a, b, c, d; }
		}
	}

	/// Create a zero vector
	static Vec!(T, K) opCall()
	{	Vec!(T, K) res;
		return res;
	}

	/// Create a vector with all values as s.
	static Vec!(T, K) opCall(T s)
	{	Vec!(T, K) res;
		foreach(inout T e; res.v)
			e = s;
		return res;
	}

	/// Create a new vector with the values s0, s1, s2, ...
	static Vec!(T, K) opCall(T[] s ...)
	{	assert(s.length==K);
		Vec!(T, K) res;
		res.v[0..K] = s[0..K];
		return res;
	}

	/// Create a new vector with the values of s; s must be at least of length 3.
	static Vec!(T, K) opCall(T[] s)
	{	assert(s.length>=K);
		Vec!(T, K) res;
		res.v[0..K] = s[0..K];
		return res;
	}

	/// The _angle between this vector and s, in radians.
	float angle(Vec!(T, K) s)
	{	return acos(dot(s)/(length()*s.length()));
	}

	/// Return the _dot product of this vector and s.
	float dot(Vec!(T, K) s)
	{	float res=0;
		for (int i=0; i<v.length; i++)
			res += v[i]*s.v[i];
		return res;
	}

	/// Return the _length of the vector (the magnitude).
	float length()
	{	return sqrt(length2());
	}

	/// Return the length of the vector squared.  This is faster than length().
	float length2()
	{	T sum = 0;
		foreach (T c; v)
			sum += c*c;
		return sum;
	}

	/// Get the element at i
	float opIndex(ubyte i)
	{	return v[i];
	}

	/// Assign value to the element at i
	float opIndexAssign(T value, ubyte i)
	{	return v[i] = value;
	}

	/// Create a new vector with the values of s; s must be at least of length 3.
	Vec!(T, K) projection(Vec!(T, K) s)
	{	return s.scale(dot(s)/s.length2());
	}

	/// Scale this vector by the values of another vector.
	Vec!(T, K) scale(float s)
	{	Vec!(T, K) res = *this;
		for (int i=0; i<v.length; i++)
			res.v[i] *= s;
		return res;
	}

	void set(Vec!(T, K) s)
	{	v[0..K] = s.v[0..K];
	}

	/// Create a new vector with the values s0, s1, s2, ...
	void set(T[] s ...)
	{	assert(s.length==K);
		v[0..K] = s[0..K];
	}

	/// Return a string representation of this vector for human reading.
	char[] toString()
	{	char[] result = "<";
		for (int i=0; i<K; i++)
			result ~= formatString("%.4f ", v[i]);
		result ~= ">";
		return result;
	}
}

alias Vec!(int, 2) Vec2i;		/// A two-component int Vec
alias Vec!(int, 3) Vec3i;		/// A three-component int Vec
alias Vec!(int, 4) Vec4i;		/// A four-component int Vec
alias Vec!(float, 2) Vec2f;		/// A two-component float Vec
//alias Vec3f Vec3f;			// Defined below
alias Vec!(float, 4) Vec4f;		/// A four-component float Vec

/**
 * A 3D vector class.  This is defined as a struct instead of a
 * class so it can be created and destroyed without dynamic memory allocation.
 * This is a higher-performance version of Vec (although it hasn't been profiled).
 * This may be merged with Vec in the future. */
struct Vec3f
{
	union
	{	float v[3] = [0, 0, 0]; // same as x, y, and z
		struct
		{	float x, y, z;
	}	}

	invariant
	{	foreach (float t; v)
			assert(t != float.nan);
	}

	/** Test some of the more common and more complex functions. */
	unittest
	{
		// Perform a test and report
		void test(char[] name, Vec3f[] args ...)
		{	char[] report = "\nFailed on test '"~name~"' With Vec3fs:\n";
			foreach(Vec3f a; args)
				report ~= a.toString()~"\n";
			assert(args[0].almostEqual(args[1]), report);
		}

		// Vectors along all axis and in all quadrants to test
		Vec3f[13] v;
		v[ 0] = Vec3f(0, 0, 0);
		v[ 1] = Vec3f(1, 0, 0);
		v[ 2] = Vec3f(0, 1, 0);
		v[ 3] = Vec3f(0, 0, 1);
		v[ 4] = Vec3f(.5, 0.0001, 2);
		v[ 5] = Vec3f(.5, 1, -2);
		v[ 6] = Vec3f(.5, -1, -2);
		v[ 7] = Vec3f(-.75, -1, -1.7);
		v[ 8] = Vec3f(-.65, -1, 2);
		v[ 9] = Vec3f(-.55, 0.005, 1);
		v[10] = Vec3f(-.371, .1, -1.570796);
		v[11] = Vec3f(1.971, -2, 1.2);
		v[12] = Vec3f(0.0001, 0.0001, 0.0001);

		// Tests for each type of vector
		foreach (Vec3f c; v)
		{	test("toQuatrn", c.toQuatrn().toAxis(), c);
			test("toMatrix", c.toMatrix().toAxis(), c);
			test("Length", c.length(c.length()), c);
			test("Scale", c.scale(4).scale(.25), c);
			test("Divide", (c*3)/3, c);

			// Rotate every vector by every other and then reverse, in 3 different ways.
			foreach (Vec3f d; v)
			{	test("Rotate Axis", c.rotate(d).rotate(d.inverse()), c, d);
				test("Rotate Matrix", c.rotate(d.toMatrix()).rotate(d.toMatrix().inverse()), c, d);
				test("Rotate Quatrn", c.rotate(d.toQuatrn()).rotate(d.toQuatrn().inverse()), c, d);
				test("Add & Subtract", (c+d-d).add(d).subtract(d), c, d);
				test("Cross Product", c.cross(d), d.inverse().cross(c), c, d);
				test("Dot Product", c.scale(c.dot(d)), c.scale(c.x*d.x+c.y*d.y+c.z*d.z));
				test("Distance", c.scale(c.distance(d)), c.scale(sqrt((c.x-d.x)*(c.x-d.x) + (c.y-d.y)*(c.y-d.y) + (c.z-d.z)*(c.z-d.z))));
			}
		}
	}

	/// Create a zero vector
	static Vec3f opCall()
	{	Vec3f res;
		return res;
	}

	/// Create a Vec3f with all values as s.
	static Vec3f opCall(float s)
	{	return Vec3f(s, s, s);
	}

	/// Create a new Vec3f with the values x, y, and z
	static Vec3f opCall(float x, float y, float z)
	{	Vec3f res=void;
		res.x = x;
		res.y = y;
		res.z = z;
		return res;
	}

	/// Return a vector with the values of s; s must be at least of length 3.
	static Vec3f opCall(float[] s)
	{	assert(s.length>=3);
		return Vec3f(s[0], s[1], s[2]);
	}

	/// Return a vector containing the absolute value of each component
	Vec3f abs()
	{	return Vec3f(x>0?x:-x, y>0?y:-y, z>0?z:-z);
	}

	/// Add another vector into this vector
	Vec3f add(Vec3f s)
	{	return Vec3f(x+s.x, y+s.y, z+s.z);
	}

	/// Is this vector equal to vector s, discarding relative error fudge.
	bool almostEqual(Vec3f s, float fudge=0.0001)
	{	for (int i=0; i<v.length; i++)
			if (!yage.core.misc.almostEqual(v[i], s.v[i], fudge))
				return false;
		return true;
	}

	/// Return the average of the x, y, and z components.
	float average()
	{	return (x+y+z)*0.3333333333f;
	}

	///
	Vec3f clamp(float l, float u)
	{	return Vec3f(clampf(x, l, u), clampf(y, l, u), clampf(z, l, u));
	}

	/// Return the cross product of this vector with another vector.
	Vec3f cross(Vec3f s)
	{	return Vec3f(y*s.z-z*s.y, z*s.x-x*s.z, x*s.y-y*s.x);
	}

	/// Return the dot product of this vector and another.
	float dot(Vec3f s)
	{	return x*s.x + y*s.y + z*s.z;
	}

	/// Return the distance from this vector to another, interpreting each as 3D coordinates.
	float distance(Vec3f s)
	{	return sqrt(distance2(s));
	}

	/// Return the square of the distance from this Vec3f to another, interpreting each as 3D coordinates.
	float distance2(Vec3f s)
	{	return (x-s.x)*(x-s.x) + (y-s.y)*(y-s.y) + (z-s.z)*(z-s.z);
	}

	/// Return a vector with every value of this Vec3f negated.
	Vec3f inverse()
	{	return Vec3f(-x, -y, -z);
	}

	/// Return the length of the vector (the magnitude).
	float length()
	{	return sqrt(x*x + y*y + z*z);
	}

	/// Return the length of the vector squared.  This is faster than length().
	float length2()
	{	return x*x+y*y+z*z;
	}

	/// Return a copy of this vector scaled to length l.
	Vec3f length(float l)
	{	if (l==0) // otherwise, setting the length of a zero vector to zero fails.
			return Vec3f(0, 0, 0);
		return scale(l/sqrt(x*x + y*y + z*z));
	}

	/// Return the maximum value of the vector components
	float max()
	{	if (x>=y && x>=z) return x;
		if (y>=z) return y;
		return z;
	}

	/// Return a normalized copy of this vector.
	Vec3f normalize()
	{	float l = length();
		if (l!=0)
			return scale(1/sqrt(x*x + y*y + z*z));
		return Vec3f(0, 0, 0);
	}

	/// Return the sum of this vector and another.
	Vec3f opAdd(Vec3f s)
	{	return Vec3f(x+s.x, y+s.y, z+s.z);
	}

	/// Add the values of another Vec3f into this one.
	Vec3f opAddAssign(Vec3f s)
	{	x+=s.x, y+=s.y, z+=s.z;
		return *this;
	}

	/// Return a copy of this vector with every value divided by s.
	Vec3f opDiv(float s)
	{	s=1/s;
		return Vec3f(x*s, y*s, z*s);
	}

	/// Divide every value of this vector by s.
	Vec3f opDivAssign(float s)
	{	scale(1/s);
		return *this;
	}

	/// Get the element at i
	float opIndex(ubyte i)
	{	return v[i];
	}

	/// Assign value to the element at i
	float opIndexAssign(float value, ubyte i)
	{	return v[i] = value;
	}

	/// Return a copy of this vector with every value multiplied by s.
	Vec3f opMul(float s)
	{	return Vec3f(x*s, y*s, z*s);
	}

	/// Multiply every value of this vector by s.
	Vec3f opMulAssign(float s)
	{	scale(s);
		return *this;
	}

	/// Return a vector with every value of this vector negated.
	Vec3f opNeg()
	{	return Vec3f(-x, -y, -z);
	}

	/// Return the difference between this vector and another.
	Vec3f opSub(Vec3f s)
	{	return Vec3f(x-s.x, y-s.y, z-s.z);
	}

	/// Subtract the values of another vector from this one.
	Vec3f opSubAssign(Vec3f s)
	{	x-=s.x, y-=s.y, z-=s.z;
		return *this;
	}

	/// Print the x, y, z values of the vector to the standard output.
	void print()
	{	writefln("Vec3f: "~toString());
	}

	/**
	 * Return a copy of this vector rotated by axis, where both are interpreted
	 * as axis-angle vectors.*/
	Vec3f rotate(Vec3f axis)
	{	return rotate(axis.toMatrix());
	}

	/**
	 * Return a copy of this Vec3f rotated by the Quatrn q.
	 * Note that this is curently slower than rotate(Matrix m).*/
	Vec3f rotate(Quatrn q)
	{	return rotate(q.toMatrix());
		//return q*(*this)*(q.inverse());
	}

	/// Return a copy of this vector rotated by the rotation values of Matrix m.
	Vec3f rotate(Matrix m)
	{	Vec3f res=void;
		res.x = x*m.v[0] + y*m.v[4] + z*m.v[8];
		res.y = x*m.v[1] + y*m.v[5] + z*m.v[9];
		res.z = x*m.v[2] + y*m.v[6] + z*m.v[10];
		return res;
	}

	/// Return a copy of this vector with each component scaled by s.
	Vec3f scale(float s)
	{	if (s == float.infinity)
			return Vec3f(0, 0, 0);
		return Vec3f(x*s, y*s, z*s);
	}

	/// Return a copy of this vector scaled by the values of another vector.
	Vec3f scale(Vec3f v)
	{	return Vec3f(x*v.x, y*v.y, z*v.z);
	}

	/// Assign s to x, y, and z.
	void set(float s)
	{	v[0..3]=s;
	}

	/// Assign a, b, and c to x, y, and z.
	void set(float a, float b, float c)
	{	x=a; y=b; z=c;
	}

	/// Set to an array of three floats.
	void set(float[] s)
	{	assert(s.length>=3);
		x=s[0]; y=s[1]; z=s[2];
	}

	/// Set this vector to the translation (position) part of a 4x4 Matrix
	void set(Matrix m)
	{	v[0..3] = m.v[12..15];
	}

	/// Set to a rotation axis from the rotation values of Matrix m.
	void setAxis(Matrix m)
	{	*this = m.toAxis();
	}

	/// Set to a rotation axis from the rotation values of Quatrn q.
	void setAxis(Quatrn q)
	{	*this = q.toAxis();
	}

	/// Return the difference between this vector and another.
	Vec3f subtract(Vec3f s)
	{	return Vec3f(x-s.x, y-s.y, z-s.z);
	}

	/**
	 * Interpret the values of this vector as a rotation axis and convert to
	 * a Quatrn.*/
	Quatrn toQuatrn()
	{	Quatrn res;
		float angle = length;
		if (length==0) // no rotation for zero-vector
			return res;
		Vec3f axis = normalize();
		float sin_a = sin( angle / 2 );
		float cos_a = cos( angle / 2 );
		res.x = axis.x * sin_a;
		res.y = axis.y * sin_a;
		res.z = axis.z * sin_a;
		res.w = cos_a;
		return res;
	}

	/**
	 * Interpret the values of this vector as a rotation axis and convert to
	 * a rotation Matrix.*/
	Matrix toMatrix()
	{	Matrix res;
		float phi = length();
		if (phi==0) // no rotation for zero-vector
			return res;
		Vec3f n = scale(1/phi);
		float rcos = cos(phi);
		float rsin = sin(phi);
		res.v[0] =      rcos + n.x*n.x*(1-rcos);
		res.v[1] =  n.z * rsin + n.y*n.x*(1-rcos);
		res.v[2] = -n.y * rsin + n.z*n.x*(1-rcos);
		res.v[4] = -n.z * rsin + n.x*n.y*(1-rcos);
		res.v[5] =      rcos + n.y*n.y*(1-rcos);
		res.v[6] =  n.x * rsin + n.z*n.y*(1-rcos);
		res.v[8] =  n.y * rsin + n.x*n.z*(1-rcos);
		res.v[9] = -n.x * rsin + n.y*n.z*(1-rcos);
		res.v[10] =      rcos + n.z*n.z*(1-rcos);
		return res;
	}

	/// Return a string representation of this vector for human reading.
	char[] toString()
	{	return formatString("<%.4f %.4f %.4f>", x, y, z);
	}
}
