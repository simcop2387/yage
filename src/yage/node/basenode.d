/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.basenode;

import std.stdio;
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
	Scene		scene;					// The Scene that this node belongs to.
	BaseNode	parent;
	Horde!(Node)children;
	int 		index = -1;				// index of this node in parent array

	protected:
	Matrix		transform;				// The position and rotation of this node relative to its parent
	Matrix		transform_abs;			// The position and rotation of this node in worldspace coordinates
	bool		transform_dirty=true;	// The absolute transformation matrix needs to be recalculated.

	Vec3f		linear_velocity;
	Vec3f		angular_velocity;
	Vec3f		linear_velocity_abs;	// Store a cached version of the absolute linear velocity.
	Vec3f		angular_velocity_abs;
	bool		velocity_dirty=true;	// The absolute velocity vectors need to be recalculated.

	float lifetime = float.infinity;	// in seconds
	BaseNode[] path;	// used in calcTransform

	public:

	/// Construct.
	this()
	{	debug scope( failure ) writef("Backtrace xx "__FILE__"(",__LINE__,")\n");
		children = new Horde!(Node);
	}

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

	/// Get the type of this Node as a string; i.e. "Node", "ModelNode", etc.
	char[] getType()
	{	return this.classinfo.name;
	}

	/**
	 * The Node will be removed (along with all of its children) after a given time.
	 * Params:
	 * seconds = The number of seconds before the Node will be removed.
	 * Set to float.infinity to make the Node last forever (the default behavior).*/
	void setLifetime(float seconds)
	{	lifetime = seconds;
	}

	/// Get the time before the Node will be removed.
	float getLifetime()
	{	return lifetime;
	}

	/**
	 * Calculate and store the absolute transformation matrices of this Node up to the first node
	 * that has a correct absolute transformation matrix.
	 * This is called automatically when the absolute transformation matrix of a node is needed.
	 * Remember that rotating a Node's parent will change the Node's velocity. */
	synchronized protected void calcTransform()
	{
		debug scope( failure ) writef("Backtrace xx ",__FILE__,"(",__LINE__,")\n");

		int l=0;
		BaseNode node = this;
		do	// build a path up to the first node that does not have transform_dirty set.
		{	if (path.length==l)
				path.length = path.length+1;
			path[l] = node;
			node = node.parent;
			l++;
		}while ((node !is null) && (node.transform_dirty))

		// Follow back down that path calculating absolute matrices.
		for (int i=l-1; i>=0; i--)
		{	path[i].transform_abs = path[i].transform;
			if (path[i].parent !is null)
			{	// Calculate the transformation matrix, unrolled for performance.
				Matrix *a = &path[i].transform_abs;
				Matrix *b = &path[i].parent.transform_abs;

				float[16] result=void;
				result[ 0] = a.v[ 0]*b.v[ 0] + a.v[ 1]*b.v[ 4] + a.v[ 2]*b.v[ 8] + a.v[ 3]*b.v[12];
				result[ 1] = a.v[ 0]*b.v[ 1] + a.v[ 1]*b.v[ 5] + a.v[ 2]*b.v[ 9] + a.v[ 3]*b.v[13];
				result[ 2] = a.v[ 0]*b.v[ 2] + a.v[ 1]*b.v[ 6] + a.v[ 2]*b.v[10] + a.v[ 3]*b.v[14];
				result[ 3] = a.v[ 0]*b.v[ 3] + a.v[ 1]*b.v[ 7] + a.v[ 2]*b.v[11] + a.v[ 3]*b.v[15];

				result[ 4] = a.v[ 4]*b.v[ 0] + a.v[ 5]*b.v[ 4] + a.v[ 6]*b.v[ 8] + a.v[ 7]*b.v[12];
				result[ 5] = a.v[ 4]*b.v[ 1] + a.v[ 5]*b.v[ 5] + a.v[ 6]*b.v[ 9] + a.v[ 7]*b.v[13];
				result[ 6] = a.v[ 4]*b.v[ 2] + a.v[ 5]*b.v[ 6] + a.v[ 6]*b.v[10] + a.v[ 7]*b.v[14];
				result[ 7] = a.v[ 4]*b.v[ 3] + a.v[ 5]*b.v[ 7] + a.v[ 6]*b.v[11] + a.v[ 7]*b.v[15];

				result[ 8] = a.v[ 8]*b.v[ 0] + a.v[ 9]*b.v[ 4] + a.v[10]*b.v[ 8] + a.v[11]*b.v[12];
				result[ 9] = a.v[ 8]*b.v[ 1] + a.v[ 9]*b.v[ 5] + a.v[10]*b.v[ 9] + a.v[11]*b.v[13];
				result[10] = a.v[ 8]*b.v[ 2] + a.v[ 9]*b.v[ 6] + a.v[10]*b.v[10] + a.v[11]*b.v[14];
				result[11] = a.v[ 8]*b.v[ 3] + a.v[ 9]*b.v[ 7] + a.v[10]*b.v[11] + a.v[11]*b.v[15];

				result[12] = a.v[12]*b.v[ 0] + a.v[13]*b.v[ 4] + a.v[14]*b.v[ 8] + a.v[15]*b.v[12];
				result[13] = a.v[12]*b.v[ 1] + a.v[13]*b.v[ 5] + a.v[14]*b.v[ 9] + a.v[15]*b.v[13];
				result[14] = a.v[12]*b.v[ 2] + a.v[13]*b.v[ 6] + a.v[14]*b.v[10] + a.v[15]*b.v[14];
				result[15] = a.v[12]*b.v[ 3] + a.v[13]*b.v[ 7] + a.v[14]*b.v[11] + a.v[15]*b.v[15];
				path[i].transform_abs.v[0..16] = result[0..16];

			/*	// This is incorrect and needs to be redone
				// Calculate linear velocity from rotation of parent.
				Vec3f r = Vec3f.allocate();
				r.set(path[i].parent.angular_velocity); // angular velocity of parent
				r.cross(path[i].transform.v[12..15]);	// cross product with position relative to parent.
				r.add(path[i].linear_velocity);		// add in this node's own relative velocity
				// r is now velocity relative its parent.

				// r is now velocity relative to parent's position in absolute worldspace coordinates.
				r.rotate(path[i].parent.transform_abs);

				// add in linear velocity of parent
				r.add(path[i].parent.linear_velocity_abs);

				path[i].linear_velocity_abs.set(r);

			*/
				path[i].transform_dirty = false;
			}
		}
		path.length = 0;
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
		result ~= pad~"Position: " ~ Vec3f(transform.v[12..15]).toString() ~ "\n";
		result ~= pad~"Rotation: " ~ transform.toAxis().toString() ~ "\n";
		result ~= pad~"Velocity: " ~ transform.toAxis().toString() ~ "\n";
		result ~= pad~"Angular : " ~ transform.toAxis().toString() ~ "\n";
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
	{
		debug scope( failure ) writef("Backtrace xx "__FILE__"(",__LINE__,")\n");

		// Decrement lifetime and remove children with < 0 lifetime.
		// We iterate in reverse to ensure we hit all of them, since the last item
		// is moved over the current item when removing from a Horde.
		lifetime-= delta;
		int i = children.length-1;
		while (i>=0)
		{	if (children[i].lifetime<=0)
				children[i].remove();
			i--;
		}

		// Children
		foreach(Node c; children.array())
			c.update(delta);
	}

}
