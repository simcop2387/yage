/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.core.color;

import yage.core.math;
import yage.core.vector;
import yage.core.types;
import yage.core.parse;
import std.intrinsic;

/**
 * A struct used to represent a color.
 * Colors are represented in RGBA format.
 * Note that uints and dwords store the bytes in reverse,
 * so Color(0x6633ff00).hex == "00FF3366"
 * All Colors default to transparent black.
 * TODO: Convert to using four floats for better arithmetic?
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
		{	case "black":	return Color(0xFF000000);
			case "blue":	return Color(0xFFFF0000);
			case "brown":	return Color(0xFFA52A2A);
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
			case "violet":	return Color(0xFFEE82EE);
			case "white":	return Color(0xFFFFFFFF);
			case "yellow":	return Color(0xFF00FFFF);
			default: break;
		}
		
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