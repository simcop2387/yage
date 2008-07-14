/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.sprite;

import yage.resource.resource;
import yage.resource.material;
import yage.scene.node;
import yage.scene.visible;


/**
 * A SpriteNode is a rectangle that always faces the camera.
 * It is useful for special effects such as dust and flares. */
class SpriteNode : VisibleNode
{
	protected Material material;

	/// Create this Node as a child of parent.
	this(Node parent)
	{	super(parent);
		visible = true;
	}

	/**
	 * Construct this Node as a copy of another Node and recursively copy all children.
	 * Params:
	 * parent = This Node will be a child of parent.
	 * original = This Node will be an exact copy of original.*/
	this (Node parent, SpriteNode original)
	{	super(parent, original);
		material = original.material;
	}

	/// Return the Material assigned to the SpriteNode.
	Material getMaterial()
	{	return material;
	}

	/// Return the distance to the furthest point of the SpriteNode.
	float getRadius()
	{	return 1.414213562*size.max();
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
