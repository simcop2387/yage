/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="http://www.opensource.org/licenses/zlib-license.php">zlib/libpng</a>
 * See_Also: Vector
 *
 * This module defines classes for organizing data structures into trees.
 *
 * Inherit from TreeRoot and TreeNode to link arbitrary objects together into a
 * tree of arbitrary height and with any number of children at each level.
 * Both TreeRoot and TreeNode inherit from TreeItem so that their shared methods
 * don't need to be defined twice and also so that functions can be constructed
 * that take either a TreeRoot or TreeNode as arguments.
 */


module core.tree;

import std.stdio;
import std.string;
import core.misc;
import core.horde;


unittest
{	TreeRoot s = new TreeRoot(); s.name = "s";
	TreeNode a = new TreeNode(s); a.name = "a";
	TreeNode b = new TreeNode(s); b.name = "b";

	assert(s.getChildren().length==2);
	assert(s.getIndex()==-1);
	assert(a.getIndex()==0);
	assert(b.getIndex()==1);

	a.addChild(b);
	assert(s.getParent() is null);
	assert(b.getParent() is a);
	assert(b.getRoot() is s);
	assert(a.getChildren()[0] is b);

	TreeRoot t = new TreeRoot(); t.name = "t";
	t.addChild(a);
	t.print();
	assert(s.getChildren().length==0);
	assert(a.getChildren()[0] is b);
	a.remove();
	assert(t.getChildren().length==0);
}


/// TreeItem is an abstract class that TreeRoot and TreeNode derrive from.
abstract class TreeItem
{
	int 				index = -1;		// index of this node in parent array
	TreeRoot			root;			// The root of the tree that this node belongs to.
	Horde!(TreeNode)	children;		// An array (actually a Horde) of children.
	char[] name;

	/// Construct and allocate memory.
	this()
	{	children = new Horde!(TreeNode);
	}

	/** Add a child TreeNode to this TreeItem.
	 *  Automatically detaches it from any other nodes.*/
	int addChild(TreeNode child)
	in {assert(child !is this);}
	body
	{	// Remove from previous parent
		if (child.index!=-1)
		{	child.parent.children.remove(child.index);
			if (child.index < child.parent.children.length) // if not removed from the end.
				child.parent.children[child.index].index = child.index; // update external index.
		}
		// Add to new parent's child array.
		int i = children.add(child);
		child.index = i;
		child.parent = this;
		child.root = root;
		return i;
	}

	/// Return a Horde (array) of this TreeItem's children.
	Horde!(TreeNode) getChildren()
	{	return children;
	}

	/** Get the index of this TreeNode in its parent's array of children.
	 *  Returns -1 if this node is a root.*/
	int getIndex()
	{	return index;
	}

	/// Get the root of the tree.
	TreeRoot getRoot()
	{	return root;
	}

	/// Remove this Node and all children.  This should be called instead of delete.
	void remove()
	{	foreach(TreeNode c; children.array())
			c.remove();
		delete this;
	}

	// These cause linking errors!
	void print()
	{	writefln(toString());
	}

	/// Returns a new string for printing this Node and all of its children.
	char[] toString(int level=0)
	{	char[] result = .toString(index) ~ " " ~ formatString("%s Root:", this) ~ root.name ~ " Name:" ~ name ~ " Children:"~.toString(children.length) ~ "\n";
		result = rjustify(result, level*2+result.length);
		int l = result.length;
		foreach (TreeNode tn; children.array)
			result ~= rjustify(tn.toString(level+1), l+2);
		return result;
	}
}

/// TreeRoot is a TreeItem with no parent
class TreeRoot : TreeItem
{	this()
	{	root = this;
	}

	/// Always return null.  This can be used to tell a TreeNode from a TreeRoot.
	TreeItem getParent()
	{	return null;
	}
}


/// A TreeNode is any TreeItem except for a TreeRoot.
class TreeNode : TreeItem
{
	TreeItem	parent;

	/// Construct as a child of _parent
	this(TreeItem parent)
	{	parent.addChild(this);
	}

	/// Return the parent of this TreeNode.
	TreeItem getParent()
	{	return parent;
	}

	/// Delete this Node and all of its children.
	void remove()
	{	parent.children.remove(index);
			if (index< parent.children.length)
				parent.children[index].index = index;
		super.remove();
	}

	/** Set the parent of this Node (what it's attached to) and remove
	 *  it from its previous parent. */
	int setParent(TreeItem _parent)
	{	// Add to new parent
		return index = parent.addChild(this);
	}

	/// Returns a new string for printing this Node and all of its children.
	char[] toString(int level=0)
	{	char[] result = .toString(index) ~ " " ~ formatString("%s Root:", this) ~ root.name ~ " Name:" ~ name ~ " Parent:" ~ parent.name ~ " Children:"~.toString(children.length)~"\n";
		result = rjustify(result, level*2+result.length);
		int l = result.length;
		foreach (TreeNode tn; children.array)
			result ~= rjustify(tn.toString(level+1), l+2);
		return result;
	}
}
