/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 * 
 * This module is dedicated to my loving wife, Brittany Poggel.
 */
module yage.gui.textblock;

import tango.core.Exception;
import tango.math.Math;
import tango.math.IEEE;
import tango.text.convert.Float;
import tango.text.xml.Document;
import tango.text.convert.Utf;
import tango.text.Unicode;
import tango.text.Util;
alias std.array.join join;

import derelict.sdl2.sdl;

import yage.core.array;
import yage.core.cache;
import yage.core.color;
import yage.core.math.math;
import yage.core.math.vector;
import yage.core.memory;
import yage.core.object2;
import yage.core.types;
import yage.resource.font;
import yage.resource.image;
import yage.resource.manager;
import yage.gui.style;
import yage.gui.exceptions;
import yage.system.log;

///
struct TextCursor
{	ulong position; ///
	ulong selectionStart; ///
	ulong selectionEnd; ///
}

/**
 * Render text and simple html with styles to an image.
 * TextBlock has two modes of input:  setHtml() and the input() function that receives keypresses.
 * This class is used internally by the engine.  In most cases it shouldn't need to be called externally. */
struct TextBlock
{
	private static const dstring whitespace = " \t\r\n"d;
	private static const dstring breaks = " *()-+=/\\,.;:|()[]{}<>\t\r\n"d; // breaking characters
	
	private ubyte[] imageLookaside; // TODO: Have the lookaside passed into Render
	
	private string html;
	private bool htmlDirty = true;		// html has changed, letters may be out of date
	private bool lettersDirty = false;	// letters have chagned via input, html may be out of date
	package InlineStyle style; // base style of entire text block
	private Style.TextAlign alignment;
	private int width;
	private int height;
	
	private ArrayBuilder!(Line) lines;
	private ArrayBuilder!(Letter) letters;
	private ArrayBuilder!(InlineStyle) styles;	// Styles pointed to by the letters
		
	/// Functions for converting between line/letter/cursor space and x/y position.
	struct {
		
		/**
		 * Get the xy pixel position of a cursor position. */
		Vec2i cursorToXy(ulong position)
		{
			// Special case
			if (!lines.length)
				return Vec2i(Line.getOffset(0, width, alignment), 0);
			
			// Get y value
			Vec2i result;
			ulong line = cursorToLine(position); // modifies position
			for (int i=0; i<line; i++)
				result.y += lines[i].height;
			
			// Get x value
			ulong last = cast(ulong) min(lines[line].letters.length, position);
			for (ulong i=0; i<last; i++)
				result.x += lines[line].letters[i].advanceX;
			result.x += Line.getOffset(lines[line].width, width, alignment);
			return result;
		}
		
		/**
		 * Get the cursor position from an xy pixel position. */
		ulong xyToCursor(Vec2i xy)
		{	if (!lines.length)
				return 0;
			
			// Calculate line
			int line, y;
			while(true)
			{	y += lines[line].height;
				if (line>=lines.length-1 || y >= xy.y)
					break;
				line++;
			}
			
			// Take alignment into account
			int lineWidth = lines.length ? lines[line].width : 0;
			xy.x -= Line.getOffset(lineWidth, width, alignment);
			
			// Calculate position on line.
			int position;
			for (; position<lines[line].letters.length && 0 < xy.x; position++)
				xy.x -= lines[line].letters[position].advanceX;
			
			return lineToCursor(line, position);
		}
		
		/**
		 * Convert an absolute cursor position to a line/position pair.
		 * Params:
		 *     position = Character position from the beginning of the TextBlock
		 *     After the function executes, this will be the position on the line returned.
		 * Returns:  The line number.  If position is after the last line, 
		 *     then the number of the last line is returned and position is an offset from this.*/
		ulong cursorToLine(ref ulong position)
		{	if (!lines.length) // special case if no lines
				return position = 0;
			
			foreach (i, line; lines.data)
			{	if (position < line.letters.length)
					return i;
				position -= line.letters.length;
			}
			position += lines.data[$-1].letters.length;
			return lines.length-1;
		}
		
