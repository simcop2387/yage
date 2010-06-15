/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 * 
 * This module is dedicated to my loving wife, Brittany Poggel.
 */
module yage.gui.textlayout;

import tango.core.Exception;
import tango.io.Stdout;
import tango.math.Math;
import tango.math.IEEE;
import tango.text.convert.Float;
import tango.text.xml.Document;
import tango.text.convert.Format;
import tango.text.convert.Utf;
import tango.text.Unicode;
import tango.text.Util;

import derelict.sdl.sdl;

import yage.core.array;
import yage.core.cache;
import yage.core.color;
import yage.core.format;
import yage.core.math.math;
import yage.core.memory;
import yage.core.object2;
import yage.core.types;
import yage.resource.font;
import yage.resource.image;
import yage.resource.manager;
import yage.gui.style;
import yage.gui.exceptions;
import yage.system.log;

/**
 * Render text and simple html with styles to an image. */
struct TextLayout
{
	private static const char[] whitespace = " \t\r\n";
	private static const char[] breaks = " *()-+=/\\,.;:|()[]{}<>\t\r\n"; // breaking characters
	
	private ubyte[] imageLookaside; // TODO: Use Memory.allocate instead?
	
	private char[] text;
	InlineStyle style;
	int width;
	int height;
	int cursorPosition;
	int selectionStart;
	int selectionEnd;
	
	// Previous settings
	/*
	struct Previous
	{	char[] text;
		InlineStyle style;
		int width;
		int height;
		int cursorPosition;
		int selectionStart;
		int selectionEnd;
	}
	Previous previous;
	*/
	
	
	/*
	 * Store a line of rendered letters. */
	private struct Line
	{	Letter[] letters;
		int height;// height of the line, based on either a css line-height or the tallest characters
		int width; // width of the line
		
		static Line opCall()
		{	Line result;
			return result;
		}
	}
	
	private Line[] lines;
	private ArrayBuilder!(Letter) letters;
	private ArrayBuilder!(InlineStyle) styles;	
	
	/**
	 * Update lines and letters data structures from keyboard input
	 * Params:
	 *     key = 
	 *     mod = modifier key.
	 *     unicode = 
	 * Returns: new html text.
	 */
	char[] input(int key, int mod, dchar unicode)
	{
		switch(key) 
		{
			case SDLK_LEFT: cursorPosition--; if (cursorPosition<0) cursorPosition=0; break;
			case SDLK_RIGHT: cursorPosition++; if (cursorPosition>letters.length) cursorPosition=letters.length; break;
			case SDLK_UP: break;
			case SDLK_DOWN: break;
			case SDLK_HOME: break;
			case SDLK_END: break;
			case SDLK_INSERT: break;
			
			case SDLK_BACKSPACE: break;
			case SDLK_DELETE:  break;
			default: break;
			
			// ctrl+a, z, x, c, v
		}
		if (unicode)
		{	Letter l = style.fontFamily.getLetter(unicode, 10, 10);
			letters ~= l;
		}		
		// TODO: rebuild lines from letters.
		
		return toString();
	}
	
