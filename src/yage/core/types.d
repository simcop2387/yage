/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.core.types;


import yage.core.parse;
private extern (C) void *memcpy(void *, void *, uint);

/**
 * Allow for easy bit-by-bit conversion from one two-byte type to another.
 * Example:
 * --------------------------------
 * short a;
 * word w;
 * w.s = a;
 * char c = w.c[1];	// c is the second byte of a.
 * --------------------------------
 */
struct word
{	
	union
	{	short s;		/// Union of various types.
		ushort us;		/// ditto
		byte[2] b;		/// ditto
		ubyte[2] ub;	/// ditto
		char[2] c;		/// ditto
	}
	
	/// Convert to word
	static word opCall(T)(T i)
	{	word res;
		static if(T.sizeof < 2)
			throw new Exception("Variable must be at least 2 bytes to be converted to a word.");
		memcpy(&res.s, &i, 2);
		return res;
	}
}
unittest
{	assert(word(3).us == word(word(1).s + word(2).s).us);
}

/// Allow for easy bit-by-bit conversion from one four-byte type to another
struct dword
{	union
	{	int i;			/// Union of various types.
		uint ui;		/// ditto
		float f;		/// ditto
		short[2] s;		/// ditto
		ushort[2] us;	/// ditto
		byte[4] b;		/// ditto
		ubyte[4] ub;	/// ditto
		char[4] c;		/// ditto
	}
	
	/// Convert to dword
	static dword opCall(T)(T i)
	{	dword res;
		static if(T.sizeof < 4)
			throw new Exception("Variable must be at least 4 bytes to be converted to a dword.");
		memcpy(&res.i, &i, 4);
		return res;
	}
}
unittest
{	assert(dword(3.0f).i == dword(dword(1.0f).f + dword(2.0f).f).i);
}

/// Allow for easy bit-by-bit conversion from one eight-byte type to another.
union qword
{	long l;			/// Union of various types.
	ulong ul;		/// ditto
	double d;		/// ditto
	float[2] f;		/// ditto
	int[2] i;		/// ditto
	uint[2] ui;		/// ditto
	short[4] s;		/// ditto
	ushort[4] us;	/// ditto
	byte[8] b;		/// ditto
	ubyte[8] ub;	/// ditto
	char[8] c;		/// ditto
	
	
	/// Convert to qword
	static qword opCall(T)(T i)
	{	qword res;
		static if(T.sizeof < 8)
			throw new Exception("Variable must be at least 8 bytes to be converted to a qword.");
		memcpy(&res.l, &i, 8);
		return res;
	}
}
unittest
{	assert(qword(3.0).l == qword(qword(1.0).d + qword(2.0).d).l);
}

/// Represent a color
struct color
{
	union
	{	int i;			/// Union of various types.
		uint ui;		/// ditto		
		byte[4] b;		/// ditto
		ubyte[4] ub;	/// ditto
		char[4] c;		/// ditto
		dword d;		/// ditto
	}	

	static color opCall(dword d)
	{	color res;
		res.d=d;
		return res;
	}
	
	static color opCall(char[] hex)
	{	color res;
		return color(dword(hexToUint(hex)));		
	}
	
	char[] toString()
	{	return ""; // todo	
	}
}

unittest
{
	color blue;
	blue = color("0000FF");
	std.stdio.writefln(blue);
	
}




