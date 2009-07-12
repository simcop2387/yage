/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.gui.textlayout;

import tango.io.Stdout;
import tango.math.Math;
import tango.math.IEEE;
import tango.text.convert.Float;
import tango.text.xml.Document;
import tango.text.Regex;
import tango.text.Ascii;
import tango.text.convert.Format;
import tango.text.Util;
import yage.core.color;
import yage.core.math.math;
import yage.core.timer;
import yage.core.types;
import yage.resource.font;
import yage.resource.image;
import yage.gui.style;

/**
 * Render text and simple html with styles to an image. */
class TextLayout
{
	private static const char[] breaks = " *()-+=/\\,.;:|()[]{}<>\r\n"; // breaking characters
	
	private static ubyte[] imageLookaside;
	private static char[] textLookaside;
	private static HtmlNode[] nodeLookaside;
	
	// regular expressions
	private static Regex rxTags;
	static this ()
	{	rxTags = Regex(`\>[^\<]+\<`);
	}
	
	static double lastRenderTime=0;	

	/**
	 * Store a line of rendered letters. */
	private struct Line
	{	Letter[] letters;
		int height;
		
		static Line opCall()
		{	Line result;
			return result;
		}
	}
	
	/*
	 * Store only the inline styles of the style struct, which uses far less memory. 
	 * This struct also stores values in only pixels and never percent. */
	private struct InlineStyle
	{	// Font
		Font fontFamily;
		int fontSize = 12; // default to 12px font size.
		Color color = {r:0, g:0, b:0, a:255};
		Style.FontWeight fontWeight;
		Style.FontStyle fontStyle;
		
		// Text	
		byte textDecoration;
		float lineHeight;
		float letterSpacing;
		
		/*
		 * Create an InlineStyle from a Style. */
		static InlineStyle opCall(Style style)
		{	
			InlineStyle result;
			result.fontFamily = style.fontFamily;
			
			float fontSizePx = style.fontSize.toPx(0); // incorrect, should inherit from parent font size
			result.fontSize = isNaN(fontSizePx) ? cast(int)Style().fontSize.toPx(0): cast(int)fontSizePx;
			
			result.fontWeight = style.fontWeight;
			result.fontStyle = style.fontStyle;
			
			result.color = style.color;
			result.textDecoration = style.textDecoration;
			
			result.letterSpacing = style.letterSpacing.toPx(0);	
			result.lineHeight = style.lineHeight.toPx(result.fontSize);
			
			return result;
		}
		
		/*
		 * Create a Style from this InlineStyle */
		Style toStyle()
		{	Style result;
			result.fontFamily = fontFamily;
			result.fontSize = fontSize;
			result.color = color;
			result.textDecoration = textDecoration;
			result.lineHeight = lineHeight;
			result.letterSpacing = letterSpacing;
			return result;
		}
	}
	
	
	/*
	 * Store a string of text and a style associated with it. */
	private struct HtmlNode
	{	char[] text;
		InlineStyle style;
		bool isBreak;
		
		char[] toString()
		{	return `<span style="`~style.toStyle().toString()~`">` ~ text ~ `</span>`;
		}
	}
	
	// reusable buffers
	private static Line[] lines;
	private static Letter[] letters;
	
