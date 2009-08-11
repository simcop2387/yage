/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.core.color;

import tango.io.Stdout;
import tango.core.BitManip;
import tango.math.Math;
import tango.text.Ascii;
import tango.text.convert.Format;

import yage.core.math.math;
import yage.core.math.vector;
import yage.core.types;
import yage.core.parse;
import yage.core.object2;

/**
 * A struct used to represent a color.
 * Colors are represented in RGBA format.
 * Note that uints and dwords store the bytes in reverse (little endian),
 * so Color(0x6633ff00).hex == "00FF3366"
 * All Colors default to transparent black.
 * TODO: Convert to using four floats for better arithmetic, or just make it templated?
 * 
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
	private const real frac = 1.0f/255;
	
	// public static Color GREEN = Color(0xFF008000); // fails due to CTFE union bug.
	
	union // this union breaks CTFE with this struct
	{	uint ui;	/// Get the Color as a uint
		ubyte[4] ub;/// Get the Color as an array of ubyte
		struct { ubyte r, g, b, a; } /// Access each color component: TODO: test to ensure order is correct.
	}

	/**
	 * Initialize from 3 or 4 values (red, green, blue, alpha).
	 * Integer types rante from 0 to 255 and floating point types range from 0 to 1. */
	static Color opCall(int r, int g,int b, int a=255)
	{	Color res;
		res.r=r;
		res.b=b;
		res.g=g;
		res.a=a;
		return res;
	}
	unittest
	{	assert(Color(0x99663300) == Color(0, 0x33, 0x66, 0x99));
	}
	
	static Color opCall(float r, float g, float b, float a=1) /// ditto
	{	Color res;
		res.r=cast(ubyte)clamp(r*255, 0.0f, 255.0f);
		res.b=cast(ubyte)clamp(b*255, 0.0f, 255.0f);
		res.g=cast(ubyte)clamp(g*255, 0.0f, 255.0f);
		res.a=cast(ubyte)clamp(a*255, 0.0f, 255.0f);
		return res;
	}
	static Color opCall(ubyte[] v) /// ditto
	{	Color res;
		for (int i=0; i<max(v.length, 4); i++)
			res.ub[i] = cast(ubyte)(v[i]);
		return res;
	}
	static Color opCall(int[] v) /// ditto
	{	Color res;
		for (int i=0; i<max(v.length, 4); i++)
			res.ub[i] = cast(ubyte)(v[i]);
		return res;
	}
	static Color opCall(float[] f) /// ditto
	{	Color res;
		for (int i=0; i<min(f.length, 4); i++)
			res.ub[i] = cast(ubyte)clamp(f[i]*255, 0.0f, 255.0f);
		return res;
	}
	static Color opCall(Vec3f v) /// ditto
	{	return Color(v.v);
	}
	static Color opCall(Vec4f v) /// ditto
	{	return Color(v.v);
	}
	
	/**
	 * Initialize from a uint, string hexadecimal value, or english color name.
	 * Strings. can be a 6 or 8 digit hexadecimal or an English color name.
	 * Black, blue, brown, cyan, gold, gray/grey, green, indigo, magenta, orange, 
	 * pink, purple, red, transparent, violet, white, and yellow are supported.
	 * See: <a href="http://www.w3schools.com/css/css_colornames.asp">CSS color names</a>*/
	static Color opCall(uint ui)
	{	Color res;
		res.ui = ui;
		return res;
	}
	static Color opCall(char[] string)
	{	
		// An english color name
		if (string.length <= 20)
		{	char[20] lower;
			toLower(string, lower);
			switch (lower[0..string.length])
			{	case "black":	return Color(0xFF000000);
				case "blue":	return Color(0xFFFF0000);
				case "brown":	return Color(0xFF2A2AA5);				
				case "cyan":	return Color(0xFFFFFF00);
				case "gold":	return Color(0xFF00D7FF);
				case "gray":	
				case "grey":	return Color(0xFF808080);
				case "green":	return Color(0xFF008000);
				case "indigo":	return Color(0xFF82004B);
				case "magenta":	return Color(0xFFFF00FF);
				case "orange":	return Color(0xFF00A5FF);
				case "pink":	return Color(0xFFCBC0FF);
				case "purple":	return Color(0xFF800080);
				case "red":		return Color(0xFF0000FF);
				case "transparent":	return Color(0x00000000); // transparent
				case "violet":	return Color(0xFFEE82EE);
				case "white":	return Color(0xFFFFFFFF);
				case "yellow":	return Color(0xFF00FFFF);
				default: break;
		}	}
		
		// Allow hex colors to start with hash.
		if (string[0] == '#')
			string = string[1..length];
			
		// Append alpha to 6-digit hex string.
		if (string.length == 6)
			string ~= "FF"; // creates garbage!
		
		// Convert string one char at a time.
		Color result;
		int digit;
		foreach (int i, char h; string)
		{	if (i>=8)
				break;
		
			digit=0; // will be 0-15
			if (47 < h && h < 58)	// 0-9
				digit = (h-48);
			else if (64 < h && h < 71) // A-F
				digit = (h-55);
			else if (96 < h && h < 103) // a-f
				digit = (h-87);
			else
				throw new YageException("Invalid character '{}' for Color()", h);
			result.ub[i/2] += digit * (15*((i+1)%2)+1); // gets low or high nibble
		}
		return result;
	}
	
	/**
	 * Assign from a uint, string hexadecimal value, or english color name.
	 * Strings. can be a 6 or 8 digit hexadecimal or an English color name.
	 * Black, blue, brown, cyan, gold, gray/grey, green, indigo, magenta, orange, 
	 * pink, purple, red, transparent, violet, white, and yellow are supported.
	 * See: <a href="http://www.w3schools.com/css/css_colornames.asp">CSS color names</a>*/
	Color opAssign(char[] string)
	{	ui = Color(string).ui;
		return *this;
	}
	Color opAssign(uint value) /// ditto
	{	ui = value;
		return *this;
	}

	/// Allow casting color to a uint.
	uint opCast()
	{	return ui;		
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
	void f(float[4] result) /// ditto
	{	result[0] = r * frac;
		result[1] = g * frac;
		result[2] = b * frac;
		result[3] = a * frac;
	}
	
	/// Get the Color as a Vector
	Vec3f vec3f()
	{	Vec3f res;
		res.v[0] = r * frac;
		res.v[1] = g * frac;
		res.v[2] = b * frac;
		return res;
	}
	Vec4f vec4f() /// ditto
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
			return Format("{:x8}", bswap(ui)); // TODO: Fix/Test for big-endian systems
		return Format("{:X8}", bswap(ui));
	}
	/// ditto
	char[] toString()
	{	return hex();
	}
	
	unittest
	{	assert(Color.sizeof == 4);
			
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