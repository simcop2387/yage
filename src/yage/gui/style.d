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
import tango.text.Unicode;
import tango.text.convert.Format;
import tango.util.Convert;
import yage.core.cache;
import yage.core.color;
import yage.core.math.vector;
import yage.resource.font;
import yage.resource.manager;
import yage.resource.material;
import yage.resource.texture;
import yage.gui.exceptions;

import yage.core.timer;

/**
 * Represents a CSS value.  It can store pixels or precent. */
struct CSSValue
{	
	/**
	 * CSSValues used to set units for measurements, such as width, padding, etc. */
	// should this be in CSSValue?
	enum Unit
	{	PX=0, ///
		PERCENT=1 /// ditto
	}	
	
	package float value=float.nan;
	package ubyte unit = Unit.PX;
	
	/**
	 * Allow assignments from ints, floats and strings. 
	 * Example:
	 * --------
	 * CSSValue height;
	 * height = 3; // width is 3 pixels
	 * height = "3%"; // width is 3% of parent's height
	 * --------
	 */
	CSSValue opAssign(float v)
	{	value = v>0 || isNaN(v) ? v : 0;
		unit = Unit.PX;
		return *this;
	}
	CSSValue opAssign(char[] v) /// ditto
	{	if (v[length-1] == '%')
		{	value = to!(float)(v[0..length-1]);
			unit = Unit.PERCENT;
		}
		else // to!(float) still works when v has trailing characters
		{	value = to!(float)(v[0..length]);
			unit = Unit.PX;
		}
		value = value>0 ? value : 0;
		return *this;
	}
	unittest
	{	CSSValue a;
		a = "3%";
		assert(a.value == 3);
		assert(a.unit == CSSValue.Unit.PERCENT);
		a = "5";
		assert(a.value == 5);
		assert(a.unit == CSSValue.Unit.PX);
	}
	
	/**
	 * Constructor for initializing the values
	 * Params:
	 *     v = the value to set
	 *     isPercent = If precent, v will be based on the Surface parent's value from 0 to 100%*/
	static CSSValue opCall(float v, bool isPercent=false)
	{	CSSValue result;
		result.value = v;
		result.unit = isPercent;
		return result;
	}
	static CSSValue opCall(char[] v) /// ditto
	{	CSSValue result;
		result = v;
		return result;
	}
	
	/**
	 * Get the value in terms of pixels or percent, if it's not already a percent value. 
	 * Params:
	 *     target = If the value is a pixel value, it will be converted to a percentage in terms of this width/height. 
	 *     allow_nan If false, nan's will be converted to 0.*/
	float toPx(float target, bool allow_nan=true)
	{	if (!allow_nan && isNaN(value))
			return 0;
		if (unit==Unit.PERCENT)
			return value*target*0.01f;
		return value;
	}
	float toPercent(float target, bool allow_nan=true) /// ditto
	{	if (!allow_nan && isNaN(value))
			return 0;
		if (unit==Unit.PERCENT)
			return value*target*100f;
		return value;
	}

	/**
	 * Returns: The value as it would be printed in a CSS string. */
	char[] toString()
	{	if (isNaN(value))
			return "auto";
		return to!(char[])(value) ~ (unit==Unit.PX ? "px" : "%");
	}
}

/**
 * This struct is used to specify the style of a Surface.
 * Inspired by the <a href="http://www.w3schools.com/css/css_reference.asp">CSS specification</a>.
 * Much of htis functionality is still unfinished. 
 * 
 * TODO:
 * 
 * Additional CSS3 border-image properties? 
 * Background image positioning
 * inline a href
 * cursor and cursor size.
 * letter spacing
 * opacity
 * default skin
 * toString()
 * scale
 * inherit?
 * TextAlign.JUSTIFY */
struct Style
{
	/// CSSValues that can be assigned to the textAlign property.
	enum TextAlign
	{	LEFT, ///
		CENTER, /// ditto
		RIGHT, /// ditto
		JUSTIFY /// ditto
	}
	
	/// CSSValues that can be assigned to the textDecoration property.
	enum TextDecoration
	{	NONE, ///
		UNDERLINE, /// ditto
		OVERLINE, /// ditto
		LINETHROUGH /// ditto
	}

	/// CSSValues that can be assigned to the borderImagestyle property.
	enum BorderImageStyle
	{	STRETCH, ///
		ROUND, /// ditto
		REPEAT	 /// ditto
	}

	/// CSSValues that can be assigned to the fontStyle property.
	enum FontStyle
	{	NORMAL, ///
		ITALIC /// ditto
	}

	/// CSSValues that can be assigned to the fontWeight property.
	enum FontWeight
	{	NORMAL, ///
		BOLD /// ditto
	}
	
	union { 
		struct { 
			CSSValue top; /// Distance of an edge from its parent, use float.nan to leave unset.
			CSSValue right; /// ditto
			CSSValue bottom; /// ditto
			CSSValue left; /// ditto
		} 
		package CSSValue[4] dimension; // internal use, not supported by css
	}
	
