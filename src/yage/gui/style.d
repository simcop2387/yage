/**
 * 
 */
module yage.gui.style;

import yage.core.color;
import yage.core.vector;
import yage.resource.material;

/**
 * Specifies the style of a Surface.
 * Inspired by the CSS specification (http://www.w3schools.com/css/css_reference.asp).
 * Defined here to keep things well separated. 
 * Styles that have a top, right, bottom, left (like margin, border) are stored in arrays of length 4.*/
struct Style
{
    enum Unit {PX, PERCENT};

    Material backgroundMaterial;
    Color   backgroundColor;
    float[4] backgroundCoordinates;  // Texture coordinates for top, right, bottom, left edges

    float[4] borderWidth;
    Unit[4]  borderWidthUnits;
    Color[4] borderColor;
    Material decoration;		// Overrides radius and color if set
    byte[5]  decorationRepeat;  // top, right, bottom, left, center

    Material cursor;
    bool visible = false;;
    byte position;

    //Font  fontFamily;
    float fontSize;
    byte  fontSizeUnits;
    float fontWeight;

    float[4] padding;
    Unit[4] paddingUnits;

    float[4] dimension; 		// top, right, bottom, left
    byte[4] dimensionUnits;
    float height;
    Unit  heightUnits;
    float width;
    Unit  widthUnits;
    int   zIndex;

    Color color;
    byte  textAlign;
    byte  textDecoration;
    float lineHeight;
    byte  lineHeightUnits;

    /**
     * Set properties from a string of text, css style.
     * Example:
     * style.set("border: 2px solid black; font-family: arial.ttf; color: white");
    void set(char[] style); */
}