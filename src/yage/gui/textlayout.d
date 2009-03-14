/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.gui.textlayout;

import tango.io.Stdout;
import tango.math.Math;
import yage.resource.image;
import yage.gui.style;

class TextLayout
{
	
	
	/**
	 * Convert a string of primitive html text and render it to an image.
	 * The following tags and styles are supported: TODO.
	 * Params:
	 *     text = 
	 *     style = 
	 *     fontSize = 
	 *     width = 
	 * Returns:  An image that is no wider than width.
	 */
	static Image render(char[] text, Style style, int fontSize, int width, int height)
	{
		Image textImage;
		
		// Update Text
		// TODO: check style font properties for changes also; font size, family, text align
		if (style.fontFamily)
		{	
			// Fragment stores the grayscale rendering.
			auto fragment = style.fontFamily.render(text, fontSize, fontSize, width, -1, style.textAlign);
			
			
			// Convert to RGBA using style.color.
			textImage = new Image(4, fragment.getWidth(), fragment.getHeight());
			auto fragment4 = new Image(4, fragment.getWidth(), fragment.getHeight());			
			for (int i=0; i<fragment.getData().length; i++) // loop through pixels
				for (int c=0; c<4; c++) // loop through channels
					fragment4.getData()[i*4+c] = 
						fragment.getData()[i] * cast(ubyte)(style.color.ub[c]/255.0f);
				
			textImage.overlay(fragment4);
			
			textImage = textImage.crop(0, 0, width, min(textImage.getHeight(), height));
		}
		
		
		return textImage;
	}
	
	
	
}