	union {
		struct {
			CSSValue width = CSSValue(float.nan); /// Width and height of the Surface.  Use float.nan to leave unset.
			CSSValue height = CSSValue(float.nan); /// ditto
		}
		package CSSValue[2] size; // internal use, not supported by css.
	}
	 
	union { 
		struct { 
			CSSValue borderTopWidth = CSSValue(0); /// Border widths
			CSSValue borderRightWidth = CSSValue(0); /// ditto
			CSSValue borderBottomWidth = CSSValue(0); /// ditto
			CSSValue borderLeftWidth = CSSValue(0); /// ditto
		} 
		CSSValue[4] borderWidth; /// Set all four border widths in one array.
	}
	
	union {
		struct {
			Color borderColorTop;/// Border colors
			Color borderColorRight; /// ditto
			Color borderColorBottom; /// ditto
			Color borderColorLeft; /// ditto
		}
		Color[4] borderColor; /// Set all four border colors in one array.
	}
	
	union {
		struct {
			GPUTexture borderTopImage; /// Border Images (TODO: support border-style and border-image-widths?)
			GPUTexture borderRightImage; /// ditto
			GPUTexture borderBottomImage; /// ditto
			GPUTexture borderLeftImage; /// ditto
		}
		GPUTexture[4] borderImage; /// Set the four top/right/bottom/left border images in one array.
	}
	GPUTexture borderCenterImage; /// Border center image (not a part of CSS3.
	
	union {
		struct {
			GPUTexture borderTopLeftImage; /// Border corner images
			GPUTexture borderTopRightImage;	 /// ditto		
			GPUTexture borderBottomLeftImage; /// ditto
			GPUTexture borderBottomRightImage; /// ditto
		}
		GPUTexture[4] borderCornerImage; /// Set the four border corner images images in one array.
	}
	
	union { 
		struct { 
			CSSValue paddingTop = CSSValue(0); /// Padding (the space inside the border surrounding any text or children)
			CSSValue paddingRight = CSSValue(0); /// ditto
			CSSValue paddingBottom = CSSValue(0); /// ditto
			CSSValue paddingLeft = CSSValue(0); /// ditto
		} 
		CSSValue[4] padding; /// Set all four padding sizes in one array.
	}
	
	/// Background image and color.  backgroundColor is drawn first, with backgroundImage second, then borderImage on top.
	GPUTexture backgroundImage; // just streteched for now.
	Color backgroundColor; /// ditto

	// Cursor
	Material cursor;
	float cursorSize=float.nan; // in pixels, float.nan to default to size of image.
	
	/// Font properties
	Font fontFamily;
	CSSValue fontSize = CSSValue(12); /// ditto
	FontStyle fontStyle; /// ditto
	FontWeight fontWeight; /// ditto
	
	/// Text properties
	Color color = {r:0, g:0, b:0, a:255};
	TextAlign textAlign = TextAlign.LEFT; /// ditto
	byte  textDecoration = TextDecoration.NONE; /// ditto
	CSSValue lineHeight = CSSValue(float.nan); /// ditto
	CSSValue letterSpacing; /// ditto
	

	// Other
	float opacity = 1; // 0 to 1.
	bool visible = true; /// Set whether the element is visible. visibility is an alias of visible for CSS compatibility.
	int zIndex; /// Sets the stack order of the surface relative to its siblings.

	/**
	 * Constructor, returns a new Style with all properties set to their defaults. */
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
		scope styles = Cache.getRegex(";\\s*").split(style);
		foreach (exp; styles)
		{	char[][] tokens = Cache.getRegex(":\\s*").split(exp);
			if (tokens.length<2)
				continue;
			char[] property = toLower(substitute(tokens[0], "-", "")); // garbage
			tokens = Cache.getRegex("\\s+").split(tokens[1]);
			
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
				
				case "textalign":			textAlign = translateTextAlign[tokens[0]]; break;
				case "textdecoration":		textDecoration = translateTextDecoration[tokens[0]]; break;
				
				case "opacity":				opacity = to!(float)(tokens[0]);  break;
				case "zIndex":				zIndex = to!(int)(tokens[0]); break;
				case "visibility":			visible = tokens[0] != "hidden"; break;
				
				default:
					throw new CSSException("Unsupported CSS Property: '", property, "'.");
			}
		}
	}

	/**
	 * Get string of css text storing the values of this style.
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

	// Translation tables (must be here to avoid fwd reference errors)
	private static TextAlign[char[]] translateTextAlign;
	private static byte[char[]] translateTextDecoration;
	private static FontStyle[char[]] translateFontStyle;
	private static FontWeight[char[]] translateFontWeight;
	static this()
	{	translateTextAlign      = [cast(char[])"left":TextAlign.LEFT, "center": TextAlign.CENTER, "right": TextAlign.RIGHT, "justify": TextAlign.JUSTIFY];
		translateTextDecoration = [cast(char[])"none":0, "underline": 1, "overline": 2, "line-through": 3];
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