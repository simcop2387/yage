/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.core.matrix;

import std.math;
import std.stdio;
import std.random;
import yage.core.vector;
import yage.core.quatrn;
import yage.core.math;
import yage.core.misc;
import yage.core.parse;

/**
 * A 4x4 matrix class for 3D transformations.
 * Column major order is used, just like OpenGL.  This is defined as a struct instead of a
 * class so it can be created and destroyed without any dynamic memory allocation.
 * The Euler operations may be unreliable and should be used cautiously.
 * See_Also:
 * <a href="http://en.wikipedia.org/wiki/Transformation_matrix">Wikipedia: Transformation Matrix</a><br>
 * <a href="http://www.gamedev.net/reference/articles/article1691.asp">The Matrix and Quaternion Faq</a>*/
struct Matrix
{
	/// The 16 values of the Matrix.
	union
	{	float[16] v =  [1, 0, 0, 0,
						0, 1, 0, 0,
						0, 0, 1, 0,
						0, 0, 0, 1,];
		//Vec4f[4] row;	// produces a forward reference error
		struct
		{	float v00, v01, v02, v03;
			float v10, v11, v12, v13;
			float v20, v21, v22, v23;
			float v30, v31, v32, v33;
		}
	}
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
		void test(char[] name, Matrix[] args ...)
		{	char[] report = "\nFailed on test '"~name~"' With Matrices:\n\n";
			foreach(Matrix a; args)
				report ~= a.toString()~"\n";
			assert(args[0].almostEqual(args[1], 0.0005), report);
		}

		// Matrices used in testing
		Matrix[] m;
		m~= Matrix();
		m~= Vec3f(0, 0, 0).toMatrix().move(Vec3f(.1, 3, 0));//Matrix([0.0f,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]);
		m~= Vec3f(0, 0, 1).toMatrix().move(Vec3f(.1, 3, 0));
		m~= Vec3f(1, 3, -1).toMatrix().move(Vec3f(2, -1, 1));
		m~= Vec3f(-.75, -1, -1.7).toMatrix().move(Vec3f(-1, 0, 4));
		m~= Vec3f(-.371, .1, -1.570796).toMatrix().move(Vec3f(1000, 2000, 4000));
		m~= Vec3f(0.0001, 0.0001, 0.0001).toMatrix();
		m~= Matrix([1,0,0,0, 0,-1,0,0, 0,0,-1,0, 0,0,0,1]);	// 7, Branch B of toQuatrn();
		m~= Matrix([-1,0,0,0, 0,1,0,0, 0,0,-1,0, 0,0,0,1]);	// 8, Branch C of toQuatrn();
		m~= Matrix([-1,0,0,0, 0,-1,0,0, 0,0,1,0, 0,0,0,1]);	// 9, Branch D of toQuatrn();

