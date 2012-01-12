/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.core.math.vector;

import tango.core.Tuple;
import tango.math.Math;
import tango.math.IEEE;
import yage.core.format;
//import yage.core.math.line;
import yage.core.math.matrix;
import yage.core.math.math;
import yage.core.math.quatrn;
import yage.core.array : amax;

import yage.system.log;

// From http://dsource.org/projects/scrapple/browser/trunk/tools/tools/base.d
template Repeat(T, int count) {
	  static if (!count) alias Tuple!() Repeat;
	  else static if (count == 1) alias Tuple!(T) Repeat;
	  else static if ((count%2) == 1) alias Tuple!(Repeat!(T, count/2), Repeat!(T, count/2), T) Repeat;
	  else alias Tuple!(Repeat!(T, count/2), Repeat!(T, count/2)) Repeat;
}

/**
 * This is a template to create a vector of any type with any number of elements.
 * Use Vec.v[0..n] to access the vector's elements directly, or x,y,z,w to access
 * elements of vector's of size less than or equal to four.
 * N = Allow NaN and inf.  If false, add a class invariant to ensure the values of the Vector are never NaN or infinity.
 * Example:
 * --------------------------------
 * Vec!(4, real) a; // a is a four-component real vector.
 * --------------------------------
 * TODO: Convert looping code to static if's to improve performance.
 */
struct Vec(int S, T : real, bool N=false)
{
	alias Vec!(S, T, N) VST;
	static const byte components = S; ///
	
	static const VST ZERO; ///
	static if (S==3) // temporary, later we will support all sizes
		static const VST ONE = {v: [1, 1, 1]}; ///

	/// Allow acessiong the vector as an array of values through field v, or via .x, .y, .z, etc. up to the number of components.
	union
	{	T v[S] = 0; ///
		Repeat!(T, S) tuple;
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
	
