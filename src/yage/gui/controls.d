/**
 * Copyright:  (c) 2005-2010 Eric Poggel
 * Authors:	   Eric Poggel
 * License:	   <a href="lgpl3.txt">LGPL v3</a> 
 */

/**
 * This file contains ideas and potential interfaces for UI controls. */
module yage.gui.scrolling;

import yage.core.math.vector;
import yage.gui.style;
import yage.gui.surface;
import yage.resource.texture;

///
enum Layout
{	HORIZONTAL, ///
	VERTICAL /// ditto
}

/**
 * This class is unimplemented. */
class Box : Surface
{	Layout layout;
	int spacing;
	
	this(Surface parent=null)
	{	super(parent);
	}
}

/**
 * This class is unimplemented. */
class HBox : Box
{	this(Surface parent=null)
	{	layout = Layout.HORIZONTAL;
		super(parent);
	}
}

/**
 * This class is unimplemented. */
class VBox : Box
{	this(Surface parent=null)
	{	layout = Layout.VERTICAL;
		super(parent);
	}
}

/**
 * This class is unimplemented. 
 * A class that can be dragged horizontally or vertically and resized at its edges. */
class Resizer: Surface
{	
	enum Region
	{	TOP=1,
		LEFT=2,
		CENTER=4,
		RIGHT=8,
		BOTTOM=16
	};
	
	short enabledRegions;	/// Bitmask of regions that allow dragging/resizing behavior
	int edgeWidth;			/// Width of resizable edges, in pixels
	bool moveHorizontal;	/// Allow dragging in the horizontal direction
	bool moveVertical;		/// Allow dragging in the vertical direction.
	
	protected int regions;		// Stores the regions was the mouse over during the last mouse press.
	protected Vec2i mouseStart;
	protected Vec4i geometryStart;
}

/**
 * This class is unimplemented. 
 * A horizontal or vertical scroll bar. */
class ScrollBar : Surface
{
	Layout direction;
	bool enabled;
	
	int minimum;
	int maximum;
	
	int lineScrollSize; /// Amount scrolled when top or bottom arrow is clicked.
	int pageScrollSize; /// Amount scrolled when scroll bar is clicked.
	
	Resizer bar;
	void delegate(ScrollBar self) onScrollChange; 
	
	protected int value;
	
	this(Surface parent=null)
	{	style.width = style.height = 16; // px
		bar = new Resizer();
		super(parent);
	}
	
	///
	int getValue()
	{	return value;
	}	
	void setValue(int value) /// ditto
	{	this.value = value;
	}
}

/**
 * This class is unimplemented. 
 * A surface that can have a horizontal and vertical scroll bars that adjust according to the content size. */
class ScrollArea : Surface
{
	enum Show
	{	AUTO,
		ALWAYS,
		NEVER
	}
	
	Show horizontalScrollPolicy;
	Show verticalScrollPolicy;
	
	ScrollBar horizontalScrollBar;
	ScrollBar verticalScrollBar;
	
	this(Surface parent=null)
	{	style.overflowX = 
		style.overflowY = Style.Overflow.HIDDEN;
	
		horizontalScrollBar = new ScrollBar(this);
		verticalScrollBar = new ScrollBar(this);
		horizontalScrollBar.style.zIndex = verticalScrollBar.style.zIndex = int.max;
		
		super(parent);
	}
}

/**
 * This class is unimplemented. */
class FileDialog
{	
	Surface address;
	Surface up;
	ListBox fileList;	
	Surface fileName;
	ListBox fileType; 
	Surface fileNameLabel, fileTypeLabel;
	Surface open;
	Surface cancel;
}

/**
 * This class is unimplemented. */
class Slider
{	Layout direction;
}

/**
 * This class is unimplemented. */
class CheckBox
{
	Surface checkMark;
	protected bool checked;
}

/**
 * This class is unimplemented. */
class ListBox
{	Surface down;
	Surface[] options;
	int height = 1;
	bool editable = false;
}

/**
 * This class is unimplemented. */
class SpinBox
{	Surface up;
	Surface down;
}