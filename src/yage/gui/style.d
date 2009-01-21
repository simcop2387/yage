/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a> 
 */

module yage.gui.style;

import std.regexp;
import std.string;
import std.stdio;
import std.conv;
import yage.core.color;
import yage.core.vector;
import yage.resource.font;
import yage.resource.manager;
import yage.resource.material;
import yage.resource.texture;
import yage.gui.exceptions;

/**
 * Specifies the style of a Surface.
 * Inspired by the <a href="http://www.w3schools.com/css/css_reference.asp">CSS specification</a>.
 * 
 * This struct is not fully documented. */
struct Style
{	
	// Types
	alias ubyte Unit;	
	
	enum { 
		/**
		 * Enumeration values used to set units for measurements, such as width, padding, etc. */
		PX,			
		PERCENT,	/// ditto

		/**
		 * Enumeration values used to set backgroundRepeat
		 * See: http://livedocs.adobe.com/flash/9.0/UsingFlash/help.html?content=WSd60f23110762d6b883b18f10cb1fe1af6-7db8.html*/
		NONE, 		
		STRETCH, 	/// ditto
		NINESLICE, 	/// ditto
		/*, REPEAT, REPEATX, REPEATY*/ 

		HIDDEN=false,
		VISIBLE=true		
	}
	
	enum TextAlign
	{	LEFT = 0,
		CENTER = 1,
		RIGHT = 2		
	}
	
	// Associative arrays used for translation
	static int[char[]] translate;
	static this()
	{	translate["none"] = NONE;
		translate["stretch"] = STRETCH;
		translate["nineslice"] = NINESLICE;
	}

	struct Edge(int S, T)
	{	static assert (S==2 || S==4);
		static if (S==2)
		{	union
			{	struct { T x, y; };
				T[S] values;
		}	}
		else
		{	union
			{	struct { T top, right, bottom, left; };
				T[S] values;
		}	}
	}
	
	
	
	// Fields
	
	// Background
	GPUTexture backgroundMaterial; 
	Color backgroundColor;
	byte backgroundRepeat = STRETCH;
	union {
		struct {
			float backgroundPositionX=0;
			float backgroundPositionY=0;
		}
		Edge!(2, float) backgroundPosition;
	}
	union {
		struct {
			Unit backgroundPositionXUnit=Style.PX;
			Unit backgroundPositionYUnit=Style.PX;
		}
		Edge!(2, Unit) backgroundPositionUnits;
	}
	
	// Border
	union { 
		struct { 
			float borderWidthTop=0;
			float borderWidthRight=0;
			float borderWidthBottom=0;
			float borderWidthLeft=0; 
		} 
		Edge!(4, float) borderWidth; 
	}
	union { 
		struct { 
			Unit borderWidthTopUnit;
			Unit borderWidthRightUnit;
			Unit borderWidthBottomUnit;
			Unit borderWidthLeftUnit;	
		}
		Edge!(4, Unit) borderWidthUnits;
	}
	union {
		struct {
			Color borderColorTop;
			Color borderColorRight;
			Color borderColorBottom;
			Color borderColorLeft;
		}
		Edge!(4, Color) borderColor;
	}
		

	// Cursor
	Material cursor;
	float cursorSize; // in pixels
		
	// Dimension
	union { 
		struct { 
			float top=float.nan;		/// Distance of an edge from its parent, use float.nan to leave unset.
			float right=float.nan;		/// ditto
			float bottom=float.nan;		/// ditto
			float left=float.nan; 		/// ditto
		} 
		Edge!(4, float) dimension; 	/// Store all four dimension properties in one struct (top, left, bottom, right).
	}
	union { 
		struct { 
			Unit topUnit=Style.PX;
			Unit rightUnit=Style.PX;
			Unit bottomUnit=Style.PX;
			Unit leftUnit=Style.PX;	
		}
		Edge!(4, Unit) dimensionUnits;
	}
	union {
		struct {
			float width=float.nan;
			float height=float.nan;
		}
		Edge!(2, float) size;
	}
	union {
		struct {
			Unit widthUnit=Style.PX;
			Unit heightUnit=Style.PX;
		}
		Edge!(2, Unit) sizeUnits;
	}
	// Font
	Font fontFamily;
	float fontSize = 12;
	Unit fontSizeUnit = Style.PX;
	
	union { // Default color to black opaque.
		uint color_ui = 0xFF000000;
		Color color;
	}
	// Padding
	//float paddingTop, paddingRight, paddingBottom, paddingLeft;
	//Unit paddingTopUnit, paddingRightUnit, paddingBottomUnit, paddingLeftUnit;

	// Text
	TextAlign textAlign = TextAlign.LEFT;
	//byte  textDecoration;
	//float lineHeight;
	//byte  lineHeightUnits;

	// Other
	union {
		bool visible = true; /// Set whether the element is visible. visibility is an alias of visible for CSS compatibility.
		bool visibility;
	}
	int zIndex;
	