		foreach (Matrix c; m)
		{	test("Transpose", c, c.transpose().transpose());
			test("Negate", c, c.negate().negate());
			test("Inverse 1", c, c.inverse().inverse());
			test("Inverse 2", Matrix(), c*c.inverse(), c);
			test("Identity", c, c*Matrix()); // [Below] compared this way because non-rotation values are lost.
			// These fail on all dmd after 0.177
			//test("toQuatrn & toAxis", c.toAxis().toMatrix(), c.toQuatrn().toMatrix(), c);
			//Matrix res = c;
			//res.set(c.toQuatrn());
			//test("Set Rotation", res, c);

			foreach (Matrix d; m)
			{	test("Multiply & Inverse", c, c*d*d.inverse(), d);
				// These fail on all dmd after 0.177
				//test("MoveRelative", c, c.moveRelative(d.toAxis()).moveRelative(d.toAxis().negate()), d);
				//test("Rotate Matrix", c, c.rotate(d).rotate(d.inverse()), d);
				//test("Rotate Quatrn", c, c.rotate(d.toQuatrn()).rotate(d.toQuatrn().inverse()), d);
				//test("Rotate Axis", c, c.rotate(d.toAxis()).rotate(d.toAxis().negate()), d);

				// These don't pass for Matrices 7, 8, and 9
				//test("Rotate Absolute Matrix", c, c.rotateAbsolute(d).rotateAbsolute(d.inverse()), d);
				//test("Rotate Absolute Quatrn", c, c.rotateAbsolute(d.toQuatrn()).rotateAbsolute(d.toQuatrn().inverse()), d);
				//test("Rotate Absolute Axis", c, c.rotateAbsolute(d.toAxis()).rotateAbsolute(d.toAxis().inverse()), d);
			}
		}
	}

	/// Create an identity Matrix.
	static Matrix opCall()
	{	Matrix m;
		return m;
	}

	/// Create a Matrix from a float[16].
	static Matrix opCall(float[] values)
	{	assert(values.length>=16);
		Matrix res;
		res.v[0..16] = values[0..16];
		return res;
	}

	/// Create a Matrix from the rotation values of a Quaternion.
	static Matrix opCall(Quatrn rotation)
	{	return Matrix().rotate(rotation);
	}

	/// Is this Matrix equal to Matrix s, discarding relative error fudge.
	bool almostEqual(Matrix s, float fudge=0.0001)
	{	for (int i=0; i<v.length; i++)
			if (!yage.core.math.almostEqual(v[i], s.v[i], fudge))
				return false;
		return true;
	}

	/// Return the determinant of the Matrix.
	float determinant()
	{	return	v[12]*v[ 9]*v[ 6]*v[ 3] - v[ 8]*v[13]*v[ 6]*v[ 3] -
				v[12]*v[ 5]*v[10]*v[ 3] + v[ 4]*v[13]*v[10]*v[ 3] +
				v[ 8]*v[ 5]*v[14]*v[ 3] - v[ 4]*v[ 9]*v[14]*v[ 3] -
				v[12]*v[ 9]*v[ 2]*v[ 7] + v[ 8]*v[13]*v[ 2]*v[ 7] +
				v[12]*v[ 1]*v[10]*v[ 7] - v[ 0]*v[13]*v[10]*v[ 7] -
				v[ 8]*v[ 1]*v[14]*v[ 7] + v[ 0]*v[ 9]*v[14]*v[ 7] +
				v[12]*v[ 5]*v[ 2]*v[11] - v[ 4]*v[13]*v[ 2]*v[11] -
				v[12]*v[ 1]*v[ 6]*v[11] + v[ 0]*v[13]*v[ 6]*v[11] +
				v[ 4]*v[ 1]*v[14]*v[11] - v[ 0]*v[ 5]*v[14]*v[11] -
				v[ 8]*v[ 5]*v[ 2]*v[15] + v[ 4]*v[ 9]*v[ 2]*v[15] +
				v[ 8]*v[ 1]*v[ 6]*v[15] - v[ 0]*v[ 9]*v[ 6]*v[15] -
				v[ 4]*v[ 1]*v[10]*v[15] + v[ 0]*v[ 5]*v[10]*v[15];
	}

	/**
	 * Return a copy of this Matrix that has been inverted.
	 * Throws an exception if this Matrix has no _inverse.  This occurs when the determinant is zero. */
	Matrix inverse()
	{	float d = determinant();
		//assert(d!=0, "Cannot invert a Matrix with a determinant of zero, original matrix is:\n"~toString());
		Matrix res;
		res.v[ 0]= (-v[13]*v[10]*v[7] +v[9]*v[14]*v[7] +v[13]*v[6]*v[11]-v[5]*v[14]*v[11]-v[9]*v[6]*v[15] +v[5]*v[10]*v[15])/d;
		res.v[ 4]= ( v[12]*v[10]*v[7] -v[8]*v[14]*v[7] -v[12]*v[6]*v[11]+v[4]*v[14]*v[11]+v[8]*v[6]*v[15] -v[4]*v[10]*v[15])/d;
		res.v[ 8]= (-v[12]*v[9]* v[7] +v[8]*v[13]*v[7] +v[12]*v[5]*v[11]-v[4]*v[13]*v[11]-v[8]*v[5]*v[15] +v[4]*v[9]* v[15])/d;
		res.v[12]= ( v[12]*v[9]* v[6] -v[8]*v[13]*v[6] -v[12]*v[5]*v[10]+v[4]*v[13]*v[10]+v[8]*v[5]*v[14] -v[4]*v[9]* v[14])/d;
		res.v[ 1]= ( v[13]*v[10]*v[3] -v[9]*v[14]*v[3] -v[13]*v[2]*v[11]+v[1]*v[14]*v[11]+v[9]*v[2]*v[15] -v[1]*v[10]*v[15])/d;
		res.v[ 5]= (-v[12]*v[10]*v[3] +v[8]*v[14]*v[3] +v[12]*v[2]*v[11]-v[0]*v[14]*v[11]-v[8]*v[2]*v[15] +v[0]*v[10]*v[15])/d;
		res.v[ 9]= ( v[12]*v[9]* v[3] -v[8]*v[13]*v[3] -v[12]*v[1]*v[11]+v[0]*v[13]*v[11]+v[8]*v[1]*v[15] -v[0]*v[9]* v[15])/d;
		res.v[13]= (-v[12]*v[9]* v[2] +v[8]*v[13]*v[2] +v[12]*v[1]*v[10]-v[0]*v[13]*v[10]-v[8]*v[1]*v[14] +v[0]*v[9]* v[14])/d;
		res.v[ 2]= (-v[13]*v[6]* v[3] +v[5]*v[14]*v[3] +v[13]*v[2]*v[7]	-v[1]*v[14]*v[7] -v[5]*v[2]*v[15] +v[1]*v[6]* v[15])/d;
		res.v[ 6]= ( v[12]*v[6]* v[3] -v[4]*v[14]*v[3] -v[12]*v[2]*v[7] +v[0]*v[14]*v[7] +v[4]*v[2]*v[15] -v[0]*v[6]* v[15])/d;
		res.v[10]= (-v[12]*v[5]* v[3] +v[4]*v[13]*v[3] +v[12]*v[1]*v[7]	-v[0]*v[13]*v[7] -v[4]*v[1]*v[15] +v[0]*v[5]* v[15])/d;
		res.v[14]= ( v[12]*v[5]* v[2] -v[4]*v[13]*v[2] -v[12]*v[1]*v[6]	+v[0]*v[13]*v[6] +v[4]*v[1]*v[14] -v[0]*v[5]* v[14])/d;
		res.v[ 3]= ( v[9]* v[6]* v[3] -v[5]*v[10]*v[3] -v[9]* v[2]*v[7]	+v[1]*v[10]*v[7] +v[5]*v[2]*v[11] -v[1]*v[6]* v[11])/d;
		res.v[ 7]= (-v[8]* v[6]* v[3] +v[4]*v[10]*v[3] +v[8]* v[2]*v[7]	-v[0]*v[10]*v[7] -v[4]*v[2]*v[11] +v[0]*v[6]* v[11])/d;
		res.v[11]= ( v[8]* v[5]* v[3] -v[4]*v[9]* v[3] -v[8]* v[1]*v[7]	+v[0]*v[9]* v[7] +v[4]*v[1]*v[11] -v[0]*v[5]* v[11])/d;
		res.v[15]= (-v[8]* v[5]* v[2] +v[4]*v[9]* v[2] +v[8]* v[1]*v[6]	-v[0]*v[9]* v[6] -v[4]*v[1]*v[10] +v[0]*v[5]* v[10])/d;
		return res;
	}

	/// Is this an identity Matrix?
	bool isIdentity()
	{	if ((v[0]==1 && v[5]==1 && v[10]==1 && v[15]==1)
			&& (v[1]==0 && v[2]==0  && v[3]==0  && v[4]==0
			&& v[6]==0  && v[7]==0  && v[8]==0  && v[9]==0
			&& v[11]==0 && v[12]==0 && v[13]==0 && v[14]==0))
			return true;
		return false;
	}

	/// Return a copy of this Matrix with its position values incremented by vec.
	Matrix move(Vec3f vec)
	{	Matrix res = *this;
		res.v[12] += vec.x;
		res.v[13] += vec.y;
		res.v[14] += vec.z;
		return res;
	}

	/** Return a copy of this Matrix with its position values incremented relative to its rotation.
	 *  Consider it to be moved in the direction that it's currently rotated. */
	Matrix moveRelative(Vec3f direction)
	{	// The same as rotating the direction by the relative matrix and sending it to move().
		return move(
		Vec3f( direction.x*v[0] + direction.y*v[4] + direction.z*v[8],
				direction.x*v[1] + direction.y*v[5] + direction.z*v[9],
				direction.x*v[2] + direction.y*v[6] + direction.z*v[10]));
	}

	/// Return a copy of this Matrix with all values negated.
	Matrix negate()
	{	Matrix res;
		for (size_t i; i<16; i++)
			res.v[i] = -v[i];
		return res;
	}

	/// Get element i from the Matrix
	float opIndex(size_t i)
	{	return v[i];
	}

	/// Assign a value to element i.
	float opIndexAssign(float value, size_t i)
	{	return v[i] = value;
	}

	/**
	 * Multiply this matrix by the 3-component Vec3f; assumes the 4th Vec3f component is 1.
	 * This is the equivalent of transforming the Vector by this Matrix. */
	Vec3f opMul(Vec3f vec)
	{	Vec3f res=void;
		res.x = vec.x*v[0] + vec.y*v[4] + vec.z*v[8]  + v[12];
		res.y = vec.x*v[1] + vec.y*v[5] + vec.z*v[9]  + v[13];
		res.z = vec.x*v[2] + vec.y*v[6] + vec.z*v[10] + v[14];
		return res;
	}

	/// Multiply two matrices and return a third Matrix result.
	Matrix opMul(Matrix b)
	{	Matrix result=void;
		result.v[ 0] = v[ 0]*b.v[ 0] + v[ 1]*b.v[ 4] + v[ 2]*b.v[ 8] + v[ 3]*b.v[12];
		result.v[ 1] = v[ 0]*b.v[ 1] + v[ 1]*b.v[ 5] + v[ 2]*b.v[ 9] + v[ 3]*b.v[13];
		result.v[ 2] = v[ 0]*b.v[ 2] + v[ 1]*b.v[ 6] + v[ 2]*b.v[10] + v[ 3]*b.v[14];
		result.v[ 3] = v[ 0]*b.v[ 3] + v[ 1]*b.v[ 7] + v[ 2]*b.v[11] + v[ 3]*b.v[15];

		result.v[ 4] = v[ 4]*b.v[ 0] + v[ 5]*b.v[ 4] + v[ 6]*b.v[ 8] + v[ 7]*b.v[12];
		result.v[ 5] = v[ 4]*b.v[ 1] + v[ 5]*b.v[ 5] + v[ 6]*b.v[ 9] + v[ 7]*b.v[13];
		result.v[ 6] = v[ 4]*b.v[ 2] + v[ 5]*b.v[ 6] + v[ 6]*b.v[10] + v[ 7]*b.v[14];
		result.v[ 7] = v[ 4]*b.v[ 3] + v[ 5]*b.v[ 7] + v[ 6]*b.v[11] + v[ 7]*b.v[15];

		result.v[ 8] = v[ 8]*b.v[ 0] + v[ 9]*b.v[ 4] + v[10]*b.v[ 8] + v[11]*b.v[12];
		result.v[ 9] = v[ 8]*b.v[ 1] + v[ 9]*b.v[ 5] + v[10]*b.v[ 9] + v[11]*b.v[13];
		result.v[10] = v[ 8]*b.v[ 2] + v[ 9]*b.v[ 6] + v[10]*b.v[10] + v[11]*b.v[14];
		result.v[11] = v[ 8]*b.v[ 3] + v[ 9]*b.v[ 7] + v[10]*b.v[11] + v[11]*b.v[15];

		result.v[12] = v[12]*b.v[ 0] + v[13]*b.v[ 4] + v[14]*b.v[ 8] + v[15]*b.v[12];
		result.v[13] = v[12]*b.v[ 1] + v[13]*b.v[ 5] + v[14]*b.v[ 9] + v[15]*b.v[13];
		result.v[14] = v[12]*b.v[ 2] + v[13]*b.v[ 6] + v[14]*b.v[10] + v[15]*b.v[14];
		result.v[15] = v[12]*b.v[ 3] + v[13]*b.v[ 7] + v[14]*b.v[11] + v[15]*b.v[15];
		return result;
	}

	/// Multiply this Matrix by another matrix and store the result in this Matrix.
	Matrix opMulAssign(Matrix b)
	{	float[16] result=void;
		result[ 0] = v[ 0]*b.v[ 0] + v[ 1]*b.v[ 4] + v[ 2]*b.v[ 8] + v[ 3]*b.v[12];
		result[ 1] = v[ 0]*b.v[ 1] + v[ 1]*b.v[ 5] + v[ 2]*b.v[ 9] + v[ 3]*b.v[13];
		result[ 2] = v[ 0]*b.v[ 2] + v[ 1]*b.v[ 6] + v[ 2]*b.v[10] + v[ 3]*b.v[14];
		result[ 3] = v[ 0]*b.v[ 3] + v[ 1]*b.v[ 7] + v[ 2]*b.v[11] + v[ 3]*b.v[15];

		result[ 4] = v[ 4]*b.v[ 0] + v[ 5]*b.v[ 4] + v[ 6]*b.v[ 8] + v[ 7]*b.v[12];
		result[ 5] = v[ 4]*b.v[ 1] + v[ 5]*b.v[ 5] + v[ 6]*b.v[ 9] + v[ 7]*b.v[13];
		result[ 6] = v[ 4]*b.v[ 2] + v[ 5]*b.v[ 6] + v[ 6]*b.v[10] + v[ 7]*b.v[14];
		result[ 7] = v[ 4]*b.v[ 3] + v[ 5]*b.v[ 7] + v[ 6]*b.v[11] + v[ 7]*b.v[15];

		result[ 8] = v[ 8]*b.v[ 0] + v[ 9]*b.v[ 4] + v[10]*b.v[ 8] + v[11]*b.v[12];
		result[ 9] = v[ 8]*b.v[ 1] + v[ 9]*b.v[ 5] + v[10]*b.v[ 9] + v[11]*b.v[13];
		result[10] = v[ 8]*b.v[ 2] + v[ 9]*b.v[ 6] + v[10]*b.v[10] + v[11]*b.v[14];
		result[11] = v[ 8]*b.v[ 3] + v[ 9]*b.v[ 7] + v[10]*b.v[11] + v[11]*b.v[15];

		result[12] = v[12]*b.v[ 0] + v[13]*b.v[ 4] + v[14]*b.v[ 8] + v[15]*b.v[12];
		result[13] = v[12]*b.v[ 1] + v[13]*b.v[ 5] + v[14]*b.v[ 9] + v[15]*b.v[13];
		result[14] = v[12]*b.v[ 2] + v[13]*b.v[ 6] + v[14]*b.v[10] + v[15]*b.v[14];
		result[15] = v[12]*b.v[ 3] + v[13]*b.v[ 7] + v[14]*b.v[11] + v[15]*b.v[15];
		set(result);
		return *this;
	}

	/// Perform Matrix multiplication in reverse (since Matrix multiplication is not cummulative.) Is this backwards?
	Matrix postMultiply(Matrix b)
	{	return *this*b;
	}

	///
	Vec3f position()
	{	return Vec3f(v[12..15]);		
	}
	
	///
	void *ptr()
	{	return v.ptr;
	}

	/// Return a copy of this Matrix rotated by an axis Vec3f.
	Matrix rotate(Vec3f axis)
	{	return rotate(axis.toMatrix());
	}

	/// Return a copy of this Matrix rotated by a Quatrn, relative to it's current rotation axis.
	Matrix rotate(Quatrn rotation)
	{	return rotate(rotation.toMatrix());
	}

	/**
	 * Return a copy of this Matrix rotated by the rotation values of another Matrix.
	 * This is equivalent to a post-multiplication of only the rotation values.*/
	Matrix rotate(Matrix b)
	{	Matrix res=void;
		res.v[ 0] = b.v[ 0]*v[ 0] + b.v[ 1]*v[ 4] + b.v[ 2]*v[ 8];
		res.v[ 1] = b.v[ 0]*v[ 1] + b.v[ 1]*v[ 5] + b.v[ 2]*v[ 9];
		res.v[ 2] = b.v[ 0]*v[ 2] + b.v[ 1]*v[ 6] + b.v[ 2]*v[10];
		res.v[ 3] = v[3];
		res.v[ 4] = b.v[ 4]*v[ 0] + b.v[ 5]*v[ 4] + b.v[ 6]*v[ 8];
		res.v[ 5] = b.v[ 4]*v[ 1] + b.v[ 5]*v[ 5] + b.v[ 6]*v[ 9];
		res.v[ 6] = b.v[ 4]*v[ 2] + b.v[ 5]*v[ 6] + b.v[ 6]*v[10];
		res.v[ 7] = v[7];
		res.v[ 8] = b.v[ 8]*v[ 0] + b.v[ 9]*v[ 4] + b.v[10]*v[ 8];
		res.v[ 9] = b.v[ 8]*v[ 1] + b.v[ 9]*v[ 5] + b.v[10]*v[ 9];
		res.v[10] = b.v[ 8]*v[ 2] + b.v[ 9]*v[ 6] + b.v[10]*v[10];
		res.v[11..16] = v[11..16];
		return res;
	}

	/**
	 * Return a copy of this Matrix with its rotation values incremented by an
	 * axis Vec3f, relative to the absolute worldspace axis.
	 * This function hasn't been verified to be correct in all circumstances. */
	Matrix rotateAbsolute(Vec3f axis)
	{	Matrix res = *this;
		res.set(axis.toQuatrn()*toQuatrn());
		return res;
		//return axis.toMatrix()*(*this);
	}

	/**
	 * Return a copy of this Matrix with its rotation values incremented by a
	 * Quatrn, relative to the absolute worldspace axis.
	 * This function hasn't been verified to be correct in all circumstances. */
	Matrix rotateAbsolute(Quatrn rotation)
	{	Matrix res = *this;
		res.set(rotation*toQuatrn());
		return res;
		//return rotation.toMatrix()*(*this);
	}

	/**
	 * Return a copy of this Matrix with its rotation values incremented by the
	 * rotation values of another Matrix, relative to the absolute worldspace axis.
	 * This function hasn't been verified to be correct in all circumstances. */
	Matrix rotateAbsolute(Matrix m)
	{	Matrix res = *this;
		res.set(m.toQuatrn()*toQuatrn());
		return res;
		//return m*(*this);
	}

	/**
	 * Return a copy of this Matrix with its rotation values incremented by a Vec3f of Euler rotation angles,
	 * relative to it's current rotation axis.  First by x, then y, then z.
	 * This function hasn't been verified to be correct in all circumstances. */
	Matrix rotateEuler(Vec3f euler)
	{	double cx = cos(euler.x);
		double sx = sin(euler.x);
		double cy = cos(euler.y);
		double sy = sin(euler.y);
		double cz = cos(euler.z);
		double sz = sin(euler.z);
		double sxsy = sx*sy;
		double cxsy = cx*sy;
		Matrix result=void;
		result[ 0] = cy*cz*v[ 0] + cy*sz*v[ 4] + -sy*v[ 8];
		result[ 1] = cy*cz*v[ 1] + cy*sz*v[ 5] + -sy*v[ 9];
		result[ 2] = cy*cz*v[ 2] + cy*sz*v[ 6] + -sy*v[10];
		result[ 3] = v[3];
		result[ 4] = (sxsy*cz - cx*sz)*v[ 0] + (sxsy*sz + cx*cz)*v[ 4] + sx*cy*v[ 8];
		result[ 5] = (sxsy*cz - cx*sz)*v[ 1] + (sxsy*sz + cx*cz)*v[ 5] + sx*cy*v[ 9];
		result[ 6] = (sxsy*cz - cx*sz)*v[ 2] + (sxsy*sz + cx*cz)*v[ 6] + sx*cy*v[10];
		result[ 7] = v[7];
		result[ 8] = (cxsy*cz + sx*sz)*v[ 0] + (cxsy*sz - sx*cz)*v[ 4] + cx*cy*v[ 8];
		result[ 9] = (cxsy*cz + sx*sz)*v[ 1] + (cxsy*sz - sx*cz)*v[ 5] + cx*cy*v[ 9];
		result[10] = (cxsy*cz + sx*sz)*v[ 2] + (cxsy*sz - sx*cz)*v[ 6] + cx*cy*v[10];
		result.v[11..16] = v[11..16];
		return result;
	}

	/**
	 * The same as above, but rotated around the absolute worldspace axis.
	 * This function hasn't been verified to be correct in all circumstances. */
	Matrix rotateEulerAbsolute(Vec3f euler)
	{	Matrix res = *this;
		res.rotateEuler(euler);
		res.set(res.toQuatrn()*toQuatrn());
		return res;
	}

	/// Set to an array of 16 values.
	void set(float[16] values)
	{	v[0..16] = values[0..16];
	}

	/// Set the rotation values of this Matrix from an axis vector.
	void set(Vec3f axis)
	{	setRotation(axis.toQuatrn().toMatrix());
	}

	/// Set the rotation values of the Matrix from a Quatrn.
	void set(Quatrn rot)
	{	setRotation(rot.toMatrix());
	}

	/// Set the rotation values of the matrix from a vector containing euler angles.
	void setEuler(Vec3f euler)
	{	double cx = cos(euler.x);
		double sx = sin(euler.x);
		double cy = cos(euler.y);
		double sy = sin(euler.y);
		double cz = cos(euler.z);
		double sz = sin(euler.z);
		double sxsy = sx*sy;
		double cxsy = cx*sy;
		v[0] = (cy*cz);
		v[1] = (cy*sz);
		v[2] = (-sy);
		v[4] = (sxsy*cz - cx*sz);
		v[5] = (sxsy*sz + cx*cz);
		v[6] = (sx*cy);
		v[8] = cxsy*cz + sx*sz;
		v[9] = cxsy*sz - sx*cz;
		v[10]= cx*cy;
	}

	///
	void setPosition(Vec3f position)
	{	v[12..15] = position.v[0..3];
	}
	
	/// Set the rotation values of this Matrix from another Matrix or Quatrn.
	void setRotation(Matrix rot)
	{	v[0..3]  = rot.v[0..3];
		v[4..7]  = rot.v[4..7];
		v[8..11] = rot.v[8..11];
	}
	/// ditto
	void setRotation(Quatrn rot)
	{	v[0] = 1-2*(rot.y*rot.y + rot.z*rot.z);
		v[1] =   2*(rot.x*rot.y + rot.z*rot.w);
		v[2] =   2*(rot.x*rot.z - rot.y*rot.w);
		//v[3] =   0;
		v[4] =   2*(rot.x*rot.y - rot.z*rot.w);
		v[5] = 1-2*(rot.x*rot.x + rot.z*rot.z);
		v[6] =   2*(rot.y*rot.z + rot.x*rot.w);
		//v[7] =   0;
		v[8] =   2*(rot.x*rot.z + rot.y*rot.w);
		v[9] =   2*(rot.y*rot.z - rot.x*rot.w);
		v[10] = 1-2*(rot.x*rot.x + rot.y*rot.y);
	}

	/**
	 * Return an axis vector of the rotation values of this Matrix.
	 * Note that the non-rotation values of the Matrix are lost. */
	Vec3f toAxis()
	{	return toQuatrn().toAxis();
	}

	/**
	 * Return the rotation values of this Matrix as a Quatern.
	 * Note that the non-rotation values of the Matrix are lost. */
	Quatrn toQuatrn()
	{	Quatrn res=void;
		// If an identity matrix, return default quaternion.
		if (almostEqual(Matrix()))
			return Quatrn();

		float t = 1 + v[0] + v[5] + v[10];
		// If the diagonal sum is less than 1.
		if (t >= 0.00000001)
		{	float s = sqrt(t)*2;
			// Differs from gamedev.net's matrix & quaternion FAQ:
			// All subtractions on res.set lines have been reversed.
			res.set((v[6]-v[9])/s, (v[8]-v[2])/s, (v[1]-v[4])/s, .25*s);
		}else if ((v[0]>v[5]) && (v[0]>v[10]))	// if 0 is greatest
		{	float s = sqrt(1 + v[0] - v[5] - v[10])*2;
			res.set(.25*s, (v[4]+v[1])/s, (v[2]+v[8])/s, (v[9]-v[6])/s);
		}else if (v[5]>v[10])					// if 5 is greatest
		{	float s = sqrt(1 + v[5] - v[0] - v[10])*2;
			res.set((v[4]+v[1])/s, .25*s, (v[9]+v[6])/s, (v[2]-v[8])/s);
		}else									// if 10 is greatest
		{	float s = sqrt(1 + v[10] - v[0] - v[5])*2;
			res.set((v[2]+v[8])/s, (v[9]+v[6])/s, .25*s, (v[4]-v[1])/s);
		}
		return res;
    }

	/** Convert the rotation part of the Matrix to Euler angles.
	 *  This may be inaccurate and perhaps suffers from other faults. */
	Vec3f toEuler()
	{	double y = asin(v[2]); // Y axis-angle
		double c = cos(y);
		if (fabs(c) > 0.00005)  // If Gimball Lock?
			return Vec3f(-atan2(-v[6]/c, v[10]/c), -y, -atan2(-v[1]/c, v[0]/c));
		return Vec3f(0, -y, -atan2(v[4], v[5]));
	}

	/** Return the transpose of the Matrix.  This is equivalent to
	 *  converting a column-major Matrix to a row-major Matrix. */
	Matrix transpose()
	{	Matrix result = void;
		result.v[0] = v[0];
		result.v[1] = v[4];
		result.v[2] = v[8];
		result.v[3] = v[12];
		result.v[4] = v[1];
		result.v[5] = v[5];
		result.v[6] = v[9];
		result.v[7] = v[13];
		result.v[8] = v[2];
		result.v[9] = v[6];
		result.v[10]= v[10];
		result.v[11]= v[14];
		result.v[12]= v[3];
		result.v[13]= v[7];
		result.v[14]= v[11];
		result.v[15]= v[15];
		return result;
	}

	/// Create a string representation of this Matrix for human reading.
	char[] toString()
	{	return
		formatString("[%f %f %f %f]\n", v[0], v[4], v[8], v[12])  ~
		formatString("[%f %f %f %f]\n", v[1], v[5], v[9], v[13])  ~
		formatString("[%f %f %f %f]\n", v[2], v[6], v[10], v[14]) ~
		formatString("[%f %f %f %f]\n", v[3], v[7], v[11], v[15]);
	}
}
