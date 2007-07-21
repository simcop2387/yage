/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.core.types;

import std.stdio;
import std.intrinsic;
import yage.core.math;
import yage.core.parse;
import yage.core.vector;
private extern (C) void *memcpy(void *, void *, uint);



/**
 * A struct used to represent a color.
 * Colors are represented in RGBA format.
 * Note that uints and dwords store the bytes in reverse,
 * so Color(0x6633ff00).hex == "00FF3366"
 * All Colors default to transparent black.
 * Example:
 * --------------------------------
 * uint  red  = Color("red").ui;
 * Vec4f blue = Color("0000FF").vec4f;
 * writefln(Color("blue")); 	 // outputs "0000FF00"
 * writefln(Color(0x00FF0000));  // outputs "0000FF00"
 * --------------------------------
 */
struct Color
{
	private static real frac = 1.0f/255;
	
	union
	{	ubyte[4] ub;/// Get the Color as an array of ubyte
		uint ui;	/// Get the Color as a uint		
		dword dw;	/// Get the Color as a dword
		struct { ubyte r, g, b, a; } /// Access each color component.
	}
	
	/// Initialize
	static Color opCall(int r, int g,int b, int a=255)
	{	Color res;
		res.r=r;
		res.b=b;
		res.g=g;
		res.a=a;
		return res;
	}
	/// Ditto
	static Color opCall(float r, float g, float b, float a=1)
	{	Color res;
		res.r=cast(ubyte)clamp(r*255, 0.0f, 255.0f);
		res.b=cast(ubyte)clamp(b*255, 0.0f, 255.0f);
		res.g=cast(ubyte)clamp(g*255, 0.0f, 255.0f);
		res.a=cast(ubyte)clamp(a*255, 0.0f, 255.0f);
		return res;
	}


	/// Convert dword to Color
	static Color opCall(dword dw)
	{	Color res;
		res.dw = dw;
		return res;
	}
	
	/// Convert uint to Color
	static Color opCall(uint ui)
	{	return Color(dword(ui));
	}
	
	/// Convert ubyte[] to Color
	static Color opCall(ubyte[] v)
	{	Color res;
		for (int i=0; i<max(v.length, 4); i++)
			res.ub[i] = cast(ubyte)(v[i]);
		return res;
	}	
	
	/// Convert int[] to Color
	static Color opCall(int[] v)
	{	Color res;
		for (int i=0; i<max(v.length, 4); i++)
			res.ub[i] = cast(ubyte)(v[i]);
		return res;
	}	
	
	/// Convert float[] to Color
	static Color opCall(float[] f)
	{	Color res;
		for (int i=0; i<min(f.length, 4); i++)
			res.ub[i] = cast(ubyte)clamp(f[i]*255, 0.0f, 255.0f);
		return res;
	}
	
	/// Convert Vec3f to Color
	static Color opCall(Vec3f v)
	{	return Color(v.v);
	}
	
	/// Convert Vec4f to Color
	static Color opCall(Vec4f v)
	{	return Color(v.v);
	}
	
	/**
	 * Convert a string to a color.
	 * The string can be a 6 or 8 digit hexadecimal or an English color name.
	 * Black, blue, brown, cyan, gold, gray/grey, green, indigo, magenta, orange, 
	 * pink, purple, red, violet, white, and yellow are supported.
	 * See: <a href="http://www.w3schools.com/css/css_colornames.asp">CSS color names</a>
	 * Params:
	 * string = The string to convert.*/
	static Color opCall(char[] string)
	{	
		// An english color name
		switch (std.string.tolower(string))
		{	case "black":	return Color(0x00000000);
			case "blue":	return Color(0x00FF0000);
			case "brown":	return Color(0x00A52A2A);
			case "cyan":	return Color(0x00FFFF00);
			case "gold":	return Color(0x0000D7FF);
			case "gray":	
			case "grey":	return Color(0x00808080);
			case "green":	return Color(0x00008000);
			case "indigo":	return Color(0x0082004B);
			case "magenta":	return Color(0x00FF00FF);
			case "orange":	return Color(0x0000A5FF);
			case "pink":	return Color(0x00CBC0FF);
			case "purple":	return Color(0x00800080);
			case "red":		return Color(0x000000FF);
			case "violet":	return Color(0x00EE82EE);
			case "white":	return Color(0x00FFFFFF);
			case "yellow":	return Color(0x0000FFFF);
			default: break;
		}		
	
		// Append alpha to 6-digit hex string.
		if (string.length == 6)
			string ~= "FF";		
		
		// Convert string one char at a a time.
		Color result;
		int digit;
		foreach (int i, char h; string)
		{	digit=0; // will be 0-15
			if (47 < h && h < 58)	// 0-9
				digit = (h-48);
			else if (64 < h && h < 71) // A-F
				digit = (h-55);
			else if (96 < h && h < 103) // a-f
				digit = (h-87);
			else
				throw new Exception("Invalid character '" ~ h ~"' for Color()");
			result.ub[i/2] += digit * (15*((i+1)%2)+1); // gets low or high nibble
		}
		return result;
	}
	
	
	/// Get the Color as an array of float.
	float[] f()
	{	float[4] res;
		res[0] = r * frac;
		res[1] = g * frac;
		res[2] = b * frac;
		res[3] = a * frac;
		return res.dup;
	}
	
	/// Get the Color as a Vec3f.
	Vec3f vec3f()
	{	Vec3f res;
		res.v[0] = r * frac;
		res.v[1] = g * frac;
		res.v[2] = b * frac;
		return res;
	}

	/// Get the Color as a Vec4f.
	Vec4f vec4f()
	{	Vec4f res;
		res.v[0] = r * frac;
		res.v[1] = g * frac;
		res.v[2] = b * frac;
		res.v[3] = a * frac;
		return res;
	}
	
	/**
	 * Get the color as a string.
	 * Params:
	 * lower = return lower case hexadecimal digits*/ 
	char[] hex(bool lower=false)
	{	if (lower)
			return formatString("%.8x", bswap(ui));
		return formatString("%.8X", bswap(ui));
	}
	/// ditto
	char[] toString()
	{	return hex();
	}
	
	unittest
	{	writefln(cast(ubyte)257);
		assert(Color.sizeof == 4);
		
		// Test initializers
		assert(Color([0, 102, 51, 255]).hex == "006633FF");
		assert(Color([0.0f, 0.4f, 0.2f, 1.0f]).hex == "006633FF");
		assert(Color(0xFF336600).hex == "006633FF");
		
		// Test converters
		assert(Color("abcdef97").hex == "ABCDEF97");
		assert(Color("006633FF").vec4f == Vec4f(0.0f, 0.4f, 0.2f, 1.0f));
		assert(Color("006633FF").ui == 0xFF336600);
	}	
}





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
		static if(T.sizeof < 2)
			throw new Exception("Variable must be at least 2 bytes to be converted to a word.");
		memcpy(&res.s, &i, 2);
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
		static if(T.sizeof < 4)
			throw new Exception("Variable must be at least 4 bytes to be converted to a dword.");		
		memcpy(&res.i, &i, 4);
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
		static if(T.sizeof < 8)
			throw new Exception("Variable must be at least 8 bytes to be converted to a qword.");
		memcpy(&res.l, &i, 8);
		return res;
	}
	
	unittest
	{	assert(qword.sizeof == 8);
		assert(qword(3L).l == 3L);
		assert(qword("yageyage").c == "yageyage");
		assert(qword(3.0).l == qword(qword(1.0).d + qword(2.0).d).l);
	}
}

