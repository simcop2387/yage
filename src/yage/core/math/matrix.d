/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel, Matt Peterson
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.core.math.matrix;

import tango.math.Math;
import tango.text.convert.Format;
import yage.core.math.vector;
import yage.core.math.quatrn;
import yage.core.math.math;
import yage.core.misc;

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
						0, 0, 0, 1,]; /// elements in array form.
		//Vec4f[4] row;	// produces a forward reference error
		struct /// elements in column/row form.
		{	float v00, v01, v02, v03; /// first column
			float v10, v11, v12, v13; /// second column
			float v20, v21, v22, v23; /// third column
			float v30, v31, v32, v33; /// fourth column
		}
	}
	
	protected static const float close_enough = 0.0001;
	
	
	invariant()
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

	/// Create an Orthographic Matrix
	static Matrix opCall(float left, float right, float bottom, float top, float near, float far)
	{	float rl = right-left;
		float tb = top-bottom;
		float fn = far-near;
		Matrix result;
		result.v00 = 2/rl;
		result.v11 = 2/tb;
		result.v22 = -2/fn;
		result.v[12] = -(right+left)/rl;
		result.v[13] = -(top+bottom)/tb;
		result.v[14] = -(far+near)/fn;

		//assert(result * result.transpose() == Matrix());
		
		
		return result;
	}
	
	/// Is this Matrix equal to Matrix s, discarding relative error fudge.
	bool almostEqual(Matrix s, float fudge=0.0001)
	{	for (int i=0; i<v.length; i++)
			if (!yage.core.math.math.almostEqual(v[i], s.v[i], fudge))
				return false;
		return true;
	}

	/**
	 * Decompose this Matrix into a position, rotation, and scaling Matrix. */
	void decompose(out Matrix position, out Matrix rotation, out Matrix scale)
	{	position = rotation = scale = Matrix(); // set each to identity.
		
		// Extract the translation directly
		position.v30 = v30;
		position.v31 = v31;
		position.v32 = v32;
		
		// Extract the orientation basis vectors
		Vec3f rx = Vec3f(v[0..3]);
		Vec3f ry = Vec3f(v[4..7]);
		Vec3f rz = Vec3f(v[8..11]);
		float rx_length = rx.length();
		float ry_length = ry.length();
		float rz_length = rz.length();
		
		// Divide the basis vectors by their lengths to normalize them.
		rotation.v[0..3] = rx.scale(1/rx_length).v[0..3];
		rotation.v[4..7] = ry.scale(1/ry_length).v[0..3];
		rotation.v[8..11]= rz.scale(1/rz_length).v[0..3];
		
		// Take the lengths of the basis vectors to find the scale factors.
		scale.v00 = rx_length;
		scale.v11 = ry_length;
		scale.v22 = rz_length;		
	}
	unittest
	{	// Decompose and recompose a random matrix to make sure we get back what we started with.
		Matrix test = Matrix.random();
		test.v03 = test.v13 = test.v23 = 0;
		test.v33 = 1; // the last row isn't used in decompose, so we set it to identity.
		
		Matrix position, rotation, scale;
		test.decompose(position, rotation, scale);

		assert(test.almostEqual(scale*(rotation*(position)), close_enough));
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

	/**
	 * Returns true if all components of the scale are the same.
	 * This is much faster than calling toScale() and comparing elements. 
	 * TODO: make this count almost uniform as uniform, to fix floating point errors.*/
	bool isUniformScale()
	{	float sx = v[0]*v[0] + v[1]*v[1] + v[2]*v[2];
		float sy = v[4]*v[4] + v[5]*v[5] + v[6]*v[6];
		if (!.almostEqual(sx, sy, close_enough))
			return false;		
		float sz = v[8]*v[8] + v[9]*v[9] + v[10]*v[10];
		return (.almostEqual(sx, sz, close_enough));
	}
	unittest
	{	assert(Matrix().isUniformScale());
		assert(!Matrix.random().isUniformScale()); // will fail 1 out of 2^64 times.
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
	{	*this = ((*this) * b);
		return *this;
	}
	unittest
	{	Matrix a = Matrix.random();
		Matrix b = Matrix.random();
		Matrix c = a;
		c*=b;
		assert (a*b == c);
	}

	/**
	 * Get the position component of the Matrix as a Vector. */
	Vec3f position()
	{	return Vec3f(v[12..15]);		
	}
	
	///
	void *ptr()
	{	return v.ptr;
	}

	/**
	 * Return a copy of this Matrix rotated by the rotation values of an axis-angle Vector, a Quaternion, or another Matrix.
	 * For Matrix rotation, this is equivalent to a post-multiplication of only the rotation values.*/
	Matrix rotate(Vec3f axis)
	{	return rotate(axis.toMatrix());
	}
	Matrix rotate(Quatrn rotation) /// ditto
	{	return rotate(rotation.toMatrix());
	}
	Matrix rotate(Matrix b) /// ditto
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
	 * Rotation and scale are intimately related in the Matrix.
	 * This decomposes the matrix, applies the rotation only to the rotation component, and then recomposes it. */
	Matrix rotatePreservingScale(T)(T rot) /// ditto
	{	if (isUniformScale()) // no need for special steps
			return rotate(rot);
		
		Matrix position, rotation, scale;
		decompose(position, rotation, scale);
		rotation = rotation.rotate(rot).rotate(scale);
		position.setRotation(rotation); // faster version of return scale * (rotation * position)
		return position;
	}

	/**
	 * Return a copy of this Matrix with its rotation values incremented by an
	 * axis angle Vector, a Quaternion or another Matrix, relative to the absolute worldspace axis.
	 * This function hasn't been verified to be correct in all circumstances. */
	Matrix rotateAbsolute(Vec3f axis)
	{	Matrix res = *this;
		res.setRotation(axis.toQuatrn()*toQuatrn());
		return res;
		//return axis.toMatrix()*(*this);
	}
	Matrix rotateAbsolute(Quatrn rotation) /// ditto
	{	Matrix res = *this;
		res.setRotation(rotation*toQuatrn());
		return res;
		//return rotation.toMatrix()*(*this);
	}
	Matrix rotateAbsolute(Matrix m) /// ditto
	{	Matrix res = *this;
		res.setRotation(m.toQuatrn()*toQuatrn());
		return res;
		//return m*(*this);
	}
	
	/**
	 * This is mostly untested. */
	Matrix rotateAbsolutePreservingScale(Vec3f axis)
	{	return rotateAbsolutePreservingScale(axis.toMatrix());
	}
	Matrix rotateAbsolutePreservingScale(Quatrn rotation) /// ditto
	{	return rotateAbsolutePreservingScale(rotation.toMatrix());
	}
	Matrix rotateAbsolutePreservingScale(Matrix b) /// ditto
	{	if (isUniformScale()) // is this right?
			return rotateAbsolute(b);
		
		Matrix position, rotation, scale;
		decompose(position, rotation, scale);
		rotation = b.rotate(rotation); // this is the reverse of the non-absolute version.
		position.setRotation(rotation.rotate(scale)); // faster version of return scale * (rotation * position)
		return position;
	}

	/**
	 * Return a copy of this Matrix with its rotation values incremented by a Vec3f of Euler rotation angles,
	 * relative to it's current rotation axis.  First by x, then y, then z.
	 * This function hasn't been verified to be correct in all circumstances. */
	Matrix rotateEuler(Vec3f euler)
	{	float cx = cos(euler.x);
		float sx = sin(euler.x);
		float cy = cos(euler.y);
		float sy = sin(euler.y);
		float cz = cos(euler.z);
		float sz = sin(euler.z);
		float sxsy = sx*sy;
		float cxsy = cx*sy;
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
		res.setRotation(res.toQuatrn()*toQuatrn());
		return res;
	}

	///
	Matrix scale(Vec3f s)
	{	Matrix result = *this;
		result.v00 = s.x;
		result.v11 = s.y;
		result.v22 = s.z;
		return result;
	}
	
	///
	void setPosition(Vec3f position)
	{	v[12..15] = position.v[0..3];
	}
	
	/// Set the rotation values of this Matrix from another Matrix, Quaternion, or axis-angle Vector.
	void setRotation(Matrix rot)
	{	v[0..3]  = rot.v[0..3];
		v[4..7]  = rot.v[4..7];
		v[8..11] = rot.v[8..11];
	}	
	void setRotation(Quatrn rot) /// ditto
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
	void setRotation(Vec3f rot) /// ditto
	{	// this is untested.
		
		float phi = rot.length();
		if (phi==0) // no rotation for zero-vector
			return;
		Vec3f n = rot.scale(1/phi);
		float rcos = cos(phi);
		float rcos1 = 1-rcos;
		float rsin = sin(phi);
		v[0] =        rcos + n.x*n.x*rcos1;
		v[1] =  n.z * rsin + n.y*n.x*rcos1;
		v[2] = -n.y * rsin + n.z*n.x*rcos1;
		v[4] = -n.z * rsin + n.x*n.y*rcos1;
		v[5] =        rcos + n.y*n.y*rcos1;
		v[6] =  n.x * rsin + n.z*n.y*rcos1;
		v[8] =  n.y * rsin + n.x*n.z*rcos1;
		v[9] = -n.x * rsin + n.y*n.z*rcos1;
		v[10]=        rcos + n.z*n.z*rcos1;	
	}
	/**
	 * Set the rotation while taking extra steps to preserve the Matrices scaling values. */
	void setRotationPreservingScale(T)(T rot)
	{	Vec3f scale = toScale();
		setRotation(rot);
		setScalePreservingRotation(scale); // slow
	}
	
	/// Set the rotation values of the matrix from a vector containing euler angles.
	void setRotationEuler(Vec3f euler)
	{	float cx = cos(euler.x);
		float sx = sin(euler.x);
		float cy = cos(euler.y);
		float sy = sin(euler.y);
		float cz = cos(euler.z);
		float sz = sin(euler.z);
		float sxsy = sx*sy;
		float cxsy = cx*sy;
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
	
	/**
	 * Set the scale component of the Matrix, taking extra steps to preserve any 
	 * rotation values already present in the scale part of the Matrix. */
	void setScalePreservingRotation(Vec3f scale)
	{	Matrix position, rotation, mscale;
		decompose(position, rotation, mscale);
		mscale = mscale.scale(scale);
		setRotation(rotation.rotate(mscale));
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
	{	
		// If an identity matrix, return default quaternion.
		if (almostEqual(Matrix()))
			return Quatrn();

		float t = 1 + v[0] + v[5] + v[10];
		// If the diagonal sum is less than 1.
		if (t >= 0.00000001)
		{	float s = sqrt(t)*2;
			// Differs from gamedev.net's matrix & quaternion FAQ:
			// All subtractions on res.set lines have been reversed.
			return Quatrn((v[6]-v[9])/s, (v[8]-v[2])/s, (v[1]-v[4])/s, .25*s);
		}else if ((v[0]>v[5]) && (v[0]>v[10]))	// if 0 is greatest
		{	float s = sqrt(1 + v[0] - v[5] - v[10])*2;
			return Quatrn(.25*s, (v[4]+v[1])/s, (v[2]+v[8])/s, (v[9]-v[6])/s);
		}else if (v[5]>v[10])					// if 5 is greatest
		{	float s = sqrt(1 + v[5] - v[0] - v[10])*2;
			return Quatrn((v[4]+v[1])/s, .25*s, (v[9]+v[6])/s, (v[2]-v[8])/s);
		}else									// if 10 is greatest
		{	float s = sqrt(1 + v[10] - v[0] - v[5])*2;
			return Quatrn((v[2]+v[8])/s, (v[9]+v[6])/s, .25*s, (v[4]-v[1])/s);
		}
    }

	/** Convert the rotation part of the Matrix to Euler angles.
	 *  This may be inaccurate and perhaps suffers from other faults. */
	Vec3f toEuler()
	{	float y = asin(v[2]); // Y axis-angle
		float c = cos(y);
		if (abs(c) > 0.00005)  // If Gimball Lock?
			return Vec3f(-atan2(-v[6]/c, v[10]/c), -y, -atan2(-v[1]/c, v[0]/c));
		return Vec3f(0, -y, -atan2(v[4], v[5]));
	}
	
	/**
	 * Extract the scale Vector from the rotation component of the Matrix.
	 * Scale components will always be positive. */
	Vec3f toScale()
	{	return Vec3f(
			Vec3f(v[0..3]).length(),
			Vec3f(v[4..7]).length(),
			Vec3f(v[8..11]).length()
		);
	}
	unittest
	{	assert(Matrix().toScale() == Vec3f(1, 1, 1));		
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
		Format.convert("[{} {} {} {}]\n", v[0], v[4], v[8], v[12])  ~
		Format.convert("[{} {} {} {}]\n", v[1], v[5], v[9], v[13])  ~
		Format.convert("[{} {} {} {}]\n", v[2], v[6], v[10], v[14]) ~
		Format.convert("[{} {} {} {}]\n", v[3], v[7], v[11], v[15]);
	}
	
	// Get a random matrix, good for unit-testing.
	protected static Matrix random()
	{	Matrix result;
		foreach (inout float t; result.v)
			t = yage.core.math.math.random(0, 4);
		return result;
	}
}
