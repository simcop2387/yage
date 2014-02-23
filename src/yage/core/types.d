/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:	Eric Poggel
 * License:	<a href="lgpl3.txt">LGPL v3</a>
 */

module yage.core.types;

import tango.stdc.string : memcpy;
import tango.math.Math;
import yage.core.math.math;
import yage.core.math.vector:Vec4f;

/**
 * Allow for easy bit-by-bit conversion from one two-byte type to another.
 * Example:
 * --------------------------------
 * short s = word("Hi").s;   // the bits of the string "Hi" are stored in s.
 * ubyte[] u = word(512).ub; // u[0] is 0 and u[1] is 1. 
 * --------------------------------
 */
struct word
{	
	union
	{	short s;		/// Get the word as one of these types.
		ushort us;		/// ditto
		byte[2] b;		/// ditto
		ubyte[2] ub;	/// ditto
		char[2] c;		/// ditto
	}
	
	/// Convert to word
	static word opCall(T)(T i)
	{	word res;
		memcpy(&res.s, &i, min(2, T.sizeof));
		return res;
	}
	
	unittest
	{	assert(word.sizeof == 2);
		assert(word(3).s == 3);
		assert(word("Hi").c == "Hi");
		assert(word(3).us == word(word(1).s + word(2).s).us);
	}
}

/// Allow for easy bit-by-bit conversion from one four-byte type to another
struct dword
{	union
	{	int i;			/// Get the dword as one of these types.
		uint ui;		/// ditto
		float f;		/// ditto
		short[2] s;		/// ditto
		ushort[2] us;	/// ditto
		word[2] w;		/// ditto
		byte[4] b;		/// ditto
		ubyte[4] ub;	/// ditto
		char[4] c;		/// ditto
	}
	
	/// Convert to dword
	static dword opCall(T)(T i)
	{	dword res;
		memcpy(&res.i, &i, min(4, T.sizeof));		
		return res;
	}
	
	unittest
	{	assert(dword.sizeof == 4);
		assert(dword(3.0f).f == 3.0f);
		assert(dword("l33t").c == "l33t");
		assert(dword(3.0f).i == dword(dword(1.0f).f + dword(2.0f).f).i);	
	}
}

/// Allow for easy bit-by-bit conversion from one eight-byte type to another.
union qword
{	long l;			/// Get the qword as one of these types
	ulong ul;		/// ditto
	double d;		/// ditto
	float[2] f;		/// ditto
	int[2] i;		/// ditto
	uint[2] ui;		/// ditto
	dword[2] dw;	/// ditto
	short[4] s;		/// ditto
	ushort[4] us;	/// ditto
	word[4] w;		/// ditto
	byte[8] b;		/// ditto
	ubyte[8] ub;	/// ditto
	char[8] c;		/// ditto	
	
	/// Convert to qword
	static qword opCall(T)(T i)
	{	qword res;
		memcpy(&res.l, &i, min(8, T.sizeof));
		return res;
	}
	
	unittest
	{	assert(qword.sizeof == 8);
		assert(qword(3L).l == 3L);
		assert(qword("yageyage").c == "yageyage");
		assert(qword(3.0).l == qword(qword(1.0).d + qword(2.0).d).l);
	}
}