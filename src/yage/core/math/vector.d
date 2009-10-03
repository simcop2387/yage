/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.core.math.vector;

import tango.math.Math;
import tango.text.convert.Format;
//import yage.core.math.line;
import yage.core.math.matrix;
import yage.core.math.math;
import yage.core.math.quatrn;

/**
 * This is a template to create a vector of any type with any number of elements.
 * Use Vec.v[0..n] to access the vector's elements directly, or a-d to access
 * elements of vector's of size less than or equal to four.
 * Example:
 * --------------------------------
 * Vec!(4, real) a; // a is a four-component real vector.
 * --------------------------------
 * TODO: Convert looping code to static if's to improve performance.
 */
struct Vec(int S, T, int D=1)
{
	alias Vec!(S, T) VST;
	static const byte components = S;

	/// Allow acessiong the vector as an array of values through field v, or via .x, .y, .z, etc. up to the number of components.
	union
	{	T v[S] = D; ///
	
		struct ///
		{	union {T x; T r; } ///
			static if (S>=2) ///
				union {T y; T g; } ///
			static if (S>=3) ///
				union {T z; T b; } ///
			static if (S>=4) ///
				union {T w; T a; } ///
		}
		static if (S==2) ///
			struct {T width; T height; } ////
		static if (S==4) ///
			struct {T top; T right; T bottom; T left; } ////
	}

	/// Create a zero vector
	static VST opCall()
	{	VST res;
		return res;
	}

	/// Create a vector with all values as s.
	static VST opCall(T s)
	{	VST res;
		foreach(inout T e; res.v)
			e = s;
		return res;
	}

	/// Create a new vector with the values s0, s1, s2, ...
	static VST opCall(T[S] s ...)
	{	VST res;
		res.v[0..S] = s[0..S];
		return res;
	}

	/// Create a new vector with the values of s; If s is less than the size of the vector, remaining values are set to 0.
	static VST opCall(T[] s)
	{	VST res;
		for (int i=0; i<s.length && i<v.length; i++)
			res.v[i] = s[i];
		return res;
	}

	/// The angle between this vector and s, in radians.
	float angle(VST s)
	{	return acos(dot(s)/(length()*s.length()));
	}

	/// Clamp all values between min and max.
	VST clamp(T min, T max)
	{	VST res;
		for (int i=0; i<S; i++)
		{	if (res.v[i]<min) res.v[i] = min;
			else if (res.v[i]>max) res.v[i] = max;
			else res.v[i] = v[i];
		}
		return res;
	}
	VST clamp(VST min, VST max) /// ditto
	{	VST result;
		for (int i=0; i<S; i++)
		{	if (result.v[i]<min.v[i]) result.v[i] = min.v[i];
			else if (result.v[i]>max.v[i]) result.v[i] = max.v[i];
			else result.v[i] = v[i];
		}
		return result;		
	}


	/// Return the _dot product of this vector and s.
	float dot(VST s)
	{	float res=0;
		for (int i=0; i<v.length; i++)
			res += v[i]*s.v[i];
		return res;
	}

	/// Is this Vector (as a point) inside a box/cube/etc. defined by topLeft and bottomRight
	bool inside(VST topLeft, VST bottomRight, bool inclusive=true)
	{	if (inclusive)
		{	for (int i=0; i<v.length; i++)
				if (v[i] <= topLeft[i] || v[i] >= bottomRight[i])
					return false;
		} else
		{	for (int i=0; i<v.length; i++)
				if (v[i] < topLeft[i] || v[i] > bottomRight[i])
					return false;
		}					
		return true;
	}
	