		/**
		 * Convert a cursor line/position pair to an absolute position.
		 * Params:
		 *     line = 
		 *     position = Position from the beginning of the line, may be negative or exceed the line length.
		 * Returns: The absolute position of the cursor from the beginning of the text block. */
		ulong lineToCursor(ulong line, int position)
		{	ulong m = min(line, lines.length);
			for (int i=0; i<m; i++)
				position += lines[i].letters.length;
			return position;
		}
	}
	
	/**
	 * Reverse the normal function of TextLayout and convert letters[] back to a string of html text.
	 * The text may use different tags than the original html, (since some information is lost) 
	 * but will be functionally the same.  */
	public string getHtml()
	{
		if (!lettersDirty)
			return html;
		
		// If the user has typed text, regenerate html from scratch
		html = "<span>";
		InlineStyle style = this.style;		
		InlineStyle currentStyle = style; // style of the previous letter
		
		foreach(i, l; letters.data)
		{
			InlineStyle* newStyle = cast(InlineStyle*) l.extra;
			if (currentStyle != *newStyle) // if style has changed since last letter
			{	
				string[] styleString;			
				
				// TODO: Would it be better to create arrays to group sequential letters of the same style?
				// then we could make a single xml node to contain those that have similar styles.
				// If nothing else, the first version of this function could just return unformatted text.
				// Should text be stored lazily so we don't have to recreate this all on every keypress?
				
				// Only print styles that don't match the Surface's style
				if (style.fontFamily && style.fontFamily != newStyle.fontFamily)
					styleString ~= std.string.format(`font-family: url('%s')`, newStyle.fontFamily);
				if (dword(style.fontSize) != dword(newStyle.fontSize))
					styleString ~= std.string.format(`font-size: %spx`, newStyle.fontSize);
				if (style.color != newStyle.color)
					styleString ~= std.string.format(`color: %spx`, newStyle.color);
				if (style.fontWeight != newStyle.fontWeight)
					styleString ~= std.string.format(`font-weight: %s`, Style.enumToString(newStyle.fontWeight));
				if (style.fontStyle != newStyle.fontStyle)
					styleString ~= std.string.format(`font-style: %s`, Style.enumToString(newStyle.fontStyle));
				if (style.textDecoration != newStyle.textDecoration) 
					styleString ~= std.string.format(`text-decoration: %s`, Style.enumToString(newStyle.textDecoration));
				if (dword(style.lineHeight) != dword(newStyle.lineHeight))
					styleString ~= std.string.format(`lineHeight: %spx`, newStyle.lineHeight);
				if (dword(style.letterSpacing) != dword(newStyle.letterSpacing)) 
					styleString ~= std.string.format(`letterSpacing: %spx`, newStyle.letterSpacing);				
				
				html ~= std.string.format(`</span><span style="%s">`, join(styleString, "; "));
				currentStyle = *newStyle;
			}
			switch (l.letter)
			{	case '>': html ~= "\&gt;"; break;
				case '<': html ~= "\&lt;"; break;
				case '&': html ~= "\&amp;"; break;
				case '\n': html ~= "<br/>"; break;
				case ' ': 
					if (i>0 && letters[i-1].letter ==' ')
					{	html ~= "\&nbsp;"; // encode multiple spaces as " &nbsp;" 
						break;
					} // fall through:
                                        goto default;
				default:
					html ~= l.toString();
			}
		}
		 html ~= "</span>";
		 lettersDirty = false;
		 
		return html;
	}
	
