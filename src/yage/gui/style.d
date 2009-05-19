/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a> 
 */

module yage.gui.style;

import tango.io.Stdout;
import tango.math.IEEE;
import tango.text.Regex;
import tango.text.Util;
import tango.text.Ascii;
import tango.text.convert.Format;
import tango.util.Convert;
import yage.core.color;
import yage.core.math.vector;
import yage.resource.font;
import yage.resource.manager;
import yage.resource.material;
import yage.resource.texture;
import yage.gui.exceptions;

import std.stdio;

/**
 * Represents a CSS value.  It can store pixels or precent. */
struct Value
{	float value=float.nan; ///
	ubyte unit = Style.Unit.PX; ///
	
	/**
	 * Allow assignments from ints, floats and strings. 
	 * Example:
	 * --------
	 * Value width;
	 * width = "3%";
	 * --------
	 */
	Value opAssign(float v) /// ditto
	{	value = v;
		unit = Style.Unit.PX;
		return *this;
	}
	Value opAssign(char[] v) /// ditto
	{	if (v[length-1] == '%')
		{	value = to!(float)(v[0..length-1]);
			unit = Style.Unit.PERCENT;
		}
		else // to!(float) still works when v has trailing characters
		{	value = to!(float)(v[0..length]);
			unit = Style.Unit.PX;
		}
		return *this;
	}
	unittest
	{	Value a;
		a = "3%";
		assert(a.value == 3);
		assert(a.unit == Style.Unit.PERCENT);
		a = "5";
		assert(a.value == 5);
		assert(a.unit == Style.Unit.PX);
	}
	
	/**
	 * Allows for compile time initialization */
	static Value opCall(float v, ubyte unit=0)
	{	Value result;
		result.value = v;
		result.unit = unit;
		return result;
	}
	static Value opCall(char[] v)
	{	Value result;
		result = v;
		return result;
	}
	
	/** 
	 * Get the value in terms of pixels, if it's not already a pixel value
	 * If it's in percent, that percentage of target will be returned. */
	float toPx(float target, bool allow_nan=true)
	{
		float result = value;
		if (unit==Style.Unit.PERCENT)
			result *= target*0.01f;
		if (!allow_nan && isNaN(result))
			result = 0;
		return result;
	}
	
	/**
	 * Get the value in terms of percent, if it's not already a percent value. 
	 * Params:
	 *     target = If it's a pixel value, it will be converted to a percentage in terms of this width/height. */
	float toPercent(float target, bool allow_nan=true)
	{	float result = value;
		if (unit==Style.Unit.PERCENT)
			result /= target*100f;
		if (!allow_nan && isNaN(result))
			result = 0;
		return result;
	}

	/**
	 * Returns: The value as it would be printed in a CSS string. */
	char[] toString()
	{	if (isNaN(value))
			return "auto";
		return to!(char[])(value) ~ (unit==Style.Unit.PX ? "px" : "%");
	}
}

/**
 * Specifies the style of a Surface.
 * Inspired by the <a href="http://www.w3schools.com/css/css_reference.asp">CSS specification</a>.
 * 
 * This struct is not fully documented. */
struct Style
{			
	/**
	 * Enumeration values used to set units for measurements, such as width, padding, etc. */
	enum Unit
	{	PX=0, ///
		PERCENT=1 ///
	}
	
	enum TextAlign
	{	LEFT = 0,
		CENTER = 1,
		RIGHT = 2		
	}
	
	enum TextDecoration
	{	NONE,
		UNDERLINE,
		OVERLINE,
		LINETHROUGH
	}
	
	enum BorderImageStyle
	{	STRETCH,
		ROUND,
		REPEAT		
	}
	
	enum FontStyle
	{	NORMAL,
		ITALIC
	}
	
	enum FontWeight
	{	NORMAL,
		BOLD
	}
	
	// Dimension
	union { 
		struct { 
			Value top;     /// Distance of an edge from its parent, use float.nan to leave unset.
			Value right;   /// ditto
			Value bottom;  /// ditto
			Value left;    /// ditto
		} 
		Value[4] dimension; // internal use, not supported by css
	}	
	union {
		struct {
			Value width = Value(float.nan);
			Value height = Value(float.nan);
		}
		Value[2] size; // internal use, not supported by css.
	}

	// Border sizes and colors
	union { 
		struct { 
			Value borderTopWidth = Value(0);
			Value borderRightWidth = Value(0);
			Value borderBottomWidth = Value(0);
			Value borderLeftWidth = Value(0);
		} 
		Value[4] borderWidth;
	}
	union {
		struct {
			Color borderColorTop;
			Color borderColorRight;
			Color borderColorBottom;
			Color borderColorLeft;
		}
		Color[4] borderColor;
	}
	
