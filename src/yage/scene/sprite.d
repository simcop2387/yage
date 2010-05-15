/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.sprite;

import yage.resource.manager;
import yage.resource.material;
import yage.scene.node;
import yage.scene.visible;


/**
 * A SpriteNode is a rectangle that always faces the camera.
 * It is useful for special effects such as dust and flares. */
class SpriteNode : VisibleNode
{
	protected Material material;

	/**
	 * Create a SpriteNode and optinally set the material from an already loaded material or a material filename. */
	this()
	{	super();
	}
	this(Material material) /// ditto
	{	this();
		setMaterial(material);
	}	
	this(char[] filename, char[] id) /// ditto
	{	this();
		setMaterial(filename, id);
	}
	
	/**
	 * Make a duplicate of this node, unattached to any parent Node.
	 * Params:
	 *     children = recursively clone children (and descendants) and add them as children to the new Node.
	 * Returns: The cloned Node. */
	override SpriteNode clone(bool children=false)
	{	auto result = cast(SpriteNode)super.clone(children);
		result.material = material;
		return result;
	}

	/// Return the Material assigned to the SpriteNode.
	Material getMaterial()
	{	return material;
	}

	/// Return the distance to the furthest point of the SpriteNode, including size but not scale.
	float getRadius()
	{	return 1.414213562*size.max();
	}

	/// Set the Material of the SpriteNode.
	void setMaterial(Material material)
	{	this.material=material;
	}

	/** Set the Material of the SpriteNode, using the ResourceManager Manager
	 *  to ensure that no Material is loaded twice.
	 *  Equivalent of setMaterial(ResourceManager.material(filename)); */
	void setMaterial(char[] filename, char[] id)
	{	setMaterial(ResourceManager.material(filename, id));
	}
}