	/**
	 * Update lines and letters data structures from keyboard input
	 * Params:
	 *     key = SDL key code constant
	 *     mod = modifier key.
	 *     unicode = Unicode value of the pressed key.
	 *     cursor = The Surface's TextCursor. */
	void input(int key, int mod, dchar unicode, ref TextCursor cursor)
	{			
		// If the html has changed we need to update the lines before continuing.
		if (htmlDirty)
		{	letters.length = 0;			
			styles.length = 0;
			HtmlParser.htmlToLetters(html.dup, style, letters, styles);	
			lines = lettersToLines(letters.data, width, lines);
			htmlDirty = false;
		}
		assert(cursor.position <= letters.length);
		static int xPosition; // save the cursor's x position when moving from one line to the next.
		
		// Position cursor
		ulong linePosition = cursor.position;
		ulong currentLine = cursorToLine(linePosition);
		if (key != SDLK_UP && key != SDLK_DOWN)
			xPosition = 0; // clear stored x cursor position		
		switch(key) 
		{	
			// Positioning keys
			case SDLK_LEFT: 
				if (cursor.position>0) 
					cursor.position--; 				
				break;
			case SDLK_RIGHT: 
				if (cursor.position<letters.length) 
					cursor.position++; 
				break;
			case SDLK_UP: 
				if (currentLine > 0) // [below] get the x position on the current line
				{	Line* newLine = lines[currentLine-1];
					int i;
					int x = xPosition = xPosition ? xPosition : cursorToXy(cursor.position).x;
					x -= Line.getOffset(newLine.width, width, alignment);
					for (; i<newLine.letters.length && x>=0; i++)
						x-= newLine.letters[i].advanceX; // find the cursor position for the previous x position
					cursor.position = lineToCursor(currentLine-1, max(i-1, 0));
				}
				break;
			case SDLK_DOWN: 
				if (currentLine < (cast(int)lines.length)-1)
				{	Line* newLine = lines[currentLine+1];
					int i;
					int x = xPosition = xPosition ? xPosition : cursorToXy(cursor.position).x;	
					x -= Line.getOffset(newLine.width, width, alignment);
					for (; i<newLine.letters.length && x>=0; i++)
						x-= newLine.letters[i].advanceX;
					//if (currentLine <lines.length-1)
					//	i--; // if not the last line, go back one before the character that causes the new line.
					cursor.position = lineToCursor(currentLine+1, max(i-1, 0));
				}
				break;
			case SDLK_HOME:
				cursor.position -= linePosition;
				break;
			case SDLK_END:
				if (lines.length)
				{	auto letters = lines[currentLine].letters;
					long newPosition = (cast(long)letters.length) - cast(long)linePosition;
					if (currentLine != lines.length-1) 
						newPosition--; // if not the last line, go back one before the character that causes the new line.
					cursor.position += newPosition;
				}
				break;
			
			// Editing Keys
			case SDLK_INSERT: break;			
			case SDLK_BACKSPACE: 
				if (cursor.position > 0)
				{	letters.splice(cursor.position-1, 1);
					cursor.position--;
					lettersDirty = true;
				}			
				break;
			case SDLK_DELETE:  
				if (cursor.position < letters.length)
				{	letters.splice(cursor.position, 1);
					lettersDirty = true;
				}
				break;
			// New letters
			default:				
				if (unicode)
				{	
					if (unicode=='\r')
						unicode='\n';
					
					// Get the style to use for a new letter
					InlineStyle *style;
					if (cursor.position > 0) // get style from previous letter
						style = cast(InlineStyle*)letters[cursor.position-1].extra;
					else if (letters.length && cursor.position < letters.length-1) // get style from next letter
						style = cast(InlineStyle*)letters[cursor.position].extra;
					else // get base style of the TextBlock.
						style = &this.style;
				
					Letter l = style.fontFamily.getLetter(unicode, style.fontSize);
					l.extra = style;
					letters.splice(cursor.position, 0, l);
					cursor.position++;
					lettersDirty = true;
				}
			break;
			
			// TODO: tabs, selection, ctrl+a/z/x/c/v
		}
		
		if (lettersDirty)
			lines = lettersToLines(letters.data, width, lines);
	}
	
