/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.sprite;

import yage.core.array;
import yage.core.math.all;
import yage.resource.manager;
import yage.resource.material;
import yage.resource.geometry;
import yage.scene.camera;
import yage.scene.light;
import yage.scene.node;
import yage.scene.visible;
import yage.system.log;

/**
 * A SpriteNode is a rectangle that always faces the camera.
 * It is useful for special effects such as dust and flares. */
class SpriteNode : VisibleNode
{
	protected Material material;
	static Geometry spriteQuad;
	
	static this()
	{	spriteQuad = Geometry.createPlane();
	}
	
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

	private Material[1] temp; // hack to return single member array w/o static allocation.
		
	void getRenderCommands(CameraNode camera, LightNode[] lights, ref ArrayBuilder!(RenderCommand) result)
	{	
		Matrix* transform = &transform_abs;
		Vec3f* position = cast(Vec3f*)transform.v[12..15].ptr; // speed hack
		
		if (camera.isVisible(*position, getRadius()))	
		{	Vec3f sprite = getAbsolutePosition();
			Vec3f cameraPosition = camera.getAbsolutePosition();	
			Vec3f spriteNormal = Vec3f(0, 0, -1);		
			Vec3f spriteToCamera = (cameraPosition - sprite).normalize();	
			Vec3f rotation = spriteNormal.lookAt(cameraPosition - sprite, Vec3f(0, 1, 0));
			
			RenderCommand rc;			
			rc.transform = transform.scale(getSize()).rotate(rotation);
			rc.geometry = spriteQuad;
			temp[0] = material;
			//spriteQuad.getMeshes()[0].setMaterial(ResourceManager.material("space/star.dae", "star-material"));
			rc.materialOverrides = temp;
			
			Log.file = "c:\\scene.txt";
			//Log.dump(rc.materialOverrides[0]);
			
			rc.setLights(getLights(lights, 8));
			result.append(rc);
		}
	}
	
	/// Return the Material assigned to the SpriteNode.
	Material getMaterial()
	{	return material;
	}

	/// Return the distance to the furthest point of the SpriteNode, including size but not scale.
	float getRadius()
	{	return 1.414213562*size.max()*getScale().max();
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
