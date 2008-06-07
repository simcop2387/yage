/**
 * Copyright:  (c) 2005-2007 Eric Poggel
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
 * -------------------------------- */
class Tree(T)
{	
	T parent;
	T[] children;
	int index=-1;
	
	/// Ensure that child is removed from its parent.
//	~this()
//	{	remove();		
//	}
	
	/**
	 * Add a child element.
	 * Automatically detaches it from any other element's children.
	 * Returns: A self reference.*/
	T addChild(T child)
	in {
		assert(child != this);
		assert(child !is null);
	}body
	{	child.setParent(cast(T)this);
		return cast(T)this;
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
	T setParent(T _parent) /// Ditto
	in { assert(_parent !is null);
	}body
	{	if (parent && parent.isChild(cast(T)this))
			yage.core.array.remove(parent.children, index);
		
		// Add to new parent
		parent = _parent;
		parent.children ~= cast(T)this;
		index = parent.children.length-1;
		return cast(T)this;
	}
	
	/// Is elem a child of this element?
	bool isChild(T elem)
	{	if (elem.index < 0 || elem.index >= children.length)
			return false;
		return cast(bool)(children[elem.index] == elem);
	}
	
	/// Remove this element from its parent
	void remove()
	{	// this needs to happen because some children (like lights) may need to do more in their remove() function.
		foreach_reverse(T c; children)
			c.remove();
		
		if (index > 0)
		{	yage.core.all.remove(parent.children, index, false);
			if (index < parent.children.length)
				parent.children[index].index = index;
			index = -1; // so remove can't be called twice.
		}

	}
}