/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 *
 * Miscellaneous function used for parsing.
 */

module yage.core.parse;

import tango.io.Stdout;
import tango.math.Math;
import tango.text.Ascii;
import tango.text.Util;
import tango.util.Convert;
import tango.text.convert.Format;

import std.format;

/// Convert a csv string of numbers to an array of floats
float[] csvToFloat(char[] csv)
{	float[] result;
	char[][] explode = split(csv, ", ");
	foreach (char[] token; explode)
		result~= to!(float)(token);
	return result;
}

/**
 * Convert an array of float color values (0-1) to hexadecimal. */
char[] floatToHex(float[] vec)
{	char[] result;
	foreach (float v; vec)
		result ~= Format.convert("{:X8}", cast(ubyte)(v*255));
	return result;
}

/**
 * Convert a hexadecimal string to an unsigned int.
 * Throws:
 * Exception if hex contains an invalid hexadecimal character. */
uint hexToUint(char[] hex)
{	uint result = 0, digit;
	for (int i=0; i<hex.length; i++)
	{	digit=0;
		if (47 < hex[i] && hex[i] < 58)
			digit = (hex[i]-48);
		else if (64 < hex[i] && hex[i] < 71)
			digit = (hex[i]-55);
		else if (96 < hex[i] && hex[i] < 103)
			digit = (hex[i]-87);
		else
			throw new Exception("Invalid character '" ~ hex[i] ~"' for hexToUint()");
		result+=digit*pow(16, cast(float)hex.length-i-1);;
	}
	return result;
}

/**
 * Convert a string to 0 or 1.
 * "true", "yes", "on", "y", and "1" will all return true,
 * "false", "no", "off", "n", and "0" will all return false,
 * and an Exception is thrown for any other value.*/
bool strToBool(char[] word)
{	switch (toLower(word))
	{	case "true":
		case "yes":
		case "on":
		case "y":
		case "1":
			return true;
		case "false":
		case "no":
		case "off":
		case "n":
		case "0":
			return false;
		default:
			throw new Exception("strToBool() cannot parse '" ~ word ~"'.");
}	}

/// Convert 1 to "true" and 0 to "false".
char[] boolToString(bool a)
{	if (a) return "true";
	return "false";
}

/// Encode characters such as &, <, >, etc. as their xml/html equivalents
char[] xmlEncode(char[] src)
{   char[] tempStr;
	tempStr = substitute(src    , "&", "&amp;");
	tempStr = substitute(tempStr, "<", "&lt;");
	tempStr = substitute(tempStr, ">", "&gt;");
	return tempStr;
}

/// Convert xml-encoded special characters such as &amp;amp; back to &amp;.
char[] xmlDecode(char[] src)
{	char[] tempStr;
	tempStr = substitute(src    , "&amp;", "&");
	tempStr = substitute(tempStr, "&lt;",  "<");
	tempStr = substitute(tempStr, "&gt;",  ">");
	return tempStr;
}