	/**
	 * Convert a string of primitive html text and render it to an image.
	 * Note that this is currently not thread-safe, since the reusable buffers above make it non-re-entrant
	 * and also due to the non thread-safety of using Font.
	 * Characters with a bold font-weight are rendered at 1.5x normal width.
	 * Characters with a italic/oblique font-style are rendered skewed.
	 * For ideal rendering, instead use a font-family that has a bold or italic style.
	 * Params:
	 *     text = String of utf-8 encoded html text to render.  
	 *       The following html tags are supported: <a>, <b>, <del>, <i>, <span>, <sub>, <sup>, <u>
	 *       The following css is supported via inline style attributes:
	 *         color, font-family, font-size[%|px], font-style[normal|italic|oblique], font-weight[normal|bold],
	 *         letter-spacing[%|px], line-height[%|px], 
	 *         text-align[left|center|right] text-decoration[none|underline|overline|line-through]
	 *     style = A style with fontSize and lineHeight in terms of pixels
	 *     width = Available width for rendering text
	 *     height = Available height for rendering text.
	 * Returns:  An RGBA image of width pixels wide and is shorter or equal to height.  
	 *     Note that the same buffer is used for each return, so one will overwrite the previous.*/
	static Image render(char[] text, Style style, int width, int height, bool pow2=false)
	{
		Image result;
		//text = .toString(lastRenderTime*1000, 6) ~ "<br/>" ~ text; // temporary profiling

		if (text.length && style.fontFamily)
		{	letters.length = 0;
			lines.length = 0;	
			
			// Get an array of letter structs for the entire text. (1ms)
			scope nodes = getNodes(text, InlineStyle(style));
			
			foreach (ref node; nodes) // ref is req'd so that &node.style points to the real style.
			{	// Aditional text replacement
				node.text = htmlToText(node.text);
				
				foreach (dchar c; node.text) // dchar to iterate over each utf-8 char group
				{	if (node.style.fontFamily)
					{	int h = node.style.fontSize;
						int w = node.style.fontWeight == Style.FontWeight.BOLD ? h*3/2 : h;
						Letter  l= node.style.fontFamily.getLetter(c, w, h); // 1.3ms
						l.extra = &node.style;
						letters ~= l;
			}	}	}
			
			// Build lines
			{	int i;
				while (i<letters.length)
				{	int start=i;
					int x=0, lineHeight=0;
					int last_break=i;
					
					// Loop through as many as we can fit on this line
					while (x<width && i<letters.length)
					{	InlineStyle* istyle = (cast(InlineStyle*)letters[i].extra);
						
						// Get line height (Defaults to fontSize*1.2 if not specified)
						int calculatedLineHeight = cast(int)(isNaN(istyle.lineHeight) ? istyle.fontSize : istyle.lineHeight);
						if (lineHeight < calculatedLineHeight)
							lineHeight = calculatedLineHeight;
						
						// Convert letter to utf-8
						char[4] lookaside;
						char[] utf8 = letters[i].toString(lookaside);
						
						if (i-start==0 && utf8[0] == ' ') // skip spaces at the beginning of a new line.
						{	start++;
							continue;
						}
							
						x+= letters[i].advancex;
						
						if (containsPattern(breaks, utf8)) // store position of last breaking character
							last_break = i;
						if (x<width)
							i++;
						if (i==letters.length) // include the final characters.
							last_break = i;
						
						if (utf8[0] == '\n') // break on line returns.
							break;
					}
					
					// Add a new line
					Line line;
					if (start<last_break)
					{	i = last_break;
						if (i < letters.length && letters[i].letter=='\n')
							i++; // skip line returns
						line.letters = letters[start..last_break]; // slice directly from the letters array to avoid copy allocation
					}
					line.height = lineHeight;
					lines ~= line;
			}	}
			
			
			// Get total height
			int totalHeight;
			foreach (line; lines)
				totalHeight += line.height;
			if (lines.length)
				totalHeight += lines[$-1].height / 3;
			height = min(totalHeight, height);
			
			// Render Image	
			int x, y;
			if (pow2)
				result = new Image(4, nextPow2(width), nextPow2(height), imageLookaside);
			else
				result = new Image(4, width, height, imageLookaside);
			imageLookaside = result.getData();
			foreach (i, line; lines)
			{
				foreach (letter; line.letters)
				{	InlineStyle* istyle = (cast(InlineStyle*)letter.extra);
				
					// Calculate local coordinates
					int baseline = y + line.height;
					int capheight = baseline - istyle.fontSize;
					int midline = ((baseline+capheight)*9)/16;
					int strikeline = midline*3/5 + baseline*2/5;
					int lineWidth = istyle.fontSize/8;
					
					// Overlay the glyph onto the main image
					result.overlayAndColor(letter.image, istyle.color, x+letter.left, baseline-letter.top);
	
					
					// Render underline, overline, and linethrough
					if (istyle.textDecoration == Style.TextDecoration.UNDERLINE)
						for (int h=max(0, baseline); h<min(baseline+lineWidth, height); h++)
							for (int j=x; j<x+letter.advancex; j++) // [above] make underline 1/10th as thick as line-height
								result[j, h] = istyle.color.ub;
					else if (istyle.textDecoration == Style.TextDecoration.OVERLINE)
						for (int h=max(0, capheight); h<min(capheight+lineWidth, height); h++)
							for (int j=x; j<x+letter.advancex; j++)
								result[j, h] = istyle.color.ub;
					else if (istyle.textDecoration == Style.TextDecoration.LINETHROUGH)
						for (int h=max(0, midline); h<min(midline+lineWidth, height); h++)
							for (int j=x; j<x+letter.advancex; j++)
								result[j, h] = istyle.color.ub;
					
					
					x+= letter.advancex;// + istyle.letterSpacing;
					y+= letter.advancey;
				}
				x=0;
				y+= lines[i].height; // add height of the next line.
				if (y>height)
					break;
			}
		}
		
		return result;
	}
	
	
	/*
	 * This function accepts a string of text that may contain nested html nodes and inline
	 * styles and breaks it a part into a non-nested, in-order array of HtmlNode. 
	 * All results of this function are written to the same buffer to avoid extra heap activity,
	 * so subsequent calls will overwrite the result of the previous. */
	private static HtmlNode[] getNodes(char[] htmlText, InlineStyle style)
	{
		htmlText = htmlWhitespace(htmlText);
		
		// .3ms
		// This will be fixed in Tango 0.99.9: http://dsource.org/projects/tango/ticket/1619#comment:1
		int i=0; // [below] ensure every plain text child is wrapped in <span></span> to fix tango's xml parsing.
		htmlText = rxTags.replaceAll(htmlText, (RegExpT!(char) input) {
			return "><span"~input[i]~"/span><";
			i++;
		});
		
		// .05ms
		scope doc = new Document!(char);
		doc.parse(htmlText);
		
		nodeLookaside.length = 0;
		getNodesHelper(doc.query.nodes[0], style); // 0.15 ms
		return nodeLookaside;
	}
	
