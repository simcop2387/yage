/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.model;

import yage.core.vector;
import yage.system.device;
import yage.system.log;
import yage.resource.resource;
import yage.resource.model;
import yage.resource.material;
import yage.node.visible;
import yage.node.node;


/// A node used for rendering a 3D model.
class ModelNode : VisibleNode
{
	protected Model model;	// The 3D model used by this node
	protected float radius=0;	// cached radius

	/// Construct this Node as a child of parent.
	this(Node parent)
	{	super(parent);
		visible = true;
	}

	/**
	 * Construct this Node as a copy of another Node and recursively copy all children.
	 * Params:
	 * parent = This Node will be a child of parent.
	 * original = This Node will be an exact copy of original.*/
	this (Node parent, ModelNode original)
	{	super(parent, original);
		model = original.model;
		radius = original.radius;
	}

	/// Get the 3D model that is being used by this Node.
	Model getModel()
	{	return model;
	}

	/// Set the 3D model used by this Node.
	void setModel(Model model)
	{	this.model = model;
		radius = model.getDimensions().scale(size).length();
	}

	/**
	 * Set the 3D model used by this Node, using the Resource Manager
	 * to ensure that no Model is loaded twice.
	 * Equivalent of setModel(Resource.model(filename)); */
	void setModel(char[] filename)
	{	setModel(Resource.model(filename));
	}

	/// Overridden to cache the radius if changed by the scale.
	void setSize(Vec3f s)
	{	super.size = Vec3f(s.x, s.y, s.z);
		if (model)
			radius = model.getDimensions().scale(size).max();
	}	
	Vec3f getSize() /// Ditto
	{	return super.size;		
	}


	/**
	 * Get the radius of the culling sphere used when rendering the 3D Model
	 * This is usually the distance from the center of its coordinate plane to
	 * the most distant vertex.  There is no setRadius() */
	float getRadius()
	{	return radius;
	}
}
