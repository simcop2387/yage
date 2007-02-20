/**
 * Copyright:  (c) 2006-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.base;

import std.stdio;
import std.traits;
import std.bind;
import yage.core.horde;
import yage.core.misc;
import yage.node.node;
import yage.node.scene;
import yage.core.all;

/**
 * Node and Scene both inherit from BaseNode and this abastract class defines
 * fields and methods that are shared between them.  Having both derrived
 * from the same class also allows functions such as setParent(BaseNode parent)
 * to take an argument of either type. */
abstract class BaseNode
{

	// These are public for easy internal access.
	Scene		scene;			// The Scene that this node belongs to.
	BaseNode	parent;
	Horde!(Node)children;
	int 		index = -1;		// index of this node in parent array

	protected void delegate(BaseNode self) on_update = null;	// called on update

	delete(void* p)
	{	throw new Exception("Nodes cannot be deleted.");
	}

	/**
	 * Add a child Node.
	 * Automatically detaches it from any other nodes.
	 * Returns: A self reference.*/
	BaseNode addChild(Node child)
	in {assert(child !is this);}
	body
	{	child.setParent(this);
		return this;
	}

	/// Get an array of this Node's children
	Node[] getChildren()
	{	return children.array();
	}

	/**
	 * Get the index of this Node in its parent's array.
	 * Returns -1 if this node is a Scene.*/
	int getIndex()
	{	return index;
	}

	/// Return this Node's parent.
	BaseNode getParent()
	{	return parent;
	}

	/// Get the Scene at the top of the tree that this node belongs to.
	Scene getScene()
	{	return scene;
	}

	/// Get the type of this Node as a string; i.e. "yage.node.node.ModelNode".
	char[] getType()
	{	return this.classinfo.name;
	}

	/**
	 * Set a function that will be called every time this Node is updated.
	 * Specifically, the supplied function is called after a Node's matrices
	 * are updated and before its children are updated and before it's removed if
	 * it's lifetime is zero.
	 * Params:
	 * on_update = the function that will be called.  Use null as an argument to clear
	 * the function.
	 * Bugs:
	 * Certain Node methods cause access violations.  Perhaps this is a dmd bug?
	 * Example:
	 * --------------------------------
	 * SpriteNode s = new SpriteNode(scene);
	 * s.setMaterial("something.xml");
	 *
	 * // Gradually fade to transparent as lifetime decreases.
	 * void recolor(BaseNode self)
	 * {   (cast(SpriteNode)self).setColor(1, 1, 1, self.getLifetime()/5);
	 * }
	 * s.setLifetime(5);
	 * s.onUpdate(&doSomething);
	 * --------------------------------*/
	void onUpdate(void delegate(typeof(this) self) on_update)
	{	this.on_update = on_update;
	}

	/// Return a string representation of this Node for human reading.
	char[] toString()
	{	return toString(false);
	}

	/**
	 * Return a string representation of this Node for human reading.
	 * Params:
	 * recurse = Print this Node's children as well. */
	char[] toString(bool recurse)
	{	static int indent;
		char[] pad = new char[indent*3];
		pad[0..length] = ' ';

		char[] result = pad ~ "[" ~ getType() ~ "]\n";
		if(parent)
			result ~= pad~"Parent  : " ~ parent.getType() ~ "\n";
		/*
		result ~= pad~"Position: " ~ Vec3f(transform.v[12..15]).toString() ~ "\n";
		result ~= pad~"Rotation: " ~ transform.toAxis().toString() ~ "\n";
		result ~= pad~"Velocity: " ~ transform.toAxis().toString() ~ "\n";
		result ~= pad~"Angular : " ~ transform.toAxis().toString() ~ "\n";*/
		result ~= pad~"Children: " ~ std.string.toString(children.length) ~ "\n";
		delete pad;

		if (recurse)
		{	indent++;
			foreach (Node c; children.array())
				result ~= c.toString(recurse);
			indent--;
		}

		return result;
	}

	/// Update the positions and rotations of this Node and all children by delta seconds.
	void update(float delta)
	{	debug scope(failure) writef("Backtrace xx "__FILE__"(",__LINE__,")\n");

		// Call the onUpdate() function
		if (on_update !is null)
			on_update(this);

		// Iterate in reverse to ensure we hit all of them, since the last item
		// is moved over the current item when removing from a Horde.
		foreach_reverse(Node c; children)
			c.update(delta);
	}
}