	/**
	 * Convert a string of primitive html text and render it to an image.
	 * Note that this is currently not thread-safe, since the reusable buffers above make it non-re-entrant
	 * and also due to the non thread-safety of using Font.
	 * Characters with a bold font-weight are rendered at 1.5x normal width.
	 * Characters with a italic/oblique font-style are rendered skewed.
	 * For ideal rendering, instead use a font-family that has a bold or italic style.
	 * Params:
	 *     pow2 = Render an image with dimensions that are a power of 2 (useful for older graphics cards)
	 *     cursor = Render this text cursor if not null.
	 * Returns:  An RGBA image of width pixels wide and is shorter or equal to height.  
	 *     Note that the same buffer is used for each return, so one call to this function will overwrite a previous result.*/
	Image render(bool pow2=false, TextCursor* cursor=null)
	{
		Image result;

		if (html.length || cursor)
		{	
			// Get total height of all lines
			int totalHeight;
			foreach (line; lines)
				totalHeight += line.height;
			if (lines.length)
				totalHeight += lines.data[$-1].height / 3; // add 1/3rd of the last line's height for letters w/ danglies.
			height = min(totalHeight, height);
			
			// Render Image	
			int x, y;
			imageLookaside[0..$] = 0; // clear
			if (pow2)
				result = new Image(4, nextPow2(width), nextPow2(height), imageLookaside);
			else
				result = new Image(4, width, height, imageLookaside);
			Image resultExact = new Image(4, result.getWidth(), height, result.data); // Points to same image data, but is exact height to ensure letters are cropped.
			imageLookaside = result.getData();
			foreach (i, line; lines.data)
			{
				x = Line.getOffset(line.width, width, alignment);

				foreach (letter; line.letters)
				{	
					if (letter.letter < 32)
						continue; // skip non-printable letters.
					
					InlineStyle* istyle = (cast(InlineStyle*)letter.extra);
				
					// Calculate local coordinates
					int baseline = y + line.height;
					int capheight = baseline - istyle.fontSize;
					int midline = ((baseline+capheight)*9)/16;
					int strikeline = midline*3/5 + baseline*2/5;
					int lineWidth = istyle.fontSize/8;
					
					// Overlay the glyph onto the main image
					float skew = istyle.fontStyle == Style.FontStyle.ITALIC ? .33f : 0;
					resultExact.overlayAndColor(letter.image, istyle.color, x+letter.left, baseline-letter.top);
					
					// Render underline, overline, and line-through
					if (istyle.textDecoration == Style.TextDecoration.UNDERLINE)
						for (int h=max(0, baseline); h<min(baseline+lineWidth, height); h++)
							for (int w=x; w<min(x+letter.advanceX, width); w++) // [above] make underline 1/10th as thick as line-height
								result[w, h] = istyle.color.ub;
					else if (istyle.textDecoration == Style.TextDecoration.OVERLINE)
						for (int h=max(0, capheight); h<min(capheight+lineWidth, height); h++)
							for (int w=x; w<min(x+letter.advanceX, width); w++)
								result[w, h] = istyle.color.ub;
					else if (istyle.textDecoration == Style.TextDecoration.LINETHROUGH)
						for (int h=max(0, midline); h<min(midline+lineWidth, height); h++)
							for (int w=x; w<min(x+letter.advanceX, width); w++)
								result[w, h] = istyle.color.ub;
					
					x+= letter.advanceX; // + istyle.letterSpacing;
					y+= letter.advanceY;
				}
				x=0;
				y+= line.height; // add height of the next line.
				if (y>height)
					break;
			}
			
			// Draw cursor
			if (cursor)
			{	Vec2i xy = cursorToXy(cursor.position);
				int lineHeight = cast(int)style.lineHeight;
				if (letters.length)
				{	ulong position = cursor.position; // copy to prevent ref modification
					ulong line = min(cursorToLine(position), lines.length-1);
					lineHeight = lines[line].height;
				}
				
				int hmin = max(0, xy.y), hmax = min(lineHeight+xy.y, height);
				int wmin = max(0, xy.x), wmax = min(xy.x+1, width);
				for (int h=hmin; h<hmax; h++)
					for (int w=wmin; w<wmax; w++)
						result[w, h] = style.color.ub;
			}
		}
		
		return result;
	}
	
	/**
	 * Set the contents of the Textblock with html.
	 * Params:
	 *     html = String of utf-8 encoded html text to render.
	 *       The following html tags are supported:<br> 
	 *       	a, b, br, del, i, span, sub, sup, u <br>
	 *       The following css is supported via inline style attributes: <br>
	 *         color, font-family, font-size[%|px], font-style[normal|italic|oblique], font-weight[normal|bold],
	 *         letter-spacing[%|px], line-height[%|px], 
	 *         text-align[left|center|right] text-decoration[none|underline|overline|line-through] */
	void setHtml(string html)
	{	this.html = html;
		htmlDirty = true;
		lettersDirty = false;
	}

