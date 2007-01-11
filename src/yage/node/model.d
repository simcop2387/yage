/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.model;

import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.vector;
import yage.system.device;
import yage.system.log;
import yage.resource.resource;
import yage.resource.model;
import yage.resource.material;
import yage.node.node;
import yage.node.basenode;


/// A node used for rendering a 3D model.
class ModelNode : Node
{
	protected Model model;	// The 3D model used by this node

	/// Construct this Node as a child of parent.
	this(BaseNode parent)
	{	super(parent);
		scale = Vec3f(1);
	}

	/**
	 * Construct this Node as a copy of another Node and recursively copy all children.
	 * Params:
	 * parent = This Node will be a child of parent.
	 * original = This Node will be an exact copy of original.*/
	this (BaseNode parent, ModelNode original)
	{	super(parent, original);
		model = original.model;
	}

	/// Get the 3D model that is being used by this Node.
	Model getModel()
	{	return model;
	}

	/// Set the 3D model used by this Node.  This also makes the Node visible.
	void setModel(Model _model)
	{	model = _model;
		setScale(1);	// force calculation of radius
		visible = true;
	}

	/** Set the 3D model used by this Node, using the Resource Manager
	 *  to ensure that no Model is loaded twice.
	 *  Equivalent of setModel(Resource.model(filename)); */
	void setModel(char[] filename)
	{	setModel(Resource.model(filename));
	}

	/** Get the radius of the culling sphere used when rendering the 3D Model
	 *  This is usually the distance from the center of its coordinate plane to
	 *  the most distant vertex.  There is no setRadius() */
	float getRadius()
	{	if (model)
			return model.getRadius()*scale.max();
		else return 0;
	}

	/// Draw the 3D model
	void render()
	{
		if ((model !is null))
		{
			glEnable(GL_LIGHTING);
			enableLights();
			glScalef(scale.x, scale.y, scale.z);

			// Use the VBO Extension
			if (model.cached)
			{	glBindBufferARB(GL_ARRAY_BUFFER, model.getVerticesVBO());
				glVertexPointer(3, GL_FLOAT, 0, null);
				glBindBufferARB(GL_ARRAY_BUFFER, model.getTexCoordsVBO());
				glTexCoordPointer(2, GL_FLOAT, 0, null);
				glBindBufferARB(GL_ARRAY_BUFFER, model.getNormalsVBO());
				glNormalPointer(GL_FLOAT, 0, null);
				glBindBufferARB(GL_ARRAY_BUFFER, 0);
			}
			else// Don't cache the model in video memory
			{	glVertexPointer(3, GL_FLOAT, 0, model.getVertices().ptr);
				glTexCoordPointer(2, GL_FLOAT, 0, model.getTexCoords().ptr);
				glNormalPointer(GL_FLOAT, 0, model.getNormals().ptr);
			}

			foreach (Mesh m; model.getMeshes())
			{	// Render each layer of the material.
				foreach (Layer l; m.getMaterial().getLayers().array())
				{
					l.apply(lights);

					if (model.cached)
					{	glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, m.getTrianglesVBO());
						glDrawElements(GL_TRIANGLES, m.getTriangles().length*3, GL_UNSIGNED_INT, null);
						glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, 0);
					}else
						glDrawElements(GL_TRIANGLES, m.getTriangles().length*3, GL_UNSIGNED_INT, m.getTriangles().ptr);

					// Unapply
					l.unApply();
				}
			}

			glScalef(1/scale.x, 1/scale.y, 1/scale.z);
			glDisable(GL_LIGHTING);
		}
	}
}
