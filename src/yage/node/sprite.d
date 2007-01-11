/**
 * Copyright:  (c) 2006 Eric Poggel
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
	static Model model;
	Material material;

	/// Create this Node as a child of parent.
	this(BaseNode parent)
	{	super(parent);
		scale = Vec3f(1);
		setVisible(true);
	}

	/**
	 * Construct this Node as a copy of another Node and recursively copy all children.
	 * Params:
	 * parent = This Node will be a child of parent.
	 * original = This Node will be an exact copy of original.*/
	this (BaseNode parent, SpriteNode original)
	{	super(parent, original);
		model = original.model;
		material = original.material;
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
	void setMaterial(char[] filename)
	{	setMaterial(Resource.material(filename));
	}

	/// Render the SpriteNode.  This is used internally.
	void render()
	{
		Vec3f axis = Device.getCurrentCamera().getAbsoluteRotation();
		float angle = axis.length();
		axis = axis.scale(1/angle);
		glRotatef(angle*57.295, axis.x, axis.y, axis.z);
		glScalef(scale.x, scale.y, scale.z);

		Matrix m;
		glGetFloatv(GL_MODELVIEW_MATRIX, m.v.ptr);

		enableLights();

		/// A quad for the sprite's texture
		if (model is null)
		{	model = new Model();
			model.addVertex(Vec3f(-1,-1, 0), Vec3f(0, 0, 1), Vec2f(0, 1));
			model.addVertex(Vec3f( 1,-1, 0), Vec3f(0, 0, 1), Vec2f(1, 1));
			model.addVertex(Vec3f( 1, 1, 0), Vec3f(0, 0, 1), Vec2f(1, 0));
			model.addVertex(Vec3f(-1, 1, 0), Vec3f(0, 0, 1), Vec2f(0, 0));
			model.addMesh(material, [Vec3i(0, 1, 2), Vec3i(2, 3, 0)]);
			model.upload();
		}

		Render.addModel(m, model, material, lights);
	}
}