	/**
	 * Set properties from a string of text, css style.
	 * TODO: Fix this function so it cleans up its garbage.
	 * Example:
	 * style.set("border: 2px solid black; font-family: arial.ttf; color: white");*/
	void set(char[] style)
	{	
		/*
		 * Populate values and units from string.*/ 
		void parseUnit(char[] string, inout float value, inout Unit value_unit)
		body
		{	value = float.nan;
			if (std.string.rfind(string, "%") != -1)
				value_unit = Style.PERCENT;
			else
				value_unit = Style.PX;
			char[] num = std.regexp.sub(string, "[^0-9]+", "", "g");
			if (num.length) // val=="auto" leaves the value as float.nan
				value = toFloat(num);
			else if (string != "auto") // entire string is already toLower'd
				throw new CSSException("Could not parse CSS value: '%s'", string); // garbage!				
		}
		
		void parseUnits(char[] string, float[] edge, Unit[] edge_units)
		in { assert(edge_units.length >= edge.length); }
		body
		{	char[][] values = std.regexp.split(string, "\\s+");
			
			// Restore to defaults
			edge[0..length] = float.nan;
			edge_units[0..length] = Style.PX;
			
			// Loop through and set what we can parse.
			for (int i=0; i<values.length && i<edge.length; i++)
				parseUnit(values[i], edge[i], edge_units[i]);
			
			// If only specified 2 values and edge has 4 values.		
			if (values.length==2 && edge.length >=4)
			{	edge[2] = edge[0];
				edge[3] = edge[1];
				edge_units[2] = edge_units[0];
				edge_units[3] = edge_units[1];
			}
		}
		
		
		
		/*
		 * Remove the url('...') from a css path, if it's present.
		 * Returns: A slice of the original url to avoid creating garbage.*/ 
		char[] removeUrl(char[] url)
		{	if (url[0..5] == "url('" || url[0..5] == "url(\"")
				return url[5..length-2];
			if (url[0..4] == "url(" || url[0..4] == "url(")
				return url[4..length-1];
			return url;
		}
	

		// Parse and apply the style
		//style = tolower(style); // breaks paths on linux!
		char[][] expressions =  std.regexp.split(style, ";\\s*");
		foreach (exp; expressions)
		{	char[][] tokens = std.regexp.split(exp, ":[ ]*");
			char[] property = tolower(replace(tokens[0], "-", "")); // creates garbage.
			if (!property.length)
				continue;
			
			// TODO: account for parse errors.
			
			switch (property)
			{	/// TODO: Lots more properties
				case "color":				color = Color(tokens[1]); break;
			
				case "backgroundcolor":		backgroundColor = Color(tokens[1]); break;
				case "backgroundrepeat":	backgroundRepeat = translate[tokens[1]]; break;
				case "backgroundmaterial":	backgroundMaterial = ResourceManager.texture(removeUrl(tokens[1])).texture; break;				
			
				case "backgroundpositionx":parseUnits(tokens[1], backgroundPosition.values[0..1], backgroundPositionUnits.values[0..1]); break;
				case "backgroundpositiony":parseUnits(tokens[1], backgroundPosition.values[1..2], backgroundPositionUnits.values[1..2]); break;
				case "backgroundposition": parseUnits(tokens[1], backgroundPosition.values, backgroundPositionUnits.values); break;
				
				//case 
				case "font":		/*todo */ break;
				case "fontsize":	parseUnit(tokens[1], fontSize, fontSizeUnit); break;
				case "fontfamily":	fontFamily = ResourceManager.font(removeUrl(tokens[1])); break;		
			
				case "top":			parseUnits(tokens[1], dimension.values[0..1], dimensionUnits.values[0..1]); break;
				case "right":		parseUnits(tokens[1], dimension.values[1..2], dimensionUnits.values[1..2]); break;
				case "bottom":		parseUnits(tokens[1], dimension.values[2..3], dimensionUnits.values[2..3]); break;
				case "left":		parseUnits(tokens[1], dimension.values[3..4], dimensionUnits.values[3..4]); break;
				case "dimension":	parseUnits(tokens[1], dimension.values, dimensionUnits.values); break;
				case "width":		parseUnits(tokens[1], size.values[0..1], sizeUnits.values[0..1]); break;
				case "height":		parseUnits(tokens[1], size.values[1..2], sizeUnits.values[1..2]); break;
				case "size": 		parseUnits(tokens[1], size.values, sizeUnits.values); break;	
				
				case "zIndex":		zIndex = toInt(tokens[1]); break;
				case "visible":
				case "visibility":	visible = (tokens[1] == "true" || tokens[1] == "visible"); break;
				
				default:
					throw new CSSException("Unsupported CSS Property: '", tokens[0], "'."); // garbage!
			}
			
			delete property;
		}
		//delete style; // can't do because tolower style only someties returns a copy.
		
		
	}
}