	// Border Image (TODO: support border-style and border-image-widths?)
	union {
		struct {
			GPUTexture borderTopImage;
			GPUTexture borderRightImage;
			GPUTexture borderBottomImage;
			GPUTexture borderLeftImage;
		}
		GPUTexture[4] borderImage;
	}
	GPUTexture borderCenterImage;
	
	union {
		struct {
			GPUTexture borderTopLeftImage;
			GPUTexture borderTopRightImage;			
			GPUTexture borderBottomLeftImage;
			GPUTexture borderBottomRightImage;
		}
		GPUTexture[4] borderCornerImage;
	}
	
	// Padding
	union { 
		struct { 
			Value paddingTop = Value(0);
			Value paddingRight = Value(0);
			Value paddingBottom = Value(0);
			Value paddingLeft = Value(0);
		} 
		Value[4] padding;
	}
	
	// Background
	GPUTexture backgroundImage; // just streteched for now.
	Color backgroundColor;

	// Cursor
	Material cursor;
	float cursorSize=16; // in pixels
	
	// Font
	Font fontFamily;
	Value fontSize = Value(12); // default to 12px font size.
	FontStyle fontStyle;
	FontWeight fontWeight;	
	
	// Text	
	Color color = {r:0, g:0, b:0, a:255};
	byte  textDecoration;
	Value lineHeight;
	Value letterSpacing;
	

	// Other
	float opacity = 1; // 0 to 1.
	TextAlign textAlign = TextAlign.LEFT;
	bool visible = true; /// Set whether the element is visible. visibility is an alias of visible for CSS compatibility.
	int zIndex;
	
	/**
	 * Struct constructor, returns the default style. */
	static Style opCall()
	{	Style result;
		return result;
	}
	

	/**
	 * Set properties from a string of text, css style.
	 * TODO: Fix this function so it cleans up its garbage.
	 * Example:
	 * style.set("border: 2px solid black; font-family: arial.ttf; color: white");*/
	void set(char[] style)
	{	
		if (!style.length)
			return;
		
		// Parse and apply the style
		Regex rxTokens = Regex(":\\s*");
		Regex rxProperties = Regex("\\s+");
		foreach (exp; Regex(";\\s*").split(style))
		{	char[][] tokens = rxTokens.split(exp);
			if (tokens.length<2)
				continue;
			char[] property = toLower(substitute(tokens[0], "-", "")); // garbage?
			tokens = rxProperties.split(tokens[1]);
			
			// TODO: account for parse errors.			
			switch (property)
			{	// TODO: more properties
				case "color":				color = Color(tokens[0]); break;
			
				case "backgroundcolor":		backgroundColor = Color(tokens[0]); break;
				case "backgroundimage":		backgroundImage = ResourceManager.texture(removeUrl(tokens[0])).texture; break;				
			
				case "font":		/*todo */  break;
				case "fontsize":	fontSize = tokens[0];  break;
				case "fontfamily":	fontFamily = ResourceManager.font(removeUrl(tokens[0]));  break;
				case "fontstyle":	fontStyle = translateFontStyle[tokens[0]];  break;
				case "fontweight":	fontWeight = translateFontWeight[tokens[0]];  break;
			
				case "top":			top = tokens[0];  break;
				case "right":		right = tokens[0];  break;
				case "bottom":		bottom = tokens[0];  break;
				case "left":		left = tokens[0];  break;
				case "dimension":	setEdge(dimension, tokens);  break;
				case "width":		width = tokens[0];  break;
				case "height":		height = tokens[0];  break;
				case "size": 		setEdge(size, tokens);  break;
				
				case "border":		setEdge(borderWidth, tokens[0..1]);  borderColor[0..4] = Color(tokens[$-1]);  break;
				case "bordercolor":	setEdge(borderColor, tokens);  break;
				case "borderwidth":	setEdge(borderWidth, tokens);  break;
				case "borderimage":	borderImage[0..4] = borderCornerImage[0..4] = borderCenterImage = 
										ResourceManager.texture(removeUrl(tokens[0])).texture;  break;
										
				case "bordertop":			borderWidth[0] = tokens[0];  borderColor[0] = Color(tokens[$-1]);  break;
				case "bordertopcolor":		borderColor[0] = Color(tokens[0]);  break;
				case "bordertopwidth":		borderWidth[0] = tokens[0];  break;
				
				case "borderright":			borderWidth[1] = tokens[0];  borderColor[1] = Color(tokens[$-1]);  break;
				case "borderrightcolor":	borderColor[1] = Color(tokens[0]);  break;
				case "borderrightwidth":	borderWidth[1] = tokens[0];  break;
				
				case "borderbottom":		borderWidth[2] = tokens[0];  borderColor[2] = Color(tokens[$-1]);  break;
				case "borderbottomcolor":	borderColor[2] = Color(tokens[0]);  break;
				case "borderbottomwidth":	borderWidth[2] = tokens[0];  break;
				
				case "borderleft":			borderWidth[3] = tokens[0];  borderColor[3] = Color(tokens[$-1]);  break;
				case "borderleftcolor":		borderColor[3] = Color(tokens[0]);  break;
				case "borderleftwidth":		borderWidth[3] = tokens[0];  break;
				
				case "padding":				setEdge(padding, tokens);  break;
				case "paddingopwidth":		padding[0] = tokens[0];  break;
				case "paddingrightwidth":	padding[1] = tokens[0];  break;
				case "paddingbottomwidth":	padding[2] = tokens[0];  break;
				case "paddingleftwidth":	padding[3] = tokens[0];  break;
				
				case "lineheight":			lineHeight = tokens[0]; break;
				
				case "textdecoration":		textDecoration = translateTextDecoration[tokens[0]]; break;
				
				case "zIndex":				zIndex = to!(int)(tokens[0]); break;
				case "visibility":			visible = tokens[0] != "hidden"; break;
				
				default:
					throw new CSSException("Unsupported CSS Property: '", property, "'.");
			}
		}		
	}

