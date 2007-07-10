/**
 * 
 */
module yage.gui.style;

import yage.core.vector;
import yage.resource.material;

/**
 * Specifies the style of a Surface.
 * Inspired by the CSS specification (http://www.w3schools.com/css/css_reference.asp).
 * Defined here to keep things well separated. 
 * Colors are represented in Vec4f's
 * Styles that have a top, right, bottom, left (like margin, border) are stored in arrays of length 4.*/
struct Style
{
    enum Units {PX, PERCENT};

    Material backgroundMaterial;
    Vec4f   backgroundColor;

    float[4] borderWidth;
    byte[4]  borderWidthUnits;
    float[4] borderRadius; // used for rounded corners.
    byte[4]  borderRadiusUnits;
    Vec4f[4] borderColor;    

    Material cursor;
    byte display; // block, none, anything else?
    byte position;
    byte visibility;

    //Font  fontFamily;
    float fontSize;
    byte  fontSizeUnits;
    float fontWeight;

    float[4] marginWidth;
    byte[4] marginUnits;

    float[4] paddingWidth;
    byte[4] paddingUnits;

    Vec4f dimension; // top, right, bottom, left
    byte[4] dimensinUnits;
    byte  overflow;
    int   zIndex;
    float height;
    byte  heightUnits;
    float width;
    byte  widthUnits;

    Vec4f color;
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