	static if (!N)
		invariant()
		{	foreach (float t; v)
			{	assert(!isNaN(t), format("<%s>", v));
				assert(t!=float.infinity, format("<%s>", v));
			}
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
	{	assert(s.length >= S);
		VST res;
		res.v[] = s[0..S];
		return res;
	}
	/*
	/// Convert from other vector types to this type.
	static VST opCall(int S2, T2 : real, bool N2)(Vec!(S2, T2, N2) s)
	{	VST result;
		const size = S>S2?S:S2;
		for (int i=0; i<size;i++)
			result.v[i] = cast(T)s.v[i];
		return result;
	}*/							

	/// Is this vector equal to vector s, discarding relative error fudge.
	bool almostEqual(VST s, float fudge=0.0001)
	{	for (int i=0; i<v.length; i++)
			if (!yage.core.math.math.almostEqual(v[i], s.v[i], fudge))
				return false;
		return true;
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

	// TODO: make this work for all vector sizes
	static if (S==3)
	{
		/// Return the distance from this vector to another, interpreting each as 3D coordinates.
		float distance(VST s)
		{	return sqrt(distance2(s));
		}
	
		/// Return the square of the distance from this Vec3f to another, interpreting each as 3D coordinates.
		float distance2(VST s)
		{	VST temp = *this - s;
			temp *= temp;
			return temp.x + temp.y + temp.z;
		}
	}

	/// Return the _dot product of this vector and s.
	float dot(VST s)
	{	VST temp = opMul(s);		
		float result=0;
		foreach (elem; temp.tuple) // compile time expand 
			result += elem;
		return result;
	}
	unittest
	{	assert(Vec3f.ZERO.dot(Vec3f.ZERO) == 0);
		assert(Vec3f(0, 1, 0).dot(Vec3f(0, -1, 0)) == -1);
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
		VST pold, p1, p2;
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
		assert(Vec2f(0, .999999).inside(polygon));
		assert(!Vec2f(0, 1.00001).inside(polygon));
	}
	
	/// Return the _length of the vector (the magnitude).
	float length()
	{	return sqrt(length2());
	}
	unittest
	{	assert (Vec3f(0, 0, 0).length() == 0);
		assert (Vec3f(1, 0, 0).length() == 1);
		assert (Vec3f(-2, 0, 0).length() == 2);
		assert (Vec3f(-3, 4, 0).length() == 5);
		assert (Vec3f(-3, 4, 0).length() == Vec3f(0, 4, 3).length());
	}

	/// Return the length of the vector squared.  This is faster than length().
	float length2()
	{	T sum = 0;
		foreach (T c; v)
			sum += c*c; // TODO: optimize!
		return sum;
	}
	
	/// Return a copy of this vector scaled to length l.
	VST length(float l)
	{	if (l==0 || *this==VST.ZERO) // otherwise, setting the length of a zero vector to zero fails.
			return VST.ZERO;
		return scale(l/length());
	}

	/// Return the maximum value of the vector components
	float max()
	{	static if (S==3)
		{	if (x>=y && x>=z) return x;
			if (y>=z) return y;
			return z;
		} else
			return amax(v);
	}
	
	/// Return a normalized copy of this vector.
	VST normalize()
	{	if (*this==ZERO)
			return ZERO;
		
		float l = length();
		if (l==1)
			return *this;
		return scale(1/l);
	}
	
	/// Perform a member-wise instead of a bitwise compare.  This way 0f == -0f.
	int opEquals(VST rhs)
	{	static if (S==3) // untested optimization
			return x==rhs.x && y==rhs.y && z==rhs.z;		
		for (int i=0; i<S; i++)
			if (v[i] != rhs.v[i])
				return false;
		return true;
	}
	
	/**
	 * Allow for additions, subtractions, multiplcations, and divisions where a scalar or another vector's value is applied to each component. */
	VST opAdd(T s)
	{	VST res = void;
		res.v[] = v[] + s;
		return res;
	}
	VST opAdd(VST s) /// ditto
	{	VST res = void;
		res.v[] = v[] + s.v[];
		return res;
	}
	void opAddAssign(float s) /// ditto
	{	v[] += cast(T)s;
	}
	void opAddAssign(VST s) /// ditto
	{	v[] += s.v[];
	}
	VST opSub(T s) /// ditto
	{	VST res = void;
		res.v[] = v[] - s;
		return res;
	}
	VST opSub(VST s) /// ditto
	{	VST res = void;
		res.v[] = v[] - s.v[];
		return res;
	}
	void opSubAssign(float s) /// ditto
	{	v[] -= cast(T)s;
	}
	void opSubAssign(VST s) /// ditto
	{	v[] -= s.v[];
	}	
	VST opMul(T s) /// ditto
	{	VST res = void;
		res.v[] = v[] * s;
		return res;
	}
	VST opMul(VST s) /// ditto
	{	VST res = void;
		res.v[] = v[] * s.v[];
		return res;
	}
	void opMulAssign(float s) /// ditto
	{	v[] *= cast(T)s;
	}
	void opMulAssign(VST s) /// ditto
	{	v[] *= s.v[];
	}
	VST opDiv(T s) /// ditto
	{	VST res = void;
		res.v[] = v[] / s;
		return res;
	}
	VST opDiv(VST s) /// ditto
	{	VST res = void;
		res.v[] = v[] / s.v[];
		return res;
	}
	void opDivAssign(float s) /// ditto
	{	v[] /= cast(T)s;
	}
	void opDivAssign(VST s) /// ditto
	{	v[] /= s.v[];
	}
	
	
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
	
	/// Scale (multiply) this vector.  TODO: Replace this with opMul
	VST scale(float s)
	{	VST result = void;
		result.v[] = v[]*cast(T)s; // TODO: wrong for ints!
		return result;
	}
	/// ditto
	VST scale(VST s)
	{	VST result = void;
		result.v[] = v[]*s.v[];
		return result;
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
			static if (is(T : real))
				result ~= format("%.12f ", v[i]);
			else
				result ~= format("%d ", v[i]);
		result ~= ">";
		return result;
	}
	
	/**
	 * Convert to one type of Vec to another.
	 * Params:
	 *     S2 = Size (number of components) of new Vec.
	 *     T2 = type of new Vec. */
	Vec!(S2, T2, N2) toVec(int S2, T2 : real, bool N2=false)()
	{	auto result = Vec!(S2, T2, N2)();
		for (int i=0; i<min(S, S2); i++)
			result.v[i] = cast(T2)v[i];
		return result;
	}
	
	alias toVec!(2, int) vec2i; /// ditto
	alias toVec!(3, int) vec3i; /// ditto
	alias toVec!(4, int) vec4i; /// ditto	
	alias toVec!(2, float) vec2f; /// Convert to these types of vectors
	alias toVec!(3, float) vec3f; /// ditto
	alias toVec!(4, float) vec4f; /// ditto
	alias toVec!(2, float, true) vec2fn; /// ditto
	alias toVec!(3, float, true) vec3fn; /// ditto
	alias toVec!(4, float, true) vec4fn; /// ditto
		
	// Special operations for 3-component vectors that can't be NaN or inf
	static if (S==3 && !N)
	{		
		/// Temporary for easily switching between Vec3f and quaternions
		VST toAxis()
		{	return *this;
		}
		
		/// Return the cross product of this vector with another vector.
		VST cross(VST s)
		{	return VST(y*s.z-z*s.y, z*s.x-x*s.z, x*s.y-y*s.x);
		}

		static if (is( T == float))
		{
			///
			static VST opCall(float angle, VST axis)
			{	VST res=void;
				res.v[] = axis.v[];
				return res.length(angle);
			}
			
			/**
			 * Treat this Vector as an axis-angle and combine the rotation of another axis-angle. */
			VST combineRotation(VST axis)
			{	
				
				// This is a required shortcut to handle corner cases.
				if (cross(axis).length2() < .0001) // If they point in almost the same or opposite directions
					return *this+axis;
				
				// Non inlined way.  Inlining below was to try to combine operations (unsuccessfully)
				//return toQuatrn().rotate(axis).toAxis();
								
				// Convert to quaternions
				Quatrn q1;
				if (*this!=ZERO) // no rotation for zero-vector
				{	float angle = length();
					float hangle = angle * .5;
					float s = sin(hangle); // / sqrt(angle);
					q1.w = cos(hangle);
					q1.v[0..3] = v[0..3] * (s/angle);
				}
				
				Quatrn q2;
				if (axis.x!=0 || axis.y!=0 || axis.z!=0) // no rotation for zero-vector
				{	float angle = axis.length();
					float hangle = angle * .5;
					float s = sin(hangle); // / sqrt(angle);
					q2.w = cos(hangle);
					q2.v[0..3] = axis.v[0..3] * (s/angle);
				}
				
				// Multiply the quaternions
				Quatrn res;
				res.w = q2.w*q1.w - q2.x*q1.x - q2.y*q1.y - q2.z*q1.z;
				res.x = q2.w*q1.x + q2.x*q1.w + q2.y*q1.z - q2.z*q1.y;
				res.y = q2.w*q1.y - q2.x*q1.z + q2.y*q1.w + q2.z*q1.x;
				res.z = q2.w*q1.z + q2.x*q1.y - q2.y*q1.x + q2.z*q1.w;
								
				// Convert back to axis-angle.
				VST result;
				auto angle = acos(res.w)*2;
				if (angle != 0)
				{	auto sin_a = sqrt(1 - res.w*res.w);
					if (.abs(sin_a) < 0.0005)	// arbitrary small number
						sin_a = 1;
					auto inv_sin_a = 1/sin_a;
					result.x = res.x*inv_sin_a;
					result.y = res.y*inv_sin_a;
					result.z = res.z*inv_sin_a;		
					result = result.length(angle);
				}
				return result;				
			}			

			///
			VST lookAt(VST direction, VST up)
			{	
				auto z = direction.normalize();
				auto x = up.cross(z).normalize();
				auto y = z.cross(x);
				
				Matrix result;		
				result.v[0..3] = x.v[0..3];
				result.v[4..7] = y.v[0..3];
				result.v[8..11] = z.v[0..3];
				
				/// TODO: This is very inefficient and possibly incorrect
				return result/*.transformAffine(toMatrix())*/.toAxis();
			}
			
			/**
			 * Return a copy of this vector rotated by axis. 
			 * TODO: Rodriguez formula should be more efficient:  http://en.wikipedia.org/wiki/Axis-angle_representation#Rotating_a_vector*/
			VST rotate(VST axis)
			{	return rotate(axis.toMatrix());
				/+// TODO Inline simplifcation and optimization
				float phi = axis.length();
				if (phi==0) // no rotation for zero-vector
					return *this;
				Vec3f n = axis.scale(1/phi);
				float rcos = cos(phi);
				float rsin = sin(phi);
				// float ircos = 1-rcos; // TODO: Use this alsy
				
				Vec3f res=void;
				res.x = x*(rcos + n.x*n.x*(1-rcos))    +    \ y*(-n.z * rsin + n.x*n.y*(1-rcos)) + z*(n.y * rsin + n.x*n.z*(1-rcos));
				
				/+ // TODO reduction from 17 to 13 ops (is this correct?) :
				x*rcos + x*n.x*n.x*(1-rcos)            +    y*-n.z * y*rsin + n.x*n.y*(1-rcos) + z*n.y*rsin + z*n.x*n.z*(1-rcos);
				x*rcos + y*-n.z*y*rsin + z*n.y*rsin    +    x*n.x*n.x*(1-rcos) + n.x*n.y*(1-rcos) + z*n.x*n.z*(1-rcos);		
				x*rcos + y*-n.z*y*rsin + z*n.y*rsin    +    (1-rcos)*(x*n.x*n.x + n.x*n.y + z*n.x*n.z);
				x*rcos + y*-n.z*y*rsin + z*n.y*rsin    +    (1-rcos)*n.x*(x*n.x + n.y + z*n.z);
				x*rcos + y*y*-n.z*rsin + y*z*n.rsin    +    (1-rcos)*n.x*(x*n.x + n.y + z*n.z);
				x*rcos + y*(y*-n.z*rsin + z*n.rsin)    +    (1-rcos)*n.x*(x*n.x + n.y + z*n.z);
				res.x = x*rcos + y*rsin*(y*-n.z + z)   +    (1-rcos)*n.x*(x*n.x + n.y + z*n.z);
				+/
				res.y = x*(n.z * rsin + n.y*n.x*(1-rcos))  + y*(rcos + n.y*n.y*(1-rcos))        + z*(-n.x * rsin + n.y*n.z*(1-rcos));
				res.z = x*(-n.y * rsin + n.z*n.x*(1-rcos)) + y*(n.x * rsin + n.z*n.y*(1-rcos))  + z*(rcos + n.z*n.z*(1-rcos));
				return res;
				+/
			}

			/**
			 * Return a copy of this Vec3f rotated by the Quatrn q.
			 * Note that this is curently slower than rotate(Matrix m).*/
			VST rotate(Quatrn q)
			{	return rotate(q.toMatrix());
			}

			/// Return a copy of this vector rotated by the rotation values of Matrix m.
			VST rotate(Matrix m)
			{	VST res=void;
				res.x = x*m.v[0] + y*m.v[4] + z*m.v[8];
				res.y = x*m.v[1] + y*m.v[5] + z*m.v[9];
				res.z = x*m.v[2] + y*m.v[6] + z*m.v[10];
				return res;
			}
			
			/**
			 * Interpret the values of this vector as a rotation axis and convert to a rotation Matrix.*/
			Matrix toMatrix()
			{	Matrix res;
				float phi = length();
				if (phi==0) // no rotation for zero-vector
					return res;
				VST n = scale(1/phi);
				float rcos = cos(phi);
				float ircos = 1-rcos;
				float rsin = sin(phi);
				res.v[0] =      rcos + n.x*n.x*ircos;
				res.v[1] =  n.z * rsin + n.y*n.x*ircos;
				res.v[2] = -n.y * rsin + n.z*n.x*ircos;
				res.v[4] = -n.z * rsin + n.x*n.y*ircos;
				res.v[5] =      rcos + n.y*n.y*ircos;
				res.v[6] =  n.x * rsin + n.z*n.y*ircos;
				res.v[8] =  n.y * rsin + n.x*n.z*ircos;
				res.v[9] = -n.x * rsin + n.y*n.z*ircos;
				res.v[10] =      rcos + n.z*n.z*ircos;
				return res;
			}
			
			/**
			 * Interpret the values of this vector as a rotation axis/angle and convert to a Quatrn.*/
			Quatrn toQuatrn()
			{	
				if (*this==ZERO) // no rotation for zero-vector
					return Quatrn();
				
				Quatrn res = void;
				float angle = length();
				float hangle = angle * .5;
				float s = sin(hangle); // / sqrt(angle);
				res.w = cos(hangle);
				if (angle != 0)
					res.v[0..3] = v[0..3] * (s/angle);
				
				debug res.__invariant();
				return res;
			}
		}
	}
}

alias Vec!(2, int) Vec2i;		/// A two-component int Vec
alias Vec!(3, int) Vec3i;		/// A three-component int Vec
alias Vec!(4, int) Vec4i;		/// A four-component int Vec
alias Vec!(2, float) Vec2f;		/// A two-component float Vec
alias Vec!(3, float) Vec3f;	
alias Vec!(4, float) Vec4f;		/// A four-component float Vec

alias Vec!(2, float, true) Vec2fn;		/// A two-component float Vec
alias Vec!(3, float, true) Vec3fn;	
alias Vec!(4, float, true) Vec4fn;		/// A four-component float Vec

/+
/**
 * A 3D vector class. 
 * This can be merged with the templated version above when D fixed the forward template declaration bugs. */
struct Vec3f
{
	static const byte components = 3;
	static const Vec3f ZERO = Vec3f(0);
	static const Vec3f ONE = Vec3f(1);
	
	union
	{	struct
		{	float x=0, y=0, z=0;
		}
		float v[3];
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
				test("Add & Subtract", (c+d-d) + (d) - (d), c, d);
				test("Cross Product", c.cross(d), d.negate().cross(c), c, d);
				test("Dot Product", c.scale(c.dot(d)), c.scale(c.x*d.x+c.y*d.y+c.z*d.z));
				test("Distance", c.scale(c.distance(d)), c.scale(sqrt((c.x-d.x)*(c.x-d.x) + (c.y-d.y)*(c.y-d.y) + (c.z-d.z)*(c.z-d.z))));
			}
		}
	}
	
