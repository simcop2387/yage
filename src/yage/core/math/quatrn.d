/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel, Matt Peterson
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.core.math.quatrn;

import tango.math.Math;
import tango.math.IEEE;
import yage.core.format;
import yage.core.math.vector;
import yage.core.math.matrix;
import yage.core.misc;

import yage.system.log;

/**
 * A quaternion class.
 * Quaternion are 4 dimensional constructs often used in rotation to avoid
 * gimbal lock. This is named Quatrn instead of Quaternion for easier typing.
 * This is defined as a struct instead of a class so it can be created and
 * destroyed without dynamic memory allocation.
 * See_Also:
 * <a href="http://en.wikipedia.org/wiki/Quaternion">Wikipedia: Quaternion</a><br>
 * <a href="http://www.gamedev.net/reference/articles/article1691.asp">The Matrix and Quaternion Faq</a>*/
struct Quatrn
{	union
	{	float v[4] = [0, 0, 0, 1]; // same as x, y, z, w
		struct {
			float x, y, z, w;
		}
		struct {
			Vec3f vector;
			float scalar;
		}
	}

	static const Quatrn IDENTITY;

	invariant()
	{	foreach (float t; v)
		{	assert(!isNaN(t), format("<%s>", v));
			assert(t!=float.infinity, format("<%s>", v));
		}
	}

	unittest
	{
		/**
		 * Testing and reporting in one function
		 * Asserts that the first two matrices are almost equal, and prints
		 * The test name and all givem matrices used in the test if not.*/
		void test(char[] name, Quatrn[] args ...)
		{	char[] report = "\nFailed on test '"~name~"' With Quaternions:\n";
			foreach(Quatrn a; args)
				report ~= format("%s", a.v)~"\n";
			assert(args[0].almostEqual(args[1]), report);
		}

		// Quaternions used in testing
		Quatrn[] q;
		q~= Vec3f(0, 0, 0).toQuatrn();
		q~= Vec3f(1, 0, 0).toQuatrn();
		q~= Vec3f(0, 1, 0).toQuatrn();
		q~= Vec3f(0, 0, 1).toQuatrn();
		q~= Vec3f(.5, 0.0001, 2).toQuatrn();
		q~= Vec3f(.5, 1, -2).toQuatrn();
		q~= Vec3f(.5, -1, -2).toQuatrn();
		q~= Vec3f(-.75, -1, -1.7).toQuatrn();
		q~= Vec3f(-.65, -1, 2).toQuatrn();
		q~= Vec3f(-.55, 0.005, 1).toQuatrn();
		q~= Vec3f(-.371, .1, -1.570796).toQuatrn();
		q~= Vec3f(1.971, -2, 1.2).toQuatrn();
		q~= Vec3f(0.0001, 0.0001, 0.0001).toQuatrn();

		foreach (Quatrn c; q)
		{
			float l = c.length();

			test("Inverse", c.inverse().inverse(), c);
			test("Conjugate", c.conjugate().conjugate(), c);
			if (l!=0)
			{	test("Normalize", c.normalize(), Quatrn(c.x/l, c.y/l, c.z/l, c.w/l), c);
				test("Multiply 1", c*c.inverse(), Quatrn());
				test("Multiply 2", c*Quatrn(), c);
			}

			foreach (Quatrn d; q)
				test("Slerp", c.slerp(d, .25), d.slerp(c, .75), c, d);
		}
	}

	/// Create a unit Quaternion.
	static Quatrn opCall()
	{	return Quatrn(0, 0, 0, 1);
	}

	/// Create a Quaternion from four values.
	static Quatrn opCall(float x, float y, float z, float w)
	{	Quatrn res = void;
		res.x=x;
		res.y=y;
		res.z=z;
		res.w=w;
		return res;
	}

	/// Create a Quaternion from an array of floats.
	static Quatrn opCall(float[] s)
	{	return Quatrn(s[0], s[1], s[2], s[3]);
	}

	/// Create a Quaternion from a rotation Matrix.
	static Quatrn opCall(Matrix m)
	{	return m.toQuatrn();
	}

	/** 
	 * Multiply this quaternion by another and return the result.
	 * The result is the sum of both quaternion rotations.
	 * Note that quaternion multiplication is not cumulative. */
	Quatrn opMul(Quatrn b)
	{	Quatrn res = void;
		res.w = w*b.w - x*b.x - y*b.y - z*b.z;
		res.x = w*b.x + x*b.w + y*b.z - z*b.y;
		res.y = w*b.y - x*b.z + y*b.w + z*b.x;
		res.z = w*b.z + x*b.y - y*b.x + z*b.w;
		return res;
	}


	void opMulAssign(Quatrn b)
	{	float qw = w*b.w - x*b.x - y*b.y - z*b.z;
		float qx = w*b.x + x*b.w + y*b.z - z*b.y;
		float qy = w*b.y + y*b.w + z*b.x - x*b.z;
		z = w*b.z + z*b.w + x*b.y - y*b.x;
		w = qw;
		x = qx;
		y = qy;
	}

	/// Is this Quatrn equal to Quatrn s, discarding relative error fudge.
	bool almostEqual(Quatrn s, float fudge=0.0001)
	{	for (int i=0; i<v.length; i++)
			if (!yage.core.math.math.almostEqual(v[i], s.v[i], fudge))
				return false;
		return true;
	}

	/// Return the conjugate the Quaternion
	Quatrn conjugate()
	{	return Quatrn(-x, -y, -z, w);
	}

	/**
	 * Return the inverse of the Quaternion.
	 * This is the equivalent of the Quaternion's rotation in reverse. */
	Quatrn inverse()
	{	float l2 = (w*w + x*x + y*y + z*z);
		if (l2==0)
			return *this;
		float l = sqrt(l2);
		return Quatrn(-x/l, -y/l, -z/l, w/l);
	}

	/// Get the magnitude of the Quaternion.
	float length()
	{	return sqrt(w*w + x*x + y*y + z*z);
	}

	/// Multiply the angle of the quaternion by this amount.  This is an in-place operation.
	void multiplyAngle(float amount)
	{	w =cos(acos(w)*amount);
	}

	/// Return a normalized version of the Quaternion.
	Quatrn normalize()
	{	float s = 1/sqrt(w*w + x*x + y*y + z*z);
		if (s!=float.infinity)
			return Quatrn(x*s, y*s, z*s, w*s);
		else return *this;
	}

	///
	void *ptr()
	{	return v.ptr;
	}

	/**
	 * Return a new Quaternion that is the sum of the current rotation and the
	 * new rotation of the parameter. */
	Quatrn rotate(Quatrn q)
	{	return (*this)*q;
	}

	Quatrn rotate(Vec!(3, float) axis)
	{	return (*this)*axis.toQuatrn();
	}

	Quatrn rotate(Matrix rot)
	{	return (*this)*rot.toQuatrn();
	}





	/**
	 * Return a rotation that is interpolated between this Quaternion and
	 * the Quatrn q. */
	Quatrn slerp(Quatrn q, float interp)
	{	Quatrn res=void;

		// figure out if second quaternion is reversed
		int i;
		float a=0, b=0;
		a+= (x-q.x)*(x-q.x) + (y-q.y)*(y-q.y) + (z-q.z)*(z-q.z) + (w-q.w)*(w-q.w);
		b+= (x+q.x)*(x+q.x) + (y-q.y)*(y-q.y) + (z-q.z)*(z-q.z) + (w-q.w)*(w-q.w);
		//if (a>b) // In the formula on m&q faq but breaks the code!
		//	q=q.inverse();

		float cosom = x*q.x + y*q.y + z*q.z + w*q.w;
		double scl, sclq;

		if ( (1.0f+cosom) > 0.00000001f)
		{	if ( (1.0f-cosom) > 0.0000001f)
			{	double omega = acos(cosom);
				double sinom = sin(omega);
				scl = sin( (1.0f-interp)*omega ) / sinom;
				sclq = sin( interp*omega ) / sinom;
			}
			else
			{	scl = 1.0f-interp;
				sclq = interp;
			}
			res.x = (scl*x + sclq*q.x);
			res.y = (scl*y + sclq*q.y);
			res.z = (scl*z + sclq*q.z);
			res.w = (scl*w + sclq*q.w);
		}else
		{	res.x = -y;
			res.y =  x;
			res.z = -w;
			res.w =  z;

			scl = sin( (1.0f-interp)*0.5f*PI );
			sclq = sin( interp*0.5f*PI );
			res.x = scl*x + sclq*x;
			res.y = scl*y + sclq*y;
			res.z = scl*z + sclq*z;
		}
		return res;
	}

	/// Create a Vec3f rotation axis from this Quaternion
	Vec!(3, float) toAxis()
	{	
		double angle;
		if (1 <= w && w < 1.0001)
		{	angle = 0;
			w = 1; // correct floating point rounding
		}
		else
			angle = acos(w)*2;
		assert(!isNaN(angle), format("%f", w));
		if (angle != 0)
		{	auto sin_a = sqrt(1 - w*w);
			if (abs(sin_a) < 0.0005)	// arbitrary small number
				sin_a = 1;
			Vec3f axis;
			auto inv_sin_a = 1/sin_a;
			axis.x = x*inv_sin_a;
			axis.y = y*inv_sin_a;
			axis.z = z*inv_sin_a;
			return axis.length(angle);
		}
		return Vec3f.ZERO;	// zero vector, no rotation
	}

	/// Create a rotation Matrix from this quaternion.
	Matrix toMatrix()
	{	Matrix res=void;
		res.v[0] = 1-2*(y*y + z*z);
		res.v[1] =   2*(x*y + z*w);
		res.v[2] =   2*(x*z - y*w);
		res.v[3] =   0;
		res.v[4] =   2*(x*y - z*w);
		res.v[5] = 1-2*(x*x + z*z);
		res.v[6] =   2*(y*z + x*w);
		res.v[7] =   0;
		res.v[8] =   2*(x*z + y*w);
		res.v[9] =   2*(y*z - x*w);
		res.v[10] = 1-2*(x*x + y*y);
		res.v[11..15] = 0;
		res.v[15] = 1;
		return res;
	}

	/// Return a string representation of this quaternion for human reading.
	char[] toString()
	{	return format("<%f %f %f %f>", x, y, z, w);
	}
}
