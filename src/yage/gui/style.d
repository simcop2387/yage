/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a> 
 */

module yage.gui.style;

import tango.math.IEEE;
import tango.text.Util;
import tango.text.Unicode;
import tango.util.Convert;

import yage.core.color;
import yage.core.format;
import yage.core.math.matrix;
import yage.core.math.vector;
import yage.core.types;
import yage.resource.font;
import yage.resource.manager;
import yage.resource.graphics.material;
import yage.resource.graphics.texture;
import yage.gui.exceptions;
import yage.system.log;

import yage.core.timer;

/**
 * Represents a CSS value.  It can store pixels or precent. */
struct CSSValue
{	
	static const CSSValue AUTO;  /// Has a value of float.nan.  This means inherit from parent style.
	
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
	CSSValue opAssign(string v) /// ditto
	{	if (v[length-1] == '%')
		{	value = to!(float)(v[0..length-1]);
			unit = Unit.PERCENT;
		}
		else // to!(float) still works when v has trailing characters
		{	if (v.length > 2 && v[length-2..length]=="px")
				value = to!(float)(v[0..length-2]);
			else
				value = to!(float)(v[0..length]);
			unit = Unit.PX;
		}
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
	static CSSValue opCall(string v) /// ditto
	{	CSSValue result;
		result = v;
		return result;
	}
	
	/**
	 * Get the value in terms of pixels or percent, if it's not already a percent value. 
	 * Params:
	 *     target = If the value is a pixel value, it will be converted to a percentage in terms of this width/height. 
	 *     allow_nan If false, nan's will be converted to 0.*/
	float toPx(lazy float target, bool allow_nan=true)
	{	if (!allow_nan && isNaN(value))
			return 0;
		if (unit==Unit.PERCENT)
			return value*target*0.01f;
		return value;
	}
	float toPercent(lazy float target, bool allow_nan=true) /// ditto
	{	if (!allow_nan && isNaN(value))
			return 0;
		if (unit==Unit.PERCENT)
			return value*target*100f;
		return value;
	}

	/**
	 * Returns: The value as it would be printed in a CSS string. */
	string toString()
	{	if (isNaN(value))
			return "auto";
		return to!(string)(value) ~ (unit==Unit.PX ? "px" : "%");
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
	/// CSSValues that can be assigned to the borderImagestyle property.
	enum BorderImageStyle
	{	STRETCH, /// Allowed values.
		ROUND, /// ditto
		REPEAT	 /// ditto
	}

	/// CSSValues that can be assigned to the fontStyle property.
	enum FontStyle
	{	AUTO, /// Allowed values.
		NORMAL, /// ditto
		ITALIC /// ditto
	}

	/// CSSValues that can be assigned to the fontWeight property.
	enum FontWeight
	{	AUTO, /// Allowed values.
		NORMAL, /// ditto
		BOLD /// ditto
	}
	
	///
	enum Overflow
	{	VISIBLE, /// Allowed values.
		HIDDEN /// ditto
	}
		
	/// CSSValues that can be assigned to the textAlign property.
	enum TextAlign
	{	AUTO, /// Allowed values.
		LEFT, /// ditto
		CENTER, /// ditto
		RIGHT, /// ditto
		JUSTIFY /// ditto
	}
	
	/// CSSValues that can be assigned to the textDecoration property.
	enum TextDecoration
	{	AUTO,
		NONE, /// Allowed values.
		UNDERLINE, /// ditto
		OVERLINE, /// ditto
		LINETHROUGH /// ditto
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
			Texture borderTopImage; /// Border Images (TODO: support border-style and border-image-widths?)
			Texture borderRightImage; /// ditto
			Texture borderBottomImage; /// ditto
			Texture borderLeftImage; /// ditto
		}
		Texture[4] borderImage; /// Set the four top/right/bottom/left border images in one array.
	}
	Texture borderCenterImage; /// Border center image (not a part of CSS3, this image is stretched to fit within the borders).
	
	union {
		struct {
			Texture borderTopLeftImage; /// Border corner images
			Texture borderTopRightImage;	 /// ditto		
			Texture borderBottomLeftImage; /// ditto
			Texture borderBottomRightImage; /// ditto
		}
		Texture[4] borderCornerImage; /// Set the four border corner images images in one array.
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
	Texture backgroundImage; // just streteched for now.
	Color backgroundColor; /// ditto

	// Cursor
	Material cursor; /// TODO: Unimplemented
	float cursorSize=float.nan; /// in pixels, float.nan to default to size of image.
	
	/**
	 * Font properties
	 * fontFamily = path or (soon) css name of the font to use.  */	
	string fontFamily = ResourceManager.DEFAULT_FONT;
	CSSValue fontSize = CSSValue(12); /// ditto
	FontStyle fontStyle; /// ditto
	FontWeight fontWeight; /// ditto
	
	private string lastFontFamily;
	private Font internalFont;
	
	/**
	 * Get a font resource from the font name.
	 * Can use better caching than ResourceManager.font() due to more information stored in the style and is therefore faster. */
	Font getFont()
	{	if (!internalFont || lastFontFamily != fontFamily)
		{	lastFontFamily = fontFamily;
			internalFont = ResourceManager.font(fontFamily);
		}
		return internalFont;
	}
	
	/**
	 * Text properties
	 * color = If null, inherits the value from the parent Surface. */
	Nullable!(Color) color = Nullable!(Color)(Color.BLACK); //{r:0, g:0, b:0, a:255};
	TextAlign textAlign = TextAlign.LEFT; /// ditto
	TextDecoration textDecoration = TextDecoration.NONE; /// ditto
	CSSValue lineHeight; /// ditto
	CSSValue letterSpacing; /// TODO: Unimplemented
	
	/**
	 * CSS 3D transform property, defaults to identity matrix.  See: http://w3.org/TR/css3-3d-transforms	 */
	Matrix transform;	

	// Other
	float opacity = 1; ///
	
	Overflow overflow; /// Set both overflow properties in one array.
	
	bool visible = true; /// Set whether the element is rendered, If false the Surface will still receive events.
	bool display = true; /// Set whether the element exists, If false, the Surface will not be rendered or receive events and will be treated like it doesn't exist.
	int zIndex; /// Sets the stack order of the surface relative to its siblings.
	
	bool backfaceVisibility = true; /// Draw the back side of surfaces if they're rotated in 3d.
	

	/**
	 * Constructor, returns a new Style with all properties set to their defaults. */
	static Style opCall(string style="")
	{	Style result;
		result.set(style);
		return result;
	}
	
	/**
	 * Set properties from a string of text, css style.
	 * TODO: Fix this function so it cleans up its garbage.
	 * Example:
	 * style.set("border: 2px solid black; font-family: arial.ttf; color: white");*/
	void set(string style)
	{	
		if (!style.length)
			return;
		
		// Parse and apply the style
		//scope styles = Cache.getRegex(";\\s*").split(style);
		foreach (expr; patterns(style, ";"))
		{	
			expr = trim(expr);
			scope string[] tokens = split(expr, ":");
			if (tokens.length<2)
				throw new CSSException("CSS Property: '%s' has no value", expr);
			string property = trim(tokens[0]);
			property = toLower(property);
			tokens = delimit(trim(tokens[1]), " \r\n\t");
			
			// TODO: account for parse errors.			
			switch (property)
			{	// TODO: more properties
				case "color":				color = Color(tokens[0]); break;
			
				case "background-color":	backgroundColor = Color(tokens[0]); break;
				case "background-image":	backgroundImage = ResourceManager.texture(removeUrl(tokens[0])); break;				
			
				case "font":  // font-style, font-weight, font-size/line-height, font-family
					foreach (i, token; tokens)
					{	if (token=="normal" || token=="italic" || token=="oblique")
							fontStyle = Style.stringToEnum!(FontStyle)(token);
						else if (token=="normal" || token=="bold")
							fontWeight = Style.stringToEnum!(FontWeight)(token);
						else if (!containsPattern(token, "url(") && (token.containsPattern("%") || token.containsPattern("px")))
						{	if (token.containsPattern("/"))
							{	string[] temp =  token.split("/");
								fontSize = temp[0];
								lineHeight = temp[1];
							} else
								fontSize = token;
						} else if (i>0)
							fontFamily = removeUrl(token);
					}
					break;
				case "font-size":			fontSize = tokens[0];  break;
				case "font-family":			fontFamily = removeUrl(tokens[0]);  break;
				case "font-style":			fontStyle = Style.stringToEnum!(FontStyle)(tokens[0]);  break;
				case "font-weight":			fontWeight = Style.stringToEnum!(FontWeight)(tokens[0]);  break;
			
				case "top":					top = tokens[0];  break;
				case "right":				right = tokens[0];  break;
				case "bottom":				bottom = tokens[0];  break;
				case "left":				left = tokens[0];  break;
				case "dimension":			setEdge(dimension, tokens);  break;
				case "width":				width = tokens[0];  break;
				case "height":				height = tokens[0];  break;
				case "size": 				setEdge(size, tokens);  break;
				
				case "border":				setEdge(borderWidth, tokens[0..1]);  borderColor[0..4] = Color(tokens[$-1]);  break;
				case "border-color":		setEdge(borderColor, tokens);  break;
				case "border-width":		setEdge(borderWidth, tokens);  break;
				case "border-image":		borderImage[0..4] = borderCornerImage[0..4] = borderCenterImage = 
												ResourceManager.texture(removeUrl(tokens[0]));  break;
										
				case "border-top":			borderWidth[0] = tokens[0];  borderColor[0] = Color(tokens[$-1]);  break;
				case "border-top-color":	borderColor[0] = Color(tokens[0]);  break;
				case "border-top-width":	borderWidth[0] = tokens[0];  break;
				
				case "border-right":		borderWidth[1] = tokens[0];  borderColor[1] = Color(tokens[$-1]);  break;
				case "border-right-color":	borderColor[1] = Color(tokens[0]);  break;
				case "border-right-width":	borderWidth[1] = tokens[0];  break;
				
				case "border-bottom":		borderWidth[2] = tokens[0];  borderColor[2] = Color(tokens[$-1]);  break;
				case "border-bottom-color":	borderColor[2] = Color(tokens[0]);  break;
				case "border-bottom-width":	borderWidth[2] = tokens[0];  break;
				
				case "border-left":			borderWidth[3] = tokens[0];  borderColor[3] = Color(tokens[$-1]);  break;
				case "border-left-color":	borderColor[3] = Color(tokens[0]);  break;
				case "border-left-width":	borderWidth[3] = tokens[0];  break;
				
				case "padding":				setEdge(padding, tokens);  break;
				case "padding-top-width":	padding[0] = tokens[0];  break;
				case "padding-right-width":	padding[1] = tokens[0];  break;
				case "padding-bottom-width":padding[2] = tokens[0];  break;
				case "padding-left-width":	padding[3] = tokens[0];  break;
				
				case "line-height":			lineHeight = tokens[0]; break;
				
				case "text-align":			textAlign = Style.stringToEnum!(TextAlign)(tokens[0]); break;
				case "text-decoration":		textDecoration = Style.stringToEnum!(TextDecoration)(tokens[0]); break;
				
				case "opacity":				opacity = to!(float)(tokens[0]);  break;
				case "overflow":			overflow = (toLower(tokens[0])=="hidden" ? Overflow.HIDDEN : Overflow.VISIBLE); break;
				case "zIndex":				zIndex = to!(int)(tokens[0]); break;
				case "display":				display = tokens[0] != "none" && tokens[0] != "false"; break;
				case "visibility":			visible = tokens[0] != "hidden" && tokens[0] != "false"; break;
				
				default:
					throw new CSSException("Unsupported CSS Property: '%s'", property);
			}
		}
	}

	/**
	 * Get string of css text storing the values of this style.
	 * Only the properties that differ from the defaults will be returned.
	 * TODO: Finish this function. */
	string toString()
	{	Style def; // default style, req'd by styleCompare
		string[] result;
		
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
		//mixin(styleCompare!("cursorSize"));
		
		if (cursorSize!=def.cursorSize && (!isNaN(cursorSize) && !isNaN(def.cursorSize))) 
			result ~= swritef("cursor-size: '%s'", cursorSize);
		
		if (fontFamily!=def.fontFamily) result ~= swritef("font-family: url('%s')", fontFamily);
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
	
	/**
	 * Convert the various Style enumerations to their css string format. */
	static string enumToString(Style.BorderImageStyle style)
	{	switch(style)
		{	case Style.BorderImageStyle.STRETCH: return "stretch";
			case Style.BorderImageStyle.ROUND: return "round";
			case Style.BorderImageStyle.REPEAT: return "repeat";
	}	}
	static string enumToString(Style.FontStyle style) /// ditto
	{	switch(style)
		{	case Style.FontStyle.AUTO: return "auto";
			case Style.FontStyle.NORMAL: return "normal";
			case Style.FontStyle.ITALIC: return "italic";
	}	}
	
	static string enumToString(Style.FontWeight style) /// ditto
	{	switch(style)
		{	case Style.FontWeight.AUTO: return "auto";
			case Style.FontWeight.NORMAL: return "normal";
			case Style.FontWeight.BOLD: return "bold";
	}	}
	static string enumToString(Style.Overflow style) /// ditto
	{	return style==Style.Overflow.VISIBLE ? "visible" : "hidden";
	}
	static string enumToString(Style.TextAlign style) /// ditto
	{	switch(style)
		{	case Style.TextAlign.AUTO: return "auto";
			case Style.TextAlign.LEFT: return "left";
			case Style.TextAlign.CENTER: return "center";
			case Style.TextAlign.RIGHT: return "right";
			case Style.TextAlign.JUSTIFY: return "justify";
	}	}
	static string enumToString(Style.TextDecoration style) /// ditto
	{	switch(style)
		{	case Style.TextDecoration.AUTO: return "auto";
			case Style.TextDecoration.NONE: return "none";
			case Style.TextDecoration.UNDERLINE: return "underline";
			case Style.TextDecoration.OVERLINE: return "overline";
			case Style.TextDecoration.LINETHROUGH: return "line-through";
		}
	}
	
	private static T stringToEnum(T)(string string)
	{	static if (is (T==Style.TextAlign))
			switch (string)
			{	case "auto": return TextAlign.AUTO; 
				case "left": return TextAlign.LEFT; 
				case "center": return TextAlign.CENTER; 
				case "right": return TextAlign.RIGHT; 
				case "justify": return TextAlign.JUSTIFY;
				default: throw new CSSException("Unsupported text-alignment %s", string);
			}
		static if (is (T==Style.TextDecoration))
			switch(string)
			{	case "auto": return TextDecoration.AUTO; 
				case "none": return TextDecoration.NONE; 
				case "underline": return TextDecoration.UNDERLINE; 
				case "overline": return TextDecoration.OVERLINE; 
				case "line-through": return TextDecoration.LINETHROUGH;
				default: throw new CSSException("Unsupported text-decoration %s", string);
			}
		static if (is (T==Style.FontStyle))
			switch(string)
			{	case "auto": return FontStyle.AUTO; 
				case "normal":return FontStyle.NORMAL; 
				case "italic":
				case "oblique": return FontStyle.ITALIC;
				default: throw new CSSException("Unsupported font-style %s", string);
			}
		static if (is (T==Style.FontWeight))
			switch(string)
			{	case "auto": return FontWeight.AUTO; 
				case "normal":return FontWeight.NORMAL; 
				case "bold": return FontWeight.BOLD;
				default: throw new CSSException("Unsupported font-weight %s", string);
			}
	}

	/* Helper for set)
	 * Remove the url('...') from a css path, if it's present.
	 * Returns: A slice of the original url to avoid creating garbage.*/ 
	private string removeUrl(char[] url)
	{	if (url.length>5 && (url[0..5] == "url('" || url[0..5] == "url(\""))
			return url[5..$-2];
		if (url.length>4 && (url[0..4] == "url(" || url[0..4] == "url("))
			return url[4..$-1];
		return url;
	}

	/*
	 * Helper for set()
	 * Set up to values of any type from an array of tokens, using T's static opCall. */
	private void setEdge(T)(T[] edge, string[] tokens)
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
}




/*
 * Helper for toString() */
private template styleCompare(string name="")
{     const string styleCompare =
    	 `if (`~name~`!=def.`~name~`) result ~= "`~toCSSName(name)~`: "~format("%s", `~name~`);`;
}

/*
 * Convert from a property name to a css name.
 * For example, "fontSize" to "font-size". */
private string toCSSName(char[] name)
{
	string result;
	foreach(c; name)
	{	if (c>64 && c<=90) // if capital letter
			result ~= '-';
		result ~= c;
	}
	return result;
}