	/**
	 * Replace the text with new text, rebuilding the internal lines and letters data structures.
	 * This is unlike input(), which modifies the text based on a single keystroke.
	 * Params:
	 *     style = A style with fontSize and lineHeight in terms of pixels
	 *     width = Available width for rendering text
	 *     height = Available height for rendering text.
	 * Returns: True if the text will need to be re-rendered, false otherwise.
	 * TODO: Should this be a constructor to maintain RAII? */
	bool update(Style style, int width, int height)
	{
		InlineStyle istyle = InlineStyle(style);
		alignment = style.textAlign;
				
		 // Reparse the arrays of letters and styles from the html
		bool newLetters = htmlDirty || istyle != this.style;
		if (newLetters)
		{	letters.length = 0;
			styles.length = 0;
			HtmlParser.htmlToLetters(html.dup, istyle, letters, styles);
			htmlDirty = false;
		}
		
		this.style = istyle;
		
		// If text or dimensions have changed
		if (lettersDirty || newLetters || width != this.width || height != this.height)
		{	this.width = width;
			this.height = height;			
			lines = lettersToLines(letters.data, width, lines);
			return true;
		}
		
		return false;
	}
	
	/*
	 * Params:
	 *     letters = 
	 *     width = 
	 *     lines = Provide an existing ArrayBuilder to fill--allows for fewer allocations */
	private static ArrayBuilder!(Line) lettersToLines(Letter[] letters, int width, ArrayBuilder!(Line) lines=ArrayBuilder!(Line)())
	{
		lines.length = 0;
		
		// Build lines from letters
		// TODO: Instead of having this here, create lettersToLines function (to Match HtmlParse.htmlToLetters())
		int i, lineEnd;
		while (i<letters.length)
		{	int lineStart = i = lineEnd;
			int x=0, lineHeight=0;
			Line line;
			
			// Skip beginning spaces unless they are on a line started from a line return.
			if (i>0 && letters[i-1].letter != '\n' && letters[i].letter == ' ')
			{	while (i<letters.length && letters[i].letter == ' ')
					i++;
				lineStart = lineEnd = i;
			}
			
			// Loop through as many as we can fit on this line
			// and populate lineStart and lineEnd
			while (i<letters.length)
			{	
				// Get line height (Defaults to fontSize if not specified)
				// TODO: Don't change lineHeight if it's already specified.
				InlineStyle* letterStyle = (cast(InlineStyle*)letters[i].extra);
				if (lineHeight < letterStyle.fontSize)
					lineHeight = letterStyle.fontSize;
	
				dchar letter = letters[i].letter;
				dchar letterBefore = i>0 ? letters[i-1].letter : letter;
				bool letterCanBreak = contains(breaks, letterBefore);
	
				// Store position of last breakable character
				if (letterCanBreak) 
					lineEnd = i;
				
				
				//  Store position of last breakable character
				if (letterCanBreak) 
					lineEnd = i;
				
				//line.xOffsets.append(x);
				x+= letters[i].advanceX; // + style.letterSpacing;
				//if (!whitespace.contains(letterBefore) && whitespace.contains(letter))
				//	x+= style.wordSpacing * fontScale;

				// Time to go to the next line
				if (letter == '\n' || (x >= width && i > lineStart))
				{	if (letter == '\n') // If line return
						lineEnd = i+1;
					else if (lineEnd == lineStart) // if word is too long to fit on one line.
						lineEnd = i;
					break;
				} else if (i+1==letters.length) // include the final characters.
					lineEnd = i+1;

				i++;				
			}
			
			// Add a new line		
			if (lineStart < lineEnd) // if line has characters
			{	assert(lineEnd <= letters.length);
				line.letters = letters[lineStart..lineEnd];
				//line.xOffsets.resize(lineEnd);
				
				//if (line.letters[$-1].letter == '\n')
				//	line.letters.length = line.letters.length-1;

				// Calculate line.width
				ulong lastLetter = line.letters.length-1;
				while (lastLetter >=0 && whitespace.contains(line.letters[lastLetter].letter))
					lastLetter--; // trim whitespace from end
				
				//Style style = *styles.at(lastLetter);
				//style.size *= fontScale;
				//Letter* letter = ResourceManager::getLetter(text.at(lastLetter), &style);
				//line.width = line.xOffsets.at(lastLetter) + letter->left + letter->advanceX;
				for (int j=0; j<=lastLetter; j++)
					line.width += line.letters[j].advanceX;
			}

			line.height = lineHeight;
			lines ~= line;
		}

		return lines;
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
	float letterSpacing; // not supported yet
	
	/*
	 * Create an InlineStyle from a Style. */
	static InlineStyle opCall(Style style)
	{	
		InlineStyle result;
		result.fontFamily = style.getFont();
		
		float fontSizePx = style.fontSize.toPx(0); // incorrect, should inherit from parent font size
		result.fontSize = isNaN(fontSizePx) ? cast(int)Style().fontSize.toPx(0): cast(int)fontSizePx;
		
		result.fontWeight = style.fontWeight;
		result.fontStyle = style.fontStyle;
		
		// This should not be needed.  The style should get its inherited color before this is called.
		// Oddly, it wasn't needed until I changed
		// string fontFamily; to
		// string fontFamily = ResourceManager.DEFAULT_FONT; in Style.  These should be unrelated!  
		if (!style.color.isNull)
			result.color = (style.color.get());
		
		result.textDecoration = style.textDecoration;
		
		result.letterSpacing = style.letterSpacing.toPx(0);
		result.lineHeight = style.lineHeight.toPx(result.fontSize);
		
		return result;
	}
	
	/*
	 * Create a Style from this InlineStyle */
	Style toStyle()
	{	Style result;
		result.fontFamily = fontFamily.toString();
		result.fontSize = fontSize;
		result.color = color;
		result.textDecoration = textDecoration;
		result.lineHeight = lineHeight;
		result.letterSpacing = letterSpacing;
		return result;
	}
}

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
	