	/**
	 * Convert a string of primitive html text and render it to an image.
	 * Note that this is currently not thread-safe, since the reusable buffers above make it non-re-entrant
	 * and also due to the non thread-safety of using Font.
	 * Characters with a bold font-weight are rendered at 1.5x normal width.
	 * Characters with a italic/oblique font-style are rendered skewed.
	 * For ideal rendering, instead use a font-family that has a bold or italic style.
	 * Params:
	 *     text = String of utf-8 encoded html text to render.
	 *       The following html tags are supported:<br> 
	 *       	a, b, br, del, i, span, sub, sup, u <br>
	 *       The following css is supported via inline style attributes: <br>
	 *         color, font-family, font-size[%|px], font-style[normal|italic|oblique], font-weight[normal|bold],
	 *         letter-spacing[%|px], line-height[%|px], 
	 *         text-align[left|center|right] text-decoration[none|underline|overline|line-through]
	 *     style = A style with fontSize and lineHeight in terms of pixels
	 *     width = Available width for rendering text
	 *     height = Available height for rendering text.
	 * Returns:  An RGBA image of width pixels wide and is shorter or equal to height.  
	 *     Note that the same buffer is used for each return, so one call to this function will overwrite a previous result.*/
	Image render(Style style, bool pow2=false)
	{
		Image result;

		if (text.length)
		{	
			// Get total height of all lines
			int totalHeight;
			foreach (line; lines)
				totalHeight += line.height;
			if (lines.length)
				totalHeight += lines[$-1].height / 3; // add 1/3rd of the last line's height for letters w/ danglies.
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
				if (style.textAlign == Style.TextAlign.RIGHT)
					x = width - line.width;
				else if (style.textAlign == Style.TextAlign.CENTER)
					x = (width - line.width) / 2;

				foreach (letter; line.letters)
				{	InlineStyle* istyle = (cast(InlineStyle*)letter.extra);
				
					// Calculate local coordinates
					int baseline = y + line.height;
					int capheight = baseline - istyle.fontSize;
					int midline = ((baseline+capheight)*9)/16;
					int strikeline = midline*3/5 + baseline*2/5;
					int lineWidth = istyle.fontSize/8;
					
					// Overlay the glyph onto the main image
					float skew = istyle.fontStyle == Style.FontStyle.ITALIC ? .33f : 0;
					result.overlayAndColor(letter.image, istyle.color, x+letter.left, baseline-letter.top);
					
					// Render underline, overline, and linethrough
					if (istyle.textDecoration == Style.TextDecoration.UNDERLINE)
						for (int h=max(0, baseline); h<min(baseline+lineWidth, height); h++)
							for (int j=x; j<x+letter.advanceX; j++) // [above] make underline 1/10th as thick as line-height
								result[j, h] = istyle.color.ub;
					else if (istyle.textDecoration == Style.TextDecoration.OVERLINE)
						for (int h=max(0, capheight); h<min(capheight+lineWidth, height); h++)
							for (int j=x; j<x+letter.advanceX; j++)
								result[j, h] = istyle.color.ub;
					else if (istyle.textDecoration == Style.TextDecoration.LINETHROUGH)
						for (int h=max(0, midline); h<min(midline+lineWidth, height); h++)
							for (int j=x; j<x+letter.advanceX; j++)
								result[j, h] = istyle.color.ub;
					
					
					x+= letter.advanceX; // + istyle.letterSpacing;
					y+= letter.advanceY;
				}
				x=0;
				y+= line.height; // add height of the next line.
				if (y>height)
					break;
			}
		}		
		return result;
	}
	
	
	/**
	 * Reverse the normal function of TextLayout and convert letters[] back to a string of html text.
	 * The text may use different tags (since some information is lost) 
	 * but will be functionally the same. 
	 * TODO: Move this to lettersToHtml(), since it's the opposite of htmlToLetters()	 
	 */
	char[] toString()
	{
		char[] result = "<span>";
		InlineStyle style = this.style;		
		InlineStyle currentStyle = style; // style of the previous letter
		
		foreach(Letter l; letters)
		{
			InlineStyle* newStyle = cast(InlineStyle*) l.extra;
			if (currentStyle != *newStyle) // if style has changed since last letter
			{	
				char[][] styleString;			
				
				// TODO: Would it be better to create arrays to group sequential letters of the same style?
				// then we could make a single xml node to contain those that have similar styles.
				// If nothing else, the first version of this function could just return unformatted text.
				// Should text be stored lazily so we don't have to recreate this all on every keypress?
				
				// Only print styles that don't match the Surface's style
				if (style.fontFamily && style.fontFamily != newStyle.fontFamily)
					styleString ~= swritef(`font-family: url('%s')`, newStyle.fontFamily);
				if (dword(style.fontSize) != dword(newStyle.fontSize)) // BUG: converts % font size to px.
					styleString ~= swritef(`font-size: %spx`, newStyle.fontSize);
				if (style.color != newStyle.color)
					styleString ~= swritef(`color: %spx`, newStyle.color);
				if (style.fontWeight != newStyle.fontWeight)
					styleString ~= swritef(`font-weight: %s`, Style.enumToString(newStyle.fontWeight));
				if (style.fontStyle != newStyle.fontStyle)
					styleString ~= swritef(`font-style: %s`, Style.enumToString(newStyle.fontStyle));
				if (style.textDecoration != newStyle.textDecoration) 
					styleString ~= swritef(`text-decoration: %s`, Style.enumToString(newStyle.textDecoration));
				if (dword(style.lineHeight) != dword(newStyle.lineHeight))
					styleString ~= swritef(`lineHeight: %spx`, newStyle.lineHeight);
				if (dword(style.letterSpacing) != dword(newStyle.letterSpacing)) 
					styleString ~= swritef(`letterSpacing: %spx`, newStyle.letterSpacing);				
				
				result ~= swritef(`</span><span style="%s">`, join(styleString, "; "));
				currentStyle = *newStyle;
			}
			result ~= l.toString();
		}
		
		return result ~ "</span>";
	}

	/**
	 * Replace the text with new text, rebuilding the internal lines and letters data structures.
	 * This is unlike input(), which modifies the text based on a single keystroke.
	 * Params:
	 *     text = 
	 *     style = Root style of the text.  Inline styles override this.
	 *     width = 
	 *     height = 
	 * Returns: True if the text will need to be re-rendered, false otherwise.
	 * TODO: Should this be a constructor to maintain RAII?  Doing so will cause more allocations of letters and lines!
	 */
	bool update(char[] text, Style style, int width, int height)
	{
		InlineStyle istyle = InlineStyle(style);
		
		// If text has changed
		//bool newLetters = text != (*this).text || istyle != (*this).style;
		bool newLetters = text != this.text || istyle != this.style;
		if (newLetters)
		{	
			// Update the arrays of letters and styles
			letters.length = 0;			
			styles.length = 0;
			HtmlParser.htmlToLetters(text, style, letters, styles);
			
			this.text = text;
			this.style = istyle;
		}
		
		// If text or dimensions have changed
		if (newLetters || width != this.width || height != this.height)
		{				
			this.width = width;
			this.height = height;			
			lines.length = 0;
			
			// Build lines from letters
			// TODO: Instead of having this here, create lettersToLines function (to Match HtmlParse.htmlToLetters())
			int i;
			while (i<letters.length)
			{	int start=i;
				int x=0, lineHeight=0;
				int last_break=i;
				
				// Loop through as many as we can fit on this line
				while (x<width && i<letters.length)
				{	InlineStyle* letterStyle = (cast(InlineStyle*)letters[i].extra);
					
					// Get line height (Defaults to fontSize*1.2 if not specified)
					int calculatedLineHeight = cast(int)(isNaN(letterStyle.lineHeight) ? letterStyle.fontSize : letterStyle.lineHeight);
					if (lineHeight < calculatedLineHeight)
						lineHeight = calculatedLineHeight;

					x+= letters[i].advanceX;
					
					// Convert letter to utf-8 for comparison. TODO: This won't be necessary if we store breaks as utf-32.
					char[4] lookaside;
					char[] utf8 = letters[i].toString(lookaside);
					
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
				if (start<last_break) // don't count spaces at the end of the line.
				{	i = last_break;
					if (i < letters.length && letters[i].letter=='\n')
						i++; // skip line returns
					assert(last_break <= letters.length);
					line.letters = letters.data[start..last_break]; // slice directly from the letters array to avoid copy allocation
				}
				
				// trim line
				int firstChar, lastChar=line.letters.length-1;
				while (firstChar < line.letters.length && whitespace.contains(cast(char)line.letters[firstChar].letter))
					firstChar++;
				while (lastChar>=0 && whitespace.contains(cast(char)line.letters[lastChar].letter))
					lastChar--;
				line.letters = line.letters[firstChar..lastChar+1];
					
				// Calculate line width
				foreach (letter; line.letters)
					line.width += letter.advanceX;
				
				line.height = lineHeight;
				lines ~= line;
			}
			return true;
		}
		return false;
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
	Style.TextDecoration textDecoration;
	float lineHeight;
	float letterSpacing;
	
	/*
	 * Create an InlineStyle from a Style. */
	static InlineStyle opCall(Style style)
	{	
		InlineStyle result;
		result.fontFamily = style.fontFamily ? style.fontFamily : ResourceManager.getDefaultFont();
		
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


private struct HtmlParser
{
	/*
	 * Convert a string of html text to an array of Letter
	 * Each letter's extra property will point to an InlineStyle for that letter.
	 * Params:
	 *     htmlText = Input text
	 *     style = Base style
	 *     letters = Letter results will be appended to this array 
	 *     styles = Style results will be appended to this array.
	 * Returns:
	 */
	static void htmlToLetters(char[] htmlText, Style style, inout ArrayBuilder!(Letter) letters, inout ArrayBuilder!(InlineStyle) styles)
	{
		char[] lookaside = Memory.allocate!(char)(htmlText.length+13); // +13 for <span></span> that surrounds it
		htmlText = htmlToAscii(htmlText, lookaside);
		
		// Convert xml document to an array of zero-deth nodes.
		scope doc = new Document!(char);
		try {
			doc.parse(htmlText);
		} catch (AssertException e)
		{	throw new XHTMLException("Unable to parse xhtml:  {}", htmlText);
		} finally {
			Memory.free(lookaside);
		}

		htmlNodeToLetters(doc.query.nodes[0], InlineStyle(style), letters, styles);
	}
		
	/*
	 * Recursive helper function for htmlToLetters.
	 * Params:
	 *     input = Current xml entity.  T is always of type NodeImpl, which is req'd because Tango's NodeImpl is private. 
	 *     parentStyle =
	 *     letters = 
	 *     style s= */
	private static void htmlNodeToLetters(T)(T input, InlineStyle parentStyle, 
		inout ArrayBuilder!(Letter) letters, inout ArrayBuilder!(InlineStyle) styles)
	{	
		// Apply additional styles based on a tag name.
		void styleByTagName(inout InlineStyle style, char[] tagName)
		{	if (tagName=="u")
				style.textDecoration = Style.TextDecoration.UNDERLINE;
			if (tagName=="b")
				style.fontWeight = Style.FontWeight.BOLD;
			if (tagName=="i")
				style.fontStyle = Style.FontStyle.ITALIC;
			if (tagName=="del" || tagName=="s" || tagName=="strike")
				style.textDecoration = Style.TextDecoration.LINETHROUGH;
		}
		
		// Set the style from the parent and style attribute
		InlineStyle style;
		char[] tagName = toLower(input.name, input.name);
		if (input.query.attribute("style").count) // if has style attribute
		{	styleByTagName(parentStyle, tagName);
			Style temp = parentStyle.toStyle(); // convert to Style so we can call .set on it.			
			temp.set(input.query.attribute("style").nodes[0].value);
			style = InlineStyle(temp);
		} else
		{	style = parentStyle;
			styleByTagName(style, tagName);
		}
		
		// Get any text from in the node.
		styles ~= style;
		if (input.value.length)
		{	char[] text = htmlEntityDecode(input.value);
			foreach (dchar c; text) // dchar to iterate over each utf-8 char group
			{	if (style.fontFamily)
				{	int size = style.fontSize;
					bool bold = style.fontWeight == Style.FontWeight.BOLD;
					bool italic = style.fontStyle == Style.FontStyle.ITALIC;
					Letter l = style.fontFamily.getLetter(c, size, size, bold, italic);
					l.extra = &styles.data[$-1];
					letters ~= l;
			}	}
			
		}
		
		// Recurse through child nodes.		
		if (input.query.child.nodes.length)
			for (auto child = input.query.child.nodes[0]; child; child=child.next())
				htmlNodeToLetters(child, style, letters, styles);
	}
	
	/*
	 * TODO: Move the <span></span> adding part outside of this function, and give it a better name.
	 * Condense whitespace in html text.
	 * Multiple whitespace characters are reduced to a single one.
	 * <br/> is converted to \n. */ 
	private static char[] htmlToAscii(char[] input, char[] lookaside)
	{	lookaside.length = input.length+13;
		lookaside[0..6] = "<span>";
		
		int r, w=6; // read and write positions
		for (r=0; r<input.length; )
		{	
			// Condense whitespace
			bool space;
			while (r<input.length && (input[r]==' ' || input[r]=='\t' || input[r]=='\r' || input[r]=='\n'))
			{	space = true;
				r++;
			} if (space)
			{	lookaside[w] = ' ';
				w++;
				continue;
			}
			
			// Replace line returns
			if (r+5 < input.length && input[r..r+5] == "<br/>") // TODO: What about <br /> and other forms?
			{	lookaside[w] = '\n';
				r+= 5;
				w++;
				continue;
			}
			
			// Copy other characters
			lookaside[w] = input[r];
			r++; w++;
		}
		lookaside[w..w+7] = "</span>";
		return lookaside[0..w+7];
	}
	
	/*
	 * For speed, only xml entities are replaced for now (not html entities).
	 * Note that this could avoid heap activity altogether with lookaside buffers.
	 * See: http://en.wikipedia.org/wiki/Character_encodings_in_HTML#XML_character_entity_references */ 
	private static char[] htmlEntityDecode(char[] text)
	{	text = text.substitute("&amp;", "&"); // TODO: fix garbage created by this function.
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
		assert (htmlEntityDecode(test) == result);
	}
}