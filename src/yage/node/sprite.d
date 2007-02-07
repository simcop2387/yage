/**
 * Copyright:  (c) 2006-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.sprite;

import derelict.opengl.gl;
import yage.resource.resource;
import yage.resource.material;
import yage.resource.model;
import yage.node.basenode;
import yage.node.node;
import yage.core.all;
import yage.system.device;
import yage.system.render;

/**
 * A SpriteNode is a rectangle that always faces the camera.
 * It is useful for special effects such as dust and flares. */
class SpriteNode : Node
{
	protected Material material;

	/// Create this Node as a child of parent.
	this(BaseNode parent)
	{	super(parent);
		setVisible(true);
	}

	/**
	 * Construct this Node as a copy of another Node and recursively copy all children.
	 * Params:
	 * parent = This Node will be a child of parent.
	 * original = This Node will be an exact copy of original.*/
	this (BaseNode parent, SpriteNode original)
	{	super(parent, original);
		material = original.material;
	}

	/// Return the Material assigned to the SpriteNode.
	Material getMaterial()
	{	return material;
	}

	/// Return the distance to the furthest point of the SpriteNode.
	float getRadius()
	{	return 1.414213562*scale.max();
	}

	/// Set the Material of the SpriteNode.
	void setMaterial(Material material)
	{	this.material=material;
	}

	/** Set the Material of the SpriteNode, using the Resource Manager
	 *  to ensure that no Material is loaded twice.
	 *  Equivalent of setMaterial(Resource.material(filename)); */
	void setMaterial(char[] material_file)
	{	setMaterial(Resource.material(material_file));
	}
}
