/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.core.tree;

import std.gc;
import std.stdio;
import yage.core.array;

/**
 * Implements an element that can be used in a tree, with parents and children.
 * Example:
 * --------------------------------
 * class Node : Tree!(Node) {}
 * auto n = new Node();
 * n.addChild(new Node());
 * -------------------------------- 
 */
class Tree(T)
{	
	protected T parent;			// reference to parent
	protected T[] children;		// array of this element's children.
	protected int index=-1;		// index of this element in its parent's array, -1 if no parent.

	/**
	 * Add a child element.
	 * Automatically detaches it from any other element's children.
	 * Params:
	 *     child = 
	 * Returns: A reference to the child.
	 */
	S addChild(S : T)(S child)
	in {
		assert(child != this);
		assert(child !is null);
	}body
	{	
		// If child has an existing parent.
		if (child.parent)
		{	assert(child.parent.isChild(cast(S)child));
			yage.core.array.remove(child.parent.children, child.index);
		}
		
		// Add as a child.
		child.parent = cast(T)this;
		children ~= cast(T)child;
		child.index = children.length-1;
		return child;	
	}
	
	/// Get an array of this element's children
	T[] getChildren()
	{	return children;
	}
	
	/**
	 * Get / set the parent of this element (what it's attached to).
	 * Setting a new parent removes it from its old parent's children and returns a self-reference. */
	T getParent()
	{	return parent;
	}
	T setParent(T _parent) /// ditto
	in { assert(_parent !is null);
	}body // should this function evenually go away?
	{	return _parent.addChild(cast(T)this);
	}
	
	/**
	 * Is elem a child of this element?
	 * This function will also return false if elem is null. */ 
	bool isChild(T elem)
	{	if (!elem || elem.index < 0 || elem.index >= children.length)
			return false;
		return cast(bool)(children[elem.index] == elem);
	}
	
	/// Remove this element from its parent.
	void remove()
	{	// this needs to happen because some children (like lights) may need to do more in their remove() function.
		foreach_reverse(T c; children)
			c.remove();
		
		if (index > 0)
		{	yage.core.all.remove(parent.children, index, false);
			if (index < parent.children.length)
				parent.children[index].index = index;
			index = -1; // so remove can't be called twice.
			parent = null;
		}

	}
}