	/**
	 * Get a string representation of this style.
	 * Only the properties that differ from the defaults will be returned. */
	char[] toString()
	{	Style def; // default style, req'd by styleCompare
		char[][] result;
		
		mixin(styleCompare!("top"));
		mixin(styleCompare!("right"));
		mixin(styleCompare!("bottom"));
		mixin(styleCompare!("left"));
		mixin(styleCompare!("width"));
		mixin(styleCompare!("height"));

		mixin(styleCompare!("borderWidth"));
		mixin(styleCompare!("borderColor"));
		//mixin(styleCompare!("borderImage"));
		//mixin(styleCompare!("borderCenterImage"));
		//mixin(styleCompare!("borderCornerImage"));		
		mixin(styleCompare!("padding"));
		//mixin(styleCompare!("backgroundImage"));
		//mixin(styleCompare!("backgroundColor"));
		
		//mixin(styleCompare!("cursor"));		
		mixin(styleCompare!("cursorSize"));
		
		mixin(styleCompare!("fontFamily"));
		mixin(styleCompare!("fontSize"));
		mixin(styleCompare!("color"));
		
		mixin(styleCompare!("textDecoration"));
		mixin(styleCompare!("lineHeight"));
		mixin(styleCompare!("letterSpacing"));
		
		mixin(styleCompare!("opacity"));
		mixin(styleCompare!("textAlign"));
		mixin(styleCompare!("visible"));		
		mixin(styleCompare!("zIndex"));
			
		return join(result, "; ");
	}

	// Translation tables
	private static byte[char[]] translateTextDecoration;
	private static FontStyle[char[]] translateFontStyle;
	private static FontWeight[char[]] translateFontWeight;
	static this()
	{	translateTextDecoration = [cast(char[])"none":0, "underline": 1, "overline": 2, "line-through": 3];
		translateFontStyle      = [cast(char[])"normal":FontStyle.NORMAL, "italic": FontStyle.ITALIC, "oblique": FontStyle.ITALIC];
		translateFontWeight     = [cast(char[])"normal":FontWeight.NORMAL, "bold": FontWeight.BOLD];
	}
	
}

/*
 * Helper for toString() */
private template styleCompare(char[] name="")
{     const char[] styleCompare =
    	 `if (`~name~`!=def.`~name~`) result ~= "`~name~`: "~Format("{}", `~name~`);`;
}

/* Helper for set)
 * Remove the url('...') from a css path, if it's present.
 * Returns: A slice of the original url to avoid creating garbage.*/ 
private char[] removeUrl(char[] url)
{	if (url[0..5] == "url('" || url[0..5] == "url(\"")
		return url[5..length-2];
	if (url[0..4] == "url(" || url[0..4] == "url(")
		return url[4..length-1];
	return url;
}

/*
 * Helper for set()
 * Set up to values of any type from an array of tokens, using T's static opCall. */
private void setEdge(T)(T[] edge, char[][] tokens)
{	if (tokens.length > 0)					
	{	edge[0..3] = edge[3] = (tokens[0]);  
		if (tokens.length > 1)
		{	edge[1] = edge[3] = tokens[1];
			if (tokens.length > 2 && edge.length > 2) // edges are always 2 or 4
			{	edge[2] = tokens[2];
				if (tokens.length > 3)
					edge[3] = tokens[3]; 
	}	}	}
}