	/*
	 * Recursive helper function for getNodes.
	 * T is always of type NodeImpl.  This only has to be templated because Tango's NodeImpl is private. 
	 * This populates nodeLookAside at each call to avoid extra heap activity.
	 * Note that one call will overwrite the result of the previous.*/
	private static void getNodesHelper(T)(T input, InlineStyle parentStyle)
	{	
		char[] tagName = toLower(input.name, input.name);
		
		// Set the style from the parent and stle attribute
		HtmlNode node; // our own node class.
		if (input.query.attribute("style").count)
		{	Style temp = parentStyle.toStyle();
			temp.set(input.query.attribute("style").nodes[0].value); // 30ms for temp.set!
			node.style = InlineStyle(temp);
		} else
			node.style = parentStyle;
		
		// Get additional styles
		if (tagName=="u")
			node.style.textDecoration = Style.TextDecoration.UNDERLINE;
		if (tagName=="b")
			node.style.fontWeight = Style.FontWeight.BOLD;
		if (tagName=="i")
			node.style.fontStyle = Style.FontStyle.ITALIC;
		if (tagName=="del" || tagName=="s" || tagName=="strike")
			node.style.textDecoration = Style.TextDecoration.LINETHROUGH;
		
		// Get any text children from the node.
		if (input.value.length)
		{	node.text = input.value;
			nodeLookaside ~= node;
		} else if (tagName=="br")
		{	node.isBreak = true;
			nodeLookaside ~= node;
		}
		
		// Recurse through child nodes.		
		if (input.query.child.nodes.length)
			for (auto child = input.query.child.nodes[0]; child; child=child.next())
				getNodesHelper(child, node.style);
	}
	
	/*
	 * Convert whitespace in html text.
	 * Multiple whitespace characters are reduced to a single one.
	 * <br/> is converted to \n.
	 * Returns:  Each call returns the same buffer, so a second call will overwrite the first result.
	 * Doing this allows no heap activity after the buffer is sized to a large enough size. */ 
	private static char[] htmlWhitespace(inout char[] input)
	{	textLookaside.length = input.length+13;
		textLookaside[0..6] = "<span>";
		
		int r, w=6; // read and write positions
		for (r=0; r<input.length; )
		{	
			// Condense whitespace
			bool space;
			while (r<input.length && (input[r]==' ' || input[r]=='\t' || input[r]=='\r' || input[r]=='\n'))
			{	space = true;
				r++;
			} if (space)
			{	textLookaside[w] = ' ';
				w++;
				continue;
			}
			
			// Replace line returns
			if (r+5 < input.length && input[r..r+5] == "<br/>")
			{	textLookaside[w] = '\n';
				r+= 5;
				w++;
				continue;
			}
			
			// Copy other characters
			textLookaside[w] = input[r];
			r++; w++;
		}
		textLookaside[w..w+7] = "</span>";
		return textLookaside[0..w+7];
	}
	
	/*
	 * For speed, only xml entities are replaced for now (not html entities).
	 * Note that this could avoid heap activity altogether with lookaside buffers.
	 * See: http://en.wikipedia.org/wiki/Character_encodings_in_HTML#XML_character_entity_references */ 
	private static char[] htmlToText(char[] text)
	{	text = text.substitute("&amp;", "&"); // todo: fix garbae created by this function.
		text = text.substitute("&lt;", "<");
		text = text.substitute("&gt;", ">");
		text = text.substitute("&quot;", `"`);
		text = text.substitute("&apos;", "'");
		text = text.substitute("&nbsp;", "\&nbsp;"); // unicode 160: non-breaking space
		return text;
	}
	unittest
	{	char[] test = "<>Hello Goodbye&nbsp; &amp;&quot;&apos;&lt;&gt;";
		char[] result="<>Hello Goodbye\&nbsp; &\"'<>";
		assert (htmlToText(test) == result);
	}
	
}