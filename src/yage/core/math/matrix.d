/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel, Matt Peterson
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.core.math.matrix;

import tango.math.IEEE;
import tango.math.Math;
import tango.text.convert.Format;
import yage.core.math.plane;
import yage.core.math.vector;
import yage.core.math.quatrn;
import yage.core.math.math;
import yage.core.misc;
import yage.system.log;

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
		Vec!(4, float)[4] col;	// produces a forward reference error
		struct /// elements in column/row form.
		{	float c0r0, c0r1, c0r2, c0r3; /// first column
			float c1r0, c1r1, c1r2, c1r3; /// second column
			float c2r0, c2r1, c2r2, c2r3; /// third column
			float c3r0, c3r1, c3r2, c3r3; /// fourth column
		}
	}
	
	protected static const float close_enough = 0.00005; // smaller values cause isUniformScale() to fail, which in turn causes Matrix drift
	
	
	invariant()
	{	foreach (float t; v)
		{	assert(!isNaN(t), std.string.format("[%s]", v)); // sometimes this fails!
			assert(t!=float.infinity, std.string.format("[%s]", v)); // sometimes this fails!
		}
	}
	
	///
	static const Matrix IDENTITY;

	unittest
	{
		/**
		 * TODO: This hsould probably be cleaned up and moved to individual functions.
		 * Testing and reporting in one function
		 * Asserts that the first two matrices are almost equal, and prints
		 * The test name and all givem matrices used in the test if not.*/
		void test(string name, Matrix[] args ...)
		{	string report = "\nFailed on test '"~name~"' With Matrices:\n\n";
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
			test("Inverse 1", c, c.inverse().inverse());
			test("Inverse 2", Matrix(), c*c.inverse(), c);
			test("Identity", c, c*Matrix()); // [Below] compared this way because non-rotation values are lost.
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
		result.c0r0 = 2/rl;
		result.c1r1 = 2/tb;
		result.c2r2 = -2/fn;
		result.c3r0 = -(right+left)/rl;
		result.c3r1 = -(top+bottom)/tb;
		result.c3r2 = -(far+near)/fn;

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
	 * Convert a Matrix to and from position, axis/angle rotation, and scale vectors.*/
	static Matrix compose(Vec3f position, Vec3f rotation, Vec3f scale)
	{	
		Matrix result;
		result.setPosition(position);
		result.setRotation(rotation);

		if (scale.almostEqual(Vec3f.ONE))
			return result;
		
		Matrix mscale;
		mscale.v[0] = scale.x;
		mscale.v[5] = scale.y;
		mscale.v[10]= scale.z;

		return result.transformAffine(mscale);
	}
	
	static Matrix compose(Vec3f position, Quatrn rotation, Vec3f scale)
	{	
        // TODO reenable this after learning if __invariant1 is what is wanted
	//		debug rotation.__invariant();

		Matrix result;
		result.setPosition(position);
		result.setRotation(rotation);

		if (scale.almostEqual(Vec3f.ONE))
			return result;
		
		Matrix mscale;
		mscale.v[0] = scale.x;
		mscale.v[5] = scale.y;
		mscale.v[10]= scale.z;

		return result.transformAffine(mscale);
	}
	
	
	void decompose(out Vec3f position, out Vec3f rotation, out Vec3f scale) /// ditto
	{		
		// Extract the translation directly
		position.x = c3r0;
		position.y = c3r1;
		position.z = c3r2;
		
		// Take the lengths of the basis vectors to find the scale factors.
		scale.x = (cast(Vec3f*)v[0..3]).length();
		scale.y = (cast(Vec3f*)v[4..7]).length();
		scale.z = (cast(Vec3f*)v[8..11]).length();
		
		// Undo the scale before getting the rotation.
		if (scale.almostEqual(Vec3f(1)))
			rotation = toAxis();
		else {
			Matrix m = this;
			m.v[0..3] = (cast(Vec3f*)v[0..3]).scale(1/scale.x).v[];
			m.v[4..7] = (cast(Vec3f*)v[4..7]).scale(1/scale.y).v[];
			m.v[8..11] = (cast(Vec3f*)v[8..11]).scale(1/scale.z).v[];
			rotation = m.toAxis();
		}
	}
	unittest
	{	auto p = Vec3f(1, 2, 3);
		auto r = Vec3f(-1, .5, 1);
		auto s = Vec3f(4, 4, 4);
		Matrix m = Matrix.compose(p, r, s);
		Vec3f p2, r2, s2;
		m.decompose(p2, r2, s2);
		assert(p.almostEqual(p2));
		assert(r.almostEqual(r2));
		assert(s.almostEqual(s2));		
		assert(Matrix.compose(Vec3f(0), Vec3f(0), Vec3f(1)) == Matrix.IDENTITY);
	}
	
	void decompose(out Vec3f position, out Quatrn rotation, out Vec3f scale) /// ditto
	{		
		// Extract the translation directly
		position.x = c3r0;
		position.y = c3r1;
		position.z = c3r2;
		
		// Take the lengths of the basis vectors to find the scale factors.
		scale.x = (cast(Vec3f*)v[0..3]).length();
		scale.y = (cast(Vec3f*)v[4..7]).length();
		scale.z = (cast(Vec3f*)v[8..11]).length();
		
		// Undo the scale before getting the rotation.
		if (scale.almostEqual(Vec3f(1)))
			rotation = toQuatrn();
		else {
			Matrix m = this;
			m.v[0..3] = (cast(Vec3f*)v[0..3]).scale(1/scale.x).v[];
			m.v[4..7] = (cast(Vec3f*)v[4..7]).scale(1/scale.y).v[];
			m.v[8..11] = (cast(Vec3f*)v[8..11]).scale(1/scale.z).v[];
			rotation = m.toQuatrn();
			
			// TODO re-enable this
			// debug rotation.__invariant();
		}
	}
	
	/**
	 * Decompose this Matrix into a position, rotation, and scaling Matrix. */
	void decompose(out Matrix position, out Matrix rotation, out Matrix scale)
	{	position = rotation = scale = Matrix(); // set each to identity.
		
		// Extract the translation directly
		position.v[12..15] = v[12..15];
		
		// Extract the orientation basis vectors
		Vec3f* rx = cast(Vec3f*)v[0..3];
		Vec3f* ry = cast(Vec3f*)v[4..7];
		Vec3f* rz = cast(Vec3f*)v[8..11];
		float rx_length = rx.length();
		float ry_length = ry.length();
		float rz_length = rz.length();
		
		// Divide the basis vectors by their lengths to normalize them.
		rotation.v[0..3] = rx.scale(1/rx_length).v[];
		rotation.v[4..7] = ry.scale(1/ry_length).v[];
		rotation.v[8..11]= rz.scale(1/rz_length).v[];
		
		// Take the lengths of the basis vectors to find the scale factors.
		scale.c0r0 = rx_length;
		scale.c1r1 = ry_length;
		scale.c2r2 = rz_length;
	}
	unittest
	{	// Decompose and recompose a random matrix to make sure we get back what we started with.
		Matrix test = Matrix.random(); // I guess it doesn't have to be affine to work
		test.c0r3 = test.c1r3 = test.c2r3 = 0;
		test.c3r3 = 1; // the last row isn't used in decompose, so we set it to identity.
		
		Matrix position, rotation, scale;
		test.decompose(position, rotation, scale);

		assert(test.almostEqual(scale*(rotation*(position)), close_enough));
	}
	
	/**
	 * Calculate the determinant of the Matrix. */
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
	 * If this is a clip matrix (projection*modelView), get a 6-plane view frustum from it.
	 * Params:
	 *     result = If set and of length=6, use this to store the result. */
	Plane[] getFrustum(Plane[] result=null)
	{	if (result.length < 6)
			result.length = 6;		
		result[0] = Plane(v[3]-v[0], v[7]-v[4], v[11]-v[ 8], v[15]-v[12]).normalize(); // left?
		result[1] = Plane(v[3]+v[0], v[7]+v[4], v[11]+v[ 8], v[15]+v[12]).normalize(); // right?
		result[2] = Plane(v[3]+v[1], v[7]+v[5], v[11]+v[ 9], v[15]+v[13]).normalize(); // top?
		result[3] = Plane(v[3]-v[1], v[7]-v[5], v[11]-v[ 9], v[15]-v[13]).normalize(); // bottom?
		result[4] = Plane(v[3]-v[2], v[7]-v[6], v[11]-v[10], v[15]-v[14]).normalize(); // near?
		result[5] = Plane(v[3]+v[2], v[7]+v[6], v[11]+v[10], v[15]+v[14]).normalize(); // far?
		return result;
	}
	
	/**
	 * Get the position component of the Matrix as a Vector. */
	Vec3f getPosition()
	{	return Vec3f(v[12 .. 15]);		
	}
	
	/**
	 * Extract the scale Vector from the rotation component of the Matrix.
	 * Scale components will always be positive. */
	Vec3f getScale()
	{	return Vec3f(
			Vec3f(v[0 .. 3]).length(),
			Vec3f(v[4 .. 7]).length(),
			Vec3f(v[8 .. 11]).length());
	}
	unittest
	{	Matrix m;
		Vec3f s = Vec3f(1, 2, 4);
		m = m.scale(s);
		assert(m.getScale() == s);
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

	/**
	 * Is this an identity Matrix? */
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
	}
	
	/// Return a copy of this Matrix with its position values incremented by vec.
	Matrix move(Vec3f vec)
	{	Matrix res = this;
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
	{	this = ((this) * b);
		return this;
	}
	unittest
	{	Matrix a = Matrix.random();
		Matrix b = Matrix.random();
		Matrix c = a;
		c*=b;
		assert (a*b == c);
	}

	///
	float* ptr()
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

	/// Return a copy of this Matrix scaled by s
	Matrix scale(Vec3f s)
	{	Matrix result = this;
		Matrix position, rotation, mscale;
		result.decompose(position, rotation, mscale);
		mscale.v[0] *= s.x;
		mscale.v[5] *= s.y;
		mscale.v[10] *= s.z;
		result.setRotation(rotation.rotate(mscale));
		return result;
	}
	unittest {
		Matrix m;
		Vec3f r = Vec3f(-1, 1, 1);
		Vec3f s = Vec3f(1, 2, 4);
		m = m.rotate(r);
		m = m.scale(s);
		assert(m.getScale().almostEqual(s));
		//assert(m.toAxis().almostEqual(r));
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
		v[4] =   2*(rot.x*rot.y - rot.z*rot.w);
		v[5] = 1-2*(rot.x*rot.x + rot.z*rot.z);
		v[6] =   2*(rot.y*rot.z + rot.x*rot.w);
		v[8] =   2*(rot.x*rot.z + rot.y*rot.w);
		v[9] =   2*(rot.y*rot.z - rot.x*rot.w);
		v[10]= 1-2*(rot.x*rot.x + rot.y*rot.y);
	}
	void setRotation(Vec3f axis) /// ditto
	{	float phi = axis.length();
		if (phi==0) // no rotation for zero-vector
		{	v[1] = v[2] = v[4] = v[6] = v[8] = v[9] = 0;
			v[0] = v[5] = v[10] = 1;
		} 
		else
		{	Vec3f n = axis.scale(1/phi);
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
	}
	unittest {
		auto rotation = (Vec3f(1, 2, -1));
		Matrix a;
		a.setRotation(rotation);
		assert(a.toAxis().almostEqual(rotation));
	}

	/**
	 * Return an axis vector of the rotation values of this Matrix.
	 * Note that the non-rotation values of the Matrix are lost. */
	Vec3f toAxis()
	{	return toQuatrn().toAxis(); /// TODO: replace with setRotation worked out in reverse.
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

	/** 
	 * Convert the rotation part of the Matrix to Euler angles.
	 * This may be inaccurate and perhaps suffers from other faults. */
	Vec3f toEuler()
	{	float y = asin(v[2]); // Y axis-angle
		float c = cos(y);
		if (abs(c) > 0.00005)  // If Gimball Lock?
			return Vec3f(-atan2(-v[6]/c, v[10]/c), -y, -atan2(-v[1]/c, v[0]/c));
		return Vec3f(0, -y, -atan2(v[4], v[5]));
	}
	
	/**
	 * Multiply two matrices and return a third Matrix result, ignoring values that aren't needed 
	 * in affine transformations.  This makes it almost half the operations of a Matrix multiplication. */ 
	Matrix transformAffine(Matrix b)
	{	
		Matrix result=void;
		
		result.v[ 0] = b.v[ 0]*v[ 0] + b.v[ 1]*v[ 4] + b.v[ 2]*v[ 8]/* + b.v[ 3]*v[12]*/;
		result.v[ 1] = b.v[ 0]*v[ 1] + b.v[ 1]*v[ 5] + b.v[ 2]*v[ 9]/* + b.v[ 3]*v[13]*/;
		result.v[ 2] = b.v[ 0]*v[ 2] + b.v[ 1]*v[ 6] + b.v[ 2]*v[10]/* + b.v[ 3]*v[14]*/;
		//result.v[ 3] = b.v[ 0]*v[ 3] + b.v[ 1]*v[ 7] + b.v[ 2]*v[11] + b.v[ 3]*v[15];
		result.v[3] = 0;

		result.v[ 4] = b.v[ 4]*v[ 0] + b.v[ 5]*v[ 4] + b.v[ 6]*v[ 8]/* + b.v[ 7]*v[12]*/;
		result.v[ 5] = b.v[ 4]*v[ 1] + b.v[ 5]*v[ 5] + b.v[ 6]*v[ 9]/* + b.v[ 7]*v[13]*/;
		result.v[ 6] = b.v[ 4]*v[ 2] + b.v[ 5]*v[ 6] + b.v[ 6]*v[10]/* + b.v[ 7]*v[14]*/;
		//result.v[ 7] = b.v[ 4]*v[ 3] + b.v[ 5]*v[ 7] + b.v[ 6]*v[11] + b.v[ 7]*v[15];
		result.v[7] = 0;

		result.v[ 8] = b.v[ 8]*v[ 0] + b.v[ 9]*v[ 4] + b.v[10]*v[ 8]/* + b.v[11]*v[12]*/;
		result.v[ 9] = b.v[ 8]*v[ 1] + b.v[ 9]*v[ 5] + b.v[10]*v[ 9]/* + b.v[11]*v[13]*/;
		result.v[10] = b.v[ 8]*v[ 2] + b.v[ 9]*v[ 6] + b.v[10]*v[10]/* + b.v[11]*v[14]*/;
		//result.v[11] = b.v[ 8]*v[ 3] + b.v[ 9]*v[ 7] + b.v[10]*v[11] + b.v[11]*v[15];
		result.v[11] = 0;

		result.v[12] = b.v[12]*v[ 0] + b.v[13]*v[ 4] + b.v[14]*v[ 8] + /*b.v[15]**/v[12];
		result.v[13] = b.v[12]*v[ 1] + b.v[13]*v[ 5] + b.v[14]*v[ 9] + /*b.v[15]**/v[13];
		result.v[14] = b.v[12]*v[ 2] + b.v[13]*v[ 6] + b.v[14]*v[10] + /*b.v[15]**/v[14];
		//result.v[15] = b.v[12]*v[ 3] + b.v[13]*v[ 7] + b.v[14]*v[11] + b.v[15]*v[15];
		result.v[15] = 1;
		
		return result;
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
	string toString()
	{	return std.string.format("[%f %f %f %f]\n[%f %f %f %f]\n[%f %f %f %f]\n[%f %f %f %f]\n",
	                                 v[0], v[4], v[8], v[12],
	                                 v[1], v[5], v[9], v[13],
	                                 v[2], v[6], v[10], v[14],
	                                 v[3], v[7], v[11], v[15]);
	}
	

	/**
	 * Params:
	 *     fovy = In radians
	 *     aspect = 
	 *     zNear = 
	 *     zFar = 
	 * Returns:
	 */
	static Matrix createProjection(float fovY, float aspect, float near, float far)
	{	Matrix result;
		
		float halfFov = fovY * .5f;		

		float sine = sin(halfFov);
		float zdist = far - near;
		if (aspect == 0 || zdist == 0 || sine == 0)
			return result;
		
		float cotangent = cos(halfFov) / sine;
		
		result.c0r0 = cotangent / aspect;
		result.c1r1 = cotangent;
		result.c2r2 = -(far + near) / zdist;
		result.c2r3 = -1;
		result.c3r2 = -2 * near * far / zdist;
		result.c3r3 = 0;
		return result;
	}
	
	
	// Get a random matrix, good for unit-testing.
	protected static Matrix random()
	{	Matrix result;
		foreach (ref float t; result.v)
			t = yage.core.math.math.random(0, 4);
		return result;
	}
}