	static int getOffset(int lineWidth, int width, Style.TextAlign align_)
	{	if (align_ == Style.TextAlign.LEFT)
			return 0;
		if (align_ == Style.TextAlign.CENTER)
			return (width - lineWidth) / 2;
		return width - lineWidth; // TextAlign.RIGHT
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
	static void htmlToLetters(string htmlText, InlineStyle style, ref ArrayBuilder!(Letter) letters, ref ArrayBuilder!(InlineStyle) styles)
	{
		char[] lookaside = Memory.allocate!(char)(htmlText.length+13); // +13 for <span></span> that surrounds it
		htmlText = htmlToAscii(htmlText.dup, lookaside.dup).dup;
		
		// Convert xml document to an array of zero-deth nodes.
		auto doc = new Document!(char);
		try {
			doc.parse(htmlText);
		} catch (Exception e)
		{	throw new XHTMLException("Unable to parse xhtml:  {}", htmlText);
		} finally {
			Memory.free(lookaside);
		}

		htmlNodeToLetters(doc.query.nodes[0], style, letters, styles);
	}
		
	/*
	 * Recursive helper function for htmlToLetters.
	 * Params:
	 *     input = Current xml entity.  T is always of type NodeImpl, which is req'd because Tango's NodeImpl is private. 
	 *     parentStyle =
	 *     letters = 
	 *     style s= */
	private static void htmlNodeToLetters(T)(T input, InlineStyle parentStyle, 
		ref ArrayBuilder!(Letter) letters, ref ArrayBuilder!(InlineStyle) styles)
	{	
		// Apply additional styles based on a tag name.
		void styleByTagName(ref InlineStyle style, string tagName)
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
		string tagName = toLower(input.name, input.name);
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
		{	string text = entityDecode(input.value);
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
	private static string htmlToAscii(char[] input, char[] lookaside)
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
	private static string entityDecode(string text)
	{	// TODO: Perform this in one pass
/*		text = text.substitute("&amp;", "&"); // TODO: fix garbage created by this function.
		text = text.substitute("&lt;", "<");
		text = text.substitute("&gt;", ">");
		text = text.substitute("&quot;", `"`);
		text = text.substitute("&apos;", "'");
		text = text.substitute("&nbsp;", "\&nbsp;"); // unicode 160: non-breaking space*/
		return text;
	}
	unittest
	{	string test = "<>Hello Goodbye&nbsp; &amp;&quot;&apos;&lt;&gt;";
		string result="<>Hello Goodbye\&nbsp; &\"'<>";
		assert (entityDecode(test) == result);
	}
}