	/**
	 * Is this Vector (as a point) inside a polygon defined by an array of Points?
	 * See_Also: http://www.visibone.com/inpoly */
	bool inside(VST[] polygon)
	{
		Vec!(S, T) pold, p1, p2;
		bool inside;
		
		if (polygon.length < 3)
			return false;
		
		pold = polygon[$-1];
		for (int i=0; i < polygon.length; i++)
		{	VST pnew = polygon[i];
			if (pnew.x > pold.x) {
				p1 = pold;
				p2 = pnew;
			}
			else {
				p1 = pnew;
				p2 = pold;
			}
			if ((pnew.x < x) == (x <= pold.x) // edge "open" at one end
			    && (y-p1.y)*(p2.x-p1.x) < (p2.y-p1.y)*(x-p1.x))
				inside= !inside;
			pold = pnew;
		}
		return inside;
	}
	unittest
	{
		Vec2f[] polygon = [Vec2f(-1, -1), Vec2f(0, 1), Vec2f(1, -1)];
		assert(Vec2f(0, 0).inside(polygon));
		assert(!Vec2f(0, 2).inside(polygon));
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


	/// Allow for linear additions, subtractions, multiplcations, and divisions among Vectors of the same size and type.
	VST opAdd(VST s)
	{	VST res;
		for (int i=0; i<v.length; i++)
			res.v[i] = v[i]+s.v[i];
		return res;
	}
	/// ditto
	void opAddAssign(VST s)
	{	for (int i=0; i<v.length; i++)
			v[i] += s.v[i];
	}	
	/// ditto
	VST opSub(VST s)
	{	VST res;
		for (int i=0; i<v.length; i++)
			res.v[i] = v[i]-s.v[i];
		return res;
	}
	/// ditto
	void opSubAssign(VST s)
	{	for (int i=0; i<v.length; i++)
			v[i] -= s.v[i];
	}
	/// ditto
	VST opMul(VST s)
	{	VST res;
		for (int i=0; i<v.length; i++)
			res.v[i] = v[i]*s.v[i];
		return res;
	}
	/// ditto
	void opMulAssign(VST s)
	{	for (int i=0; i<v.length; i++)
			v[i] *= s.v[i];
	}	
	/// ditto
	VST opDiv(VST s)
	{	VST res;
		for (int i=0; i<v.length; i++)
			res.v[i] = v[i]/s.v[i];
		return res;
	}
	/// ditto
	void opDivAssign(VST s)
	{	for (int i=0; i<v.length; i++)
			v[i] /= s.v[i];
	}
	
	/// Allow for additions, subtractions, multiplcations, and divisions where a scalar is applied to each vector component.
	void opMulAssign(float s)
	{	for (int i=0; i<v.length; i++)
			v[i] += s;
	}
	/// ditto
	void opDivAssign(float s)
	{	for (int i=0; i<v.length; i++)
			v[i] /= s;
	}
	
	/* Postponed until D array operations are stable.
	/// Allow for linear additions, subtractions, multiplcations, and divisions among Vectors of the same size and type.
	VecST opAdd(T s)
	{	return Vec!(S, T)(v[] + s);	
	}
	VecST opAdd(T s) /// ditto
	{	return Vec!(S, T)(v[] + s);	
	}
	void opAddAssign(float s) /// ditto
	{	v[] += cast(T)s;
	}
	void opAddAssign(VecST s) /// ditto
	{	v[] += s.v[];
	}
	VecST opSub(T s) /// ditto
	{	return Vec!(S, T)(v[] - s);	
	}
	VecST opSub(VecST s) /// ditto
	{	return Vec!(S, T)(v[] - s.v[]);
	}
	void opSubAssign(float s) /// ditto
	{	v[] -= cast(T)s;
	}
	void opSubAssign(VecST s) /// ditto
	{	v[] -= s.v[];
	}
	
	/// Allow for additions, subtractions, multiplcations, and divisions where a scalar is applied to each vector component.
	VecST opMul(T s)
	{	return Vec!(S, T)(v[] * s);	
	}
	VecST opMul(VecST s) /// ditto
	{	return Vec!(S, T)(v[] * s.v[]);	
	}
	void opMulAssign(float s) /// ditto
	{	v[] *= cast(T)s;
	}
	void opMulAssign(VecST s) /// ditto
	{	v[] *= s.v[];
	}
	VecST opDiv(T s) /// ditto
	{	return Vec!(S, T)(v[] / s);	
	}
	VecST opDiv(VecST s) /// ditto
	{	return Vec!(S, T)(v[] / s.v[]);	
	}
	void opDivAssign(float s) /// ditto
	{	v[] /= cast(T)s;
	}
	void opDivAssign(VecST s) /// ditto
	{	v[] /= s.v[];
	}
	*/
	
	/// Allow casting to float where appropriate
	static if (is(T : float))	// if T can be implicitly cast to float
	{	Vec!(S, float) opCast()
		{	Vec!(S, float) result;
			for (int i=0; i<v.length; i++)
				result.v[i] = v[i];
			return result;
	}	}
	
	/// Get the element at i
	float opIndex(size_t i)
	{	return v[i];
	}

	/// Assign value to the element at i
	float opIndexAssign(T value, size_t i)
	{	return v[i] = value;
	}

	/// Create a new vector with the values of s
	VST projection(VST s)
	{	return s.scale(dot(s)/s.length2());
	}

	///
	T* ptr()
	{	return v.ptr;		
	}
	
	/// Scale (multiply) this vector.
	VST scale(float s)
	{	VST res = *this;
		for (int i=0; i<v.length; i++)
			res.v[i] *= s;
		return res;
	}
	/// ditto
	VST scale(VST s)
	{	VST res = *this;
		for (int i=0; i<v.length; i++)
			res.v[i] *= s.v[i];
		return res;
	}

	/// Set the values of the Vector.
	void set(T s)
	{	foreach(inout T e; v)
			e = s;
	}
	/// ditto
	void set(VST s)
	{	v[0..S] = s.v[0..S];
	}

	/// ditto
	void set(T[S] s ...)
	{	v[0..S] = s[0..S];
	}

	/// Transform this vector by a Matrix.
	VST transform(Matrix m)
	{	VST result;
		static if (S==2)
		{	result.x = cast(T)(x*m.v[0] + y*m.v[4] + m.v[8] + m.v[12]);
			result.y = cast(T)(x*m.v[1] + y*m.v[5] + m.v[9] + m.v[13]);
		}
		static if (S==3)
		{	result.x = cast(T)(x*m.v[0] + y*m.v[4] + z*m.v[8] + m.v[12]);
			result.y = cast(T)(x*m.v[1] + y*m.v[5] + z*m.v[9] + m.v[13]);
			result.z = cast(T)(x*m.v[2] + y*m.v[6] + z*m.v[10]+ m.v[14]);
		}			
		static if (S>=4)
		{	result.x = cast(T)(x*m.v[0] + y*m.v[4] + z*m.v[8] + w*m.v[12]);
			result.y = cast(T)(x*m.v[1] + y*m.v[5] + z*m.v[9] + w*m.v[13]);
			result.z = cast(T)(x*m.v[2] + y*m.v[6] + z*m.v[10]+ w*m.v[14]);
			result.w = cast(T)(x*m.v[3] + y*m.v[7] + z*m.v[11]+ w*m.v[15]);
		}	
		return result;
	}
	
	/// Return a string representation of this vector for human reading.
	char[] toString()
	{	char[] result = "<";
		for (int i=0; i<S; i++)
			result ~= Format.convert("{} ", v[i]);
		result ~= ">";
		return result;
	}
	
	/*
	// Forward reference error
	static if (S!=2)
	{	///
		Vec2f vec2f()
		{	return Vec2f(v);
		}
	}*/
	
	static if (S!=3 && is(T == float))
	{	///
		Vec3f vec3f()
		{	return Vec3f(v);
		}
	}
	
	/*// forward reference error
	static if (S!=4)
	{	///
		Vec4f vec4f()
		{	return Vec4f(v);
		}
	}
	*/
}

alias Vec!(2, int) Vec2i;		/// A two-component int Vec
alias Vec!(3, int) Vec3i;		/// A three-component int Vec
alias Vec!(4, int) Vec4i;		/// A four-component int Vec
alias Vec!(2, float) Vec2f;		/// A two-component float Vec
alias Vec!(3, float) Vec3f2;			// Defined below
alias Vec!(4, float) Vec4f;		/// A four-component float Vec

/**
 * A 3D vector class. 
 * This can be merged with the templated version above when D fixed the forward template declaration bugs. */
struct Vec3f
{
	static const byte components = 3;
	