	Vec!(3, float) newVec()
	{	return Vec!(3, float)(x, y, z);
	}

	/// Create a zero vector
	static Vec3f opCall()
	{	Vec3f res;
		return res;
	}

	/// Create a Vec3f with all values as s.
	static Vec3f opCall(float s)
	{	Vec3f res={s, s, s};
		return res;
	}

	/// Create a new Vec3f with the values x, y, and z
	static Vec3f opCall(float x, float y, float z)
	{	Vec3f res={x, y, z};
		return res;
	}

	/// Create a new axis-angle Vec3f from rotation angle angle and the values x, y, and z
	static Vec3f opCall(float angle, Vec3f axis)
	{	Vec3f res=void;
		res.v[] = axis.v[];
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

	/// Is this vector equal to vector s, discarding relative error fudge.
	bool almostEqual(Vec3f s, float fudge=0.0001)
	{	for (int i=0; i<v.length; i++)
			if (!yage.core.math.math.almostEqual(v[i], s.v[i], fudge))
				return false;
		return true;
	}

	/// This fails when this vector and s almost point at one another.
	
	import yage.system.log;
	
	Vec3f angleBetween(Vec3f s)
	{	
		// TODO: This can be optimized?
		Vec3f axis = cross(s);
		float ds = dot(s);
		float d = ds / (length()*s.length());		
		float angle = atan2(axis.length(), ds);

		return axis.length(angle);
	}
	
	///
	Vec3f lookAt(Vec3f direction, Vec3f up)
	{	
		Vec3f z = direction.normalize();
		Vec3f x = up.cross(z).normalize();
		Vec3f y = z.cross(x);
		
		Matrix result;		
		result.v[0..3] = x.v[0..3];
		result.v[4..7] = y.v[0..3];
		result.v[8..11] = z.v[0..3];
		
		/// TODO: This is very inefficient and possibly incorrect
		return result/*.transformAffine(toMatrix())*/.toAxis();		
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
	{	return sqrt(length2());
	}

	/// Return the length of the vector squared.  This is faster than length().
	float length2()
	{	Vec3f temp = void;
		temp.v[] = v[]*v[];
		return temp.x + temp.y + temp.z;
	}

	/// Return a copy of this vector scaled to length l.
	Vec3f length(float l)
	{	if (l==0 || *this==Vec3f.ZERO) // otherwise, setting the length of a zero vector to zero fails.
			return Vec3f.ZERO;
		return scale(l/length());
	}

	/// Return the maximum value of the vector components
	float max()
	{	if (x>=y && x>=z) return x;
		if (y>=z) return y;
		return z;
	}

	/// Return a vector with every value of this Vec3f negated.
	Vec3f negate()
	{	Vec3f result;
		result.v[] = v[]*-1;
		return result;
	}

	/// Return a normalized copy of this vector.
	Vec3f normalize()
	{	if (*this==ZERO)
			return ZERO;
		
		float l = length();
		if (l==1)
			return *this;
		return scale(1/l);
	}

	/// Return the sum of this vector and another.
	Vec3f opAdd(Vec3f s)
	{	Vec3f result = void;
		result.v[] = v[] + s.v[];
		return result;
	}

	/// Add the values of another Vec3f into this one.
	Vec3f opAddAssign(Vec3f s) /// ditto
	{	v[] += s.v[];
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
	{	Vec3f result = void;
		result.v[] = v[] - s.v[];
		return result;
	}
	Vec3f opSubAssign(Vec3f s) /// ditto
	{	v[] -= s.v[];
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
	 * Return a copy of this vector rotated by axis. */
	Vec3f rotate(Vec3f axis)
	{	return rotate(axis.toMatrix());
		/+// TODO Inline simplifcation and optimization
		float phi = axis.length();
		if (phi==0) // no rotation for zero-vector
			return *this;
		Vec3f n = axis.scale(1/phi);
		float rcos = cos(phi);
		float rsin = sin(phi);
		// float ircos = 1-rcos; // TODO: Use this alsy
		
		Vec3f res=void;
		res.x = x*(rcos + n.x*n.x*(1-rcos))    +    \ y*(-n.z * rsin + n.x*n.y*(1-rcos)) + z*(n.y * rsin + n.x*n.z*(1-rcos));
		
		/+ // TODO reduction from 17 to 13 ops (is this correct?) :
		x*rcos + x*n.x*n.x*(1-rcos)            +    y*-n.z * y*rsin + n.x*n.y*(1-rcos) + z*n.y*rsin + z*n.x*n.z*(1-rcos);
		x*rcos + y*-n.z*y*rsin + z*n.y*rsin    +    x*n.x*n.x*(1-rcos) + n.x*n.y*(1-rcos) + z*n.x*n.z*(1-rcos);		
		x*rcos + y*-n.z*y*rsin + z*n.y*rsin    +    (1-rcos)*(x*n.x*n.x + n.x*n.y + z*n.x*n.z);
		x*rcos + y*-n.z*y*rsin + z*n.y*rsin    +    (1-rcos)*n.x*(x*n.x + n.y + z*n.z);
		x*rcos + y*y*-n.z*rsin + y*z*n.rsin    +    (1-rcos)*n.x*(x*n.x + n.y + z*n.z);
		x*rcos + y*(y*-n.z*rsin + z*n.rsin)    +    (1-rcos)*n.x*(x*n.x + n.y + z*n.z);
		res.x = x*rcos + y*rsin*(y*-n.z + z)   +    (1-rcos)*n.x*(x*n.x + n.y + z*n.z);
		+/
		res.y = x*(n.z * rsin + n.y*n.x*(1-rcos))  + y*(rcos + n.y*n.y*(1-rcos))        + z*(-n.x * rsin + n.y*n.z*(1-rcos));
		res.z = x*(-n.y * rsin + n.z*n.x*(1-rcos)) + y*(n.x * rsin + n.z*n.y*(1-rcos))  + z*(rcos + n.z*n.z*(1-rcos));
		return res;
		+/
	}

	/**
	 * Return a copy of this Vec3f rotated by the Quatrn q.
	 * Note that this is curently slower than rotate(Matrix m).*/
	Vec3f rotate(Quatrn q)
	{	return rotate(q.toMatrix());
	}

	/// Return a copy of this vector rotated by the rotation values of Matrix m.
	Vec3f rotate(Matrix m)
	{	Vec3f res=void;
		res.x = x*m.v[0] + y*m.v[4] + z*m.v[8];
		res.y = x*m.v[1] + y*m.v[5] + z*m.v[9];
		res.z = x*m.v[2] + y*m.v[6] + z*m.v[10];
		return res;
	}
	
	/**
	 * Treat this Vector as an axis-angle and combine the rotation of another axis-angle. */
	Vec3f combineRotation(Vec3f axis)
	{	
		// Shortcut!
		if (cross(axis).length2() < .01) // If they point in almost the same or opposite directions
			return *this+axis;
		
		Quatrn q1;
		if (*this!=ZERO) // no rotation for zero-vector
		{	float angle = length();
			float hangle = angle * .5;
			float s = sin(hangle); // / sqrt(angle);
			q1.w = cos(hangle);
			q1.v[0..3] = v[0..3] * (s/angle);
		}
		
		Quatrn q2;
		if (axis!=ZERO) // no rotation for zero-vector
		{	float angle = axis.length();
			float hangle = angle * .5;
			float s = sin(hangle); // / sqrt(angle);
			q2.w = cos(hangle);
			q2.v[0..3] = axis.v[0..3] * (s/angle);
		}
		
		Quatrn res;
		res.w = q2.w*q1.w - q2.x*q1.x - q2.y*q1.y - q2.z*q1.z;
		res.x = q2.w*q1.x + q2.x*q1.w + q2.y*q1.z - q2.z*q1.y;
		res.y = q2.w*q1.y - q2.x*q1.z + q2.y*q1.w + q2.z*q1.x;
		res.z = q2.w*q1.z + q2.x*q1.y - q2.y*q1.x + q2.z*q1.w;
		
		Vec3f result;
		auto angle = acos(res.w)*2;
		if (angle != 0)
		{	auto sin_a = sqrt(1 - res.w*res.w);
			if (.abs(sin_a) < 0.0005)	// arbitrary small number
				sin_a = 1;
			auto inv_sin_a = 1/sin_a;
			result.x = res.x*inv_sin_a;
			result.y = res.y*inv_sin_a;
			result.z = res.z*inv_sin_a;		
			result = result.length(angle);
		}
		return result;
	}
	
	/// Return a copy of this vector with each component scaled by s.
	Vec3f scale(float s)
	{	//if (s == float.infinity)
		//	return Vec3f.ZERO;
		assert(s!=float.infinity);
		Vec3f result;
		result.v[0..3] = v[0..3]*s;
		return result;
	}

	/// Return a copy of this vector scaled by the values of another vector.
	Vec3f scale(Vec3f s)
	{	Vec3f result;
		result.v[0..3] = v[0..3]*s.v[0..3];
		return result;
	}

	/**
	 * Interpret the values of this vector as a rotation axis/angle and convert to a Quatrn.*/
	Quatrn toQuatrn()
	{	Quatrn res;
		if (*this!=ZERO) // no rotation for zero-vector
		{	float angle = length();
			float hangle = angle * .5;
			float s = sin(hangle); // / sqrt(angle);
			res.w = cos(hangle);
			res.v[0..3] = v[0..3] * (s/angle);
		}
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
		float ircos = 1-rcos;
		float rsin = sin(phi);
		res.v[0] =      rcos + n.x*n.x*ircos;
		res.v[1] =  n.z * rsin + n.y*n.x*ircos;
		res.v[2] = -n.y * rsin + n.z*n.x*ircos;
		res.v[4] = -n.z * rsin + n.x*n.y*ircos;
		res.v[5] =      rcos + n.y*n.y*ircos;
		res.v[6] =  n.x * rsin + n.z*n.y*ircos;
		res.v[8] =  n.y * rsin + n.x*n.z*ircos;
		res.v[9] = -n.x * rsin + n.y*n.z*ircos;
		res.v[10] =      rcos + n.z*n.z*ircos;
		return res;
	}

	/// Return a string representation of this vector for human reading.
	char[] toString()
	{	return format("<%.6f, %.6f, %.6f>", x, y, z);
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
+/