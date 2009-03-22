/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.gui.textlayout;

import tango.io.Stdout;
import tango.math.Math;
import tango.text.xml.Document;
import yage.resource.image;
import yage.gui.style;

/**
 * Render text and simple html with styles
 * Authors: eric
 */
class TextLayout
{
	
	/**
	 * Convert a string of primitive html text and render it to an image.
	 * The following tags and styles will be supported:
	 * Params:
	 *     text = The text to render.  
	 *       The following html tags are supported: <a>, <del>, <i>, <span>, <sub>, <sup>, <u>
	 *       The following css is supported via inline style attributes:
	 *         color, font-family, font-size[%|px], font-style[normal|italic|oblique], letter-spacing[%|px], line-height[%|px], 
	 *         text-align: [left|center|right] text-decoration: [none|underline|overline|line-through]
	 *     style = 
	 *     fontSize = font size in pixels (since style may have fontSize in percent)
	 *     width = Available width for rendering text
	 *     height = Available height for rendering text.
	 * Returns:  An RGBA image of width pixels wide and is shorter or equal to height.
	 */
	static Image render(char[] text, Style style, int fontSize, int width, int height)
	{
		Image result;
		
		// Update Text
		// TODO: check style font properties for changes also; font size, family, text align
		if (style.fontFamily)
		{	
			/*
			int j=0;
			text = Regex(`\>[^\<]+\<`).replaceAll(text, (RegExpT!(char) input) {
				return "><span"~input[j]~"/span><";
				j++;
			});
			HtmlNode[] nodes = getNodes(text, style);
			*/
			
			// Fragment stores the grayscale rendering.
			auto fragment = style.fontFamily.render(text, fontSize, fontSize, width, -1, style.textAlign);
			
			
			// Convert to RGBA using style.color.
			result = new Image(4, fragment.getWidth(), fragment.getHeight());
			auto fragment4 = new Image(4, fragment.getWidth(), fragment.getHeight());			
			for (int i=0; i<fragment.getData().length; i++) // loop through pixels
				for (int c=0; c<4; c++) // loop through channels
					fragment4.getData()[i*4+c] = 
						fragment.getData()[i] * cast(ubyte)(style.color.ub[c]/255.0f);
			
			result.overlay(fragment4);
			//result.overlayAndColor(fragment, style.color);
			
			result = result.crop(0, 0, width, min(result.getHeight(), height));
		}
		
		
		return result;
	}
	
	
	/**
	 * Store a string of text, a style associated with it, and a rendered image. */
	struct HtmlNode
	{	char[] text;
		Style style;
		Image[] images; // rendered images for this node.
		
		char[] toString()
		{	return `<span style="`~style.toString()~`">` ~ text ~ "</span>";
		}
	}
	
	/**
	 * This function accepts a string of text that may contain nested html nodes and inline
	 * styles and breaks it a part into a non-nested, in-order array of HtmlNode. */
	static HtmlNode[] getNodes(char[] htmlText, Style style)
	{	auto doc = new Document!(char);
		doc.parse("<span>"~htmlText~"</span>");
		return getNodesHelper(doc.query.nodes[0], style);
	}
	
	/*
	 * Recursive helper function for getNodes.
	 * T is always of type NodeImpl.  This only has to be templated because Tango's NodeImpl is private. */
	private static HtmlNode[] getNodesHelper(T)(T input, Style parentStyle)
	{	HtmlNode[] result;
		
		HtmlNode node;
		
		node.style = parentStyle;
		if (input.query.attribute("style").count)
		{	parentStyle.set(input.query.attribute("style").nodes[0].value);
			node.style = parentStyle;
		}
		if (input.value.length)
		{	node.text = input.value;
			result ~= node;
		}		
		if (input.query.child.nodes.length)
			for (auto child = input.query.child.nodes[0]; child; child=child.nextSibling())
				result ~= getNodesHelper(child, parentStyle);
		return result;
	}
	
}