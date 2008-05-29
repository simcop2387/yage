/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.core.tree;


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
	T[T] children;
	
	/// Prohibit manual deletion of Tree elements.  Use .remove() instead.
	delete(void* p)
	{	throw new Exception("Tree elements cannot be deleted.  Use remove().");
	}
	
	/**
	 * Add a child element.
	 * Automatically detaches it from any other element's children.
	 * Returns: A self reference.*/
	T addChild(T child)
	in {assert(child !is this);}
	body
	{	child.setParent(cast(T)this);
		return cast(T)this;
	}
	
	/// Get an array of this element's children
	T[T] getChildren()
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
	{			
		if (parent && cast(T)this in parent.children)
			parent.children.remove(cast(T)this);
		
		// Add to new parent
		parent = _parent;
		parent.children[cast(T)this] = cast(T)this;
		return cast(T)this;
	}
	
	/// Remove this element.  This function should be used instead of delete.
	void remove()
	{	// this needs to happen because some children (like lights) may need to do more in their remove() function.
		foreach(T c; children)
			c.remove();
		if (parent && cast(T)this in parent.children)
			parent.children.remove(cast(T)this);
	}
}