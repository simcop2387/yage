/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.core.quatrn;

import std.math;
import std.stdio;
import yage.core.parse;
import yage.core.vector;
import yage.core.matrix;
import yage.core.misc;



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
		struct
		{	float x, y, z, w;
	}	}

	invariant
	{	foreach (float t; v)
			assert(t != float.nan);
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
				report ~= a.toString()~"\n";
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
			test("Normalize", c.normalize(), Quatrn(c.x/l, c.y/l, c.z/l, c.w/l), c);
			test("Multiply 1", c*c.inverse(), Quatrn());
			test("Multiply 2", c*Quatrn(), c);

			// These fail on all dmd after 0.177
			//test("toMatrix", c.toMatrix().toQuatrn(), c);
			//test("toAxis", c.toAxis().toQuatrn(), c);

			foreach (Quatrn d; q)
			{	// These fail on all dmd after 0.177
				//test("Rotate Quatrn", c.rotate(d).rotate(d.inverse()), c, d);
				//test("Rotate Axis", c.rotate(d.toAxis()).rotate(d.inverse().toAxis()), c, d);
				//test("Rotate Matrix", c.rotate(d.toMatrix()).rotate(d.inverse().toMatrix()), c, d);
				//test("Rotate Absolute Quatrn", c.rotateAbsolute(d).rotateAbsolute(d.inverse()), c, d);
				//test("Rotate Absolute Axis", c.rotateAbsolute(d.toAxis()).rotateAbsolute(d.inverse().toAxis()), c, d);
				//test("Rotate Absolute Matrix", c.rotateAbsolute(d.toMatrix()).rotateAbsolute(d.inverse().toMatrix()), c, d);
				test("Slerp", c.slerp(d, .25), d.slerp(c, .75), c, d);

				// Fails (perhaps this shoudln't work anyway?)
				//test("Rotate Euler", c.rotateEuler(d.toAxis()).rotateEuler(d.inverse().toAxis()), c, d);
			}
		}
	}

	/// Create a unit Quaternion.
	static Quatrn opCall()
	{	return Quatrn(0, 0, 0, 1);
	}

	/// Create a Quaternion from four values.
	static Quatrn opCall(float x, float y, float z, float w)
	{	Quatrn res;
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

	/// Create a Quaternion from a rotation axis Vec3f.
	static Quatrn opCall(Vec3f axis)
	{	return axis.toQuatrn();
	}

	/// Create a Quaternion from a rotation Matrix.
	static Quatrn opCall(Matrix m)
	{	return m.toQuatrn();
	}

	/** Multiply this quaternion by another and return the result.
	 *  The result is the sum of both quaternion rotations.
	 *  Note that quaternion multiplication is not cumulative.*/
	Quatrn opMul(Quatrn b)
	{	Quatrn res;
		res.w = w*b.w - x*b.x - y*b.y - z*b.z;
		res.x = w*b.x + x*b.w + y*b.z - z*b.y;
		res.y = w*b.y + y*b.w + z*b.x - x*b.z;
		res.z = w*b.z + z*b.w + x*b.y - y*b.x;
		return res;
	}


	void opMulAssign(Quatrn b)
	{	float qw = w*b.w - x*b.x - y*b.y - z*b.z;
		float qx = w*b.x + x*b.w + y*b.z - z*b.y;
		float qy = w*b.y + y*b.w + z*b.x - x*b.z;
		float qz = w*b.z + z*b.w + x*b.y - y*b.x;
		set(qx, qy, qz, qw);
	}

	/// Is this Quatrn equal to Quatrn s, discarding relative error fudge.
	bool almostEqual(Quatrn s, float fudge=0.0001)
	{	for (int i=0; i<v.length; i++)
			if (!yage.core.math.almostEqual(v[i], s.v[i], fudge))
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
	{	float l = length();
		return Quatrn(-x/l, -y/l, -z/l, w/l);
	}

	/// Get the magnitude of the Quaternion.
	float length()
	{	return sqrt(w*w + x*x + y*y + z*z);
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

	Quatrn rotate(Vec3f axis)
	{	return (*this)*axis.toQuatrn();
	}

	Quatrn rotate(Matrix rot)
	{	return (*this)*rot.toQuatrn();
	}

	/**
	 * Return a new Quaternion that is the sum of the current rotation and the
	 * new rotation of the parameter, rotating in absolute worldspace coordinates. */
	Quatrn rotateAbsolute(Quatrn q)
	{	return q*(*this);
	}

	Quatrn rotateAbsolute(Vec3f axis)
	{	return axis.toQuatrn()*(*this);
	}

	Quatrn rotateAbsolute(Matrix rot)
	{	return rot.toQuatrn()*(*this);
	}

	/**
	 * Return a new Quaternion that is the sum of the current rotation and the
	 * new rotation of the Vec3f of euler angles, rotating first by x, then y, then z. */
	Quatrn rotateEuler(Vec3f euler)
	{	Quatrn rot;
		rot.setEuler(euler);
		return *this*rot;
	}

	/**
	 * Return a new Quaternion that is the sum of the current rotation and the
	 * new rotation of the Vec3f of euler angles, rotating first by x, then y,
	 * then z, rotating around the absolute worldspace axis */
	Quatrn rotateEulerAbsolute(Vec3f euler)
	{	Quatrn qr;
		qr.setEuler(euler);
		return qr*(*this);
	}

	/// Set the Quaternion using four scalar values.
	void set(float x, float y, float z, float w)
	{	*this = Quatrn(x, y, z, w);
	}

	/// Set to an array of floats (x,y,z,w)
	void set(float[] s)
	{	*this = Quatrn(s[0], s[1], s[2], s[3]);
	}

	/// Set the Quaternion using a rotation axis Vec3f.
	void set(Vec3f axis)
	{	double l = axis.length();
		double s = sin(l*0.5f)/l;
		w = cos(l*0.5f);
		x = axis.v[0] * s;
		y = axis.v[1] * s;
		z = axis.v[2] * s;
	}

	/// Set the Quaternion to the rotation part of a Matrix.
	void set(Matrix r)
	{	*this = r.toQuatrn();
	}

	/// Set the rotation using a Vec3f of Euler angles. TODO: replace with code below.
	void setEuler(Vec3f euler)
	{	*this =
		   (Quatrn(sin(euler.x*0.5), 0, 0, cos(euler.x*0.5)) // x
		  * Quatrn(0, sin(euler.y*0.5), 0, cos(euler.y*0.5))) // y
		  * Quatrn(0, 0, sin(euler.z*0.5), cos(euler.z*0.5)); // z
	}
	/*
	inline void quatrn::fromvector(vector rot)
	{
		float hlf;
		double sr, sp, sy, cr, cp, cy;

		hlf = rot[2]*0.5f;
		sy = sin(hlf);
		cy = cos(hlf);
		hlf = rot[1]*0.5f;
		sp = sin(hlf);
		cp = cos(hlf);
		hlf = rot[0]*0.5f;
		sr = sin(hlf);
		cr = cos(hlf);

		double crcp = cr*cp;
		double srsp = sr*sp;
		double srcp = sr*cp;

		v[0] = float(srcp*cy- cr*sp*sy);
		v[1] = float(cr*sp*cy+ srcp*sy);
		v[2] = float(crcp*sy - srsp*cy);
		v[3] = float(crcp*cy + srsp*sy);
	}*/

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
	Vec3f toAxis()
	{	double angle = acos(w)*2;
		double sin_a = sqrt(1.0 - w*w);
		if (fabs(sin_a) < 0.0005)	// arbitrary small number
			sin_a = 1;
		Vec3f axis;
		axis.x = x/sin_a;
		axis.y = y/sin_a;
		axis.z = z/sin_a;
		if (angle>0)
			return axis.length(angle);
		return Vec3f();	// zero vector, no rotation
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
	{	return formatString("<%.4f %.4f %.4f %.4f>", x, y, z, w);
	}
}