	union
	{	float v[3] = [0, 0, 0]; // same as x, y, and z
		struct
		{	float x, y, z;
	}	}

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
			// This fails on all dmd after 0.177
			//test("toMatrix", c.toMatrix().toAxis(), c);
			test("Length", c.length(c.length()), c);
			test("Scale", c.scale(4).scale(.25), c);
			test("Divide", (c*3)/3, c);

			// Rotate every vector by every other and then reverse, in 3 different ways.
			foreach (Vec3f d; v)
			{	test("Rotate Axis", c.rotate(d).rotate(d.negate()), c, d);
				// This fails on all dmd after 0.177
				//test("Rotate Matrix", c.rotate(d.toMatrix()).rotate(d.toMatrix().inverse()), c, d);
				test("Rotate Quatrn", c.rotate(d.toQuatrn()).rotate(d.toQuatrn().inverse()), c, d);
				test("Add & Subtract", (c+d-d).add(d).subtract(d), c, d);
				test("Cross Product", c.cross(d), d.negate().cross(c), c, d);
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

	/// Create a new axis-angle Vec3f from rotation angle angle and the values x, y, and z
	static Vec3f opCall(float angle, float x, float y, float z)
	{	Vec3f res=void;
		res.x = x;
		res.y = y;
		res.z = z;
		return res.length(angle);
	}

	/// Return a vector with the values of s.
	static Vec3f opCall(float[] s)
	{	if(s.length>=3)
			return Vec3f(s[0], s[1], s[2]);
		Vec3f result;
		for (int i=0; i<s.length; i++)
			result.v[i] = s[i];
		return result;
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
			if (!yage.core.math.math.almostEqual(v[i], s.v[i], fudge))
				return false;
		return true;
	}

	float angle(Vec3f s)
	{	return acos(dot(s)/(length()*s.length())); // sqrt(length2*s.length2) would be faster, but untested
	}
	
	/// Return the average of the x, y, and z components.
	float average()
	{	return (x+y+z)*0.3333333333f;
	}

	///
	Vec3f clamp(float l, float u)
	{	return Vec3f(.clamp(x, l, u), .clamp(y, l, u), .clamp(z, l, u));
	}
	///
	Vec3f clamp(Vec3f l, Vec3f u)
	{	return Vec3f(.clamp(x, l.x, u.x), .clamp(y, l.y, u.y), .clamp(z, l.z, u.z));		
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

	/// Is this Vector inside a box/cube/etc. defined by topLeft and bottomRight
	bool inside(Vec3f topLeft, Vec3f bottomRight, bool inclusive=true)
	{	if (inclusive)
		{	for (int i=0; i<v.length; i++)
				if (v[i] <= topLeft[i] || v[i] >= bottomRight[i])
					return false;
		} else
		{	for (int i=0; i<v.length; i++)
				if (v[i] < topLeft[i] || v[i] > bottomRight[i])
					return false;
		}					
		return true;
	}
	
	///
	Vec3f inverse()
	{	return Vec3f(1/x, 1/y, 1/z);
	}
	
	/**
	 * Unlike a transformation, we first apply the translation and then the rotation. */
	Vec3f inverseTransform(Matrix m)
	{	Vec3f copy = Vec3f(x-m[12], y-m[13], z-m[14]); // apply translation in reverse
		return Vec3f(
			copy.x*m[0] + copy.y*m[1] + copy.z*m[2],
			copy.x*m[4] + copy.y*m[5] + copy.z*m[6],
			copy.x*m[8] + copy.y*m[9] + copy.z*m[10]
		);
	}
	
	///
	Vec3f inverseRotate(Matrix m)
	{	Vec3f result;
		result.v[0] = v[0]*m[0] + v[1]*m[1] + v[2]*m[2];
		result.v[1] = v[0]*m[4] + v[1]*m[5] + v[2]*m[6];
		result.v[2] = v[0]*m[8] + v[1]*m[9] + v[2]*m[10];
		return result;
	}

	///
	Vec3f inverseTranslate(Matrix m)
	{	return Vec3f(x-m[12], y-m[13], z-m[14]);
	}

	/// Return the length of the vector (the magnitude).
	float length()
	{	return sqrt(x*x + y*y + z*z);
	}

	/// Return the length of the vector squared.  This is faster than length().
	float length2()
	{	return x*x + y*y + z*z;
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

	/// Return a vector with every value of this Vec3f negated.
	Vec3f negate()
	{	return Vec3f(-x, -y, -z);
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

	///
	float *ptr()
	{	return v.ptr;
	}
	
	/// Create a new vector with the values of s
	Vec3f projection(Vec3f s)
	{	return s.scale(dot(s)/s.length2());
	}

	/// Return a vector in a random direction between length -r and r.
	static Vec3f random(float r = 1)
	{	float a = .random(0, 6.283185307);
		float b = .random(0, 6.283185307);
		return Vec3f(sin(a)*cos(b)*r, sin(a)*sin(b)*r, cos(a)*r);
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
	 * Interpret the values of this vector as a rotation axis and convert to a Quatrn.*/
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
	 * Interpret the values of this vector as a rotation axis and convert to a rotation Matrix.*/
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
	{	return Format.convert("<{} {} {}>", x, y, z);
	}

	/// Return a copy of this Vecotr translated by the translation component of Matrix m.
	Vec3f translate(Matrix m)
	{	Vec3f res=void;
		res.x = x + m.v[12];
		res.y = y + m.v[13];
		res.z = z + m.v[14];
		return res;
	}
	
	/// Return a copy of this vector transformed by Matrix m.
	Vec3f transform(Matrix m)
	{	return Vec3f(
			x*m.v[0] + y*m.v[4] + z*m.v[8] + m.v[12],
			x*m.v[1] + y*m.v[5] + z*m.v[9] + m.v[13],
			x*m.v[2] + y*m.v[6] + z*m.v[10]+ m.v[14]
		);
	}
	
	///
	Vec2f vec2f()
	{	return Vec2f(x, y); 		
	}
	
	///
	Vec4f vec4f()
	{	return Vec4f(x, y, z, 0); 		
	}
}
