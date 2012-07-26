/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.sprite;

import yage.core.array;
import yage.core.math.all;
import yage.resource.manager;
import yage.resource.graphics.all;
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
	Material material; /// The material rendered on the sprite.
	
	static Geometry spriteQuad;
	
	static this()
	{	spriteQuad = Geometry.createPlane();
	}
	
	/**
	 * Create a SpriteNode and optinally set the material from an already loaded material or a material filename. */
	this()
	{	super();  // default constructor required for clone.
		transform().cullRadius = 1.414213562f;
	}
	this(Node parent) /// ditto
	{	super(parent);
	}
	this(Material material, Node parent=null) /// ditto
	{	this(parent);
		this.material = material;
	}	
	this(char[] filename, char[] id, Node parent=null) /// ditto
	{	this(parent);
		material = ResourceManager.material(filename, id);
	}
	
	/**
	 * Make a duplicate of this node, unattached to any parent Node.
	 * Params:
	 *     children = recursively clone children (and descendants) and add them as children to the new Node.
	 * Returns: The cloned Node. */
	override Node clone(bool children=true, Node destination=null)
	{	assert (!destination || cast(SpriteNode)destination);
		auto result = cast(SpriteNode)super.clone(children, destination);
		result.material = material;
		//Log.write("sprite clone");
		return result;
	}

	private Material[1] temp; // hack to return single member array w/o static allocation.
		
	void getRenderCommands(CameraNode camera, LightNode[] lights, ref ArrayBuilder!(RenderCommand) result)
	{	
		//Matrix* transform = &transform_abs;
		//Vec3f position = cast(Vec3f*)transform.v[12..15].ptr; // speed hack
		Vec3f wp = getWorldPosition();
		
		//if (camera.isVisible(wp, getRadius()))	
		{	
			Vec3f cameraPosition = camera.getWorldPosition();	
			Vec3f spriteNormal = Vec3f(0, 0, -1);		
			Vec3f spriteToCamera = (cameraPosition - wp).normalize();	
			Vec3f rotation = spriteNormal.lookAt(cameraPosition - wp, Vec3f(0, 1, 0));
			
			RenderCommand rc;			
			rc.transform = getWorldTransform().rotate(rotation);
			rc.geometry = spriteQuad;
			temp[0] = material;
			//spriteQuad.getMeshes()[0].setMaterial(ResourceManager.material("space/star.dae", "star-material"));
			rc.materialOverrides = temp;			
			rc.setLights(getLights(lights, 8));
			result.append(rc);
		}
	}

	/// Return the distance to the furthest point of the SpriteNode, including size but not scale.
	float getRadius()
	{	return 1.414213562*getWorldScale().max();
	}

}
