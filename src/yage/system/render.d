module yage.system.render;

import derelict.opengl.gl;
import derelict.opengl.glext;

import yage.core.freelist;
import yage.core.horde;
import yage.core.matrix;
import yage.core.vector;
import yage.resource.layer;
import yage.resource.material;
import yage.resource.model;
import yage.system.constant;
import yage.system.device;
import yage.node.light;
import yage.node.node;

struct RenderNode
{	Model model;
	Matrix transform;
	Material materials;
	LightNode[] lights;

	static RenderNode opCall(Matrix transform, Model model, Material materials, LightNode[] lights)
	{	RenderNode a;

		a.transform = transform;
		a.model = model;
		a.materials = materials;
		a.lights = lights;
		return a;
	}
}

/**
 * As the nodes of the scene graph are traversed, 3d mesh data is added to an
 * internal queue of rendering nodes.  They are then sorted to optimize
 * rendering speed, to correctly render translucent polygons, etc.  Call flush()
 * to process the queue and render.*/
class Render
{
	static Horde!(RenderNode) queue;
	//static Horde!(Node) queue2; // probably better than using RenderNode

	/**
	 * Add a model to the queue for rendering.
	 * Params:
	 * transform = the model's absolute transformatin matrix containing rotation,
	 * translation, and scaling values.
	 * model = contains vertex, triangle, etc. data to render.
	 * materials = An optional array of materials to override the materials of
	 * the model.  The first material will override the material of the model's
	 * first mesh, the second for the second, and etc.
	 * lights = an array of lights that affect the model data.*/
	static void addModel(Matrix transform, Model model, Material materials=null, LightNode[] lights=null)
	{	if (queue is null)
			queue = new Horde!(RenderNode);

		queue.add(RenderNode(transform, model, materials, lights));
	}

	/// Render everything in the queue, in an optimized order.
	static void flush()
	{
		// Sort everything in the queue by its distance from the camera.
		Matrix camera = Device.getCurrentCamera().getAbsoluteTransform();
		queue.sortType!(float).radix( (RenderNode n) { return -Vec3f(n.transform.v[11..15]).distance2(Device.getCurrentCamera().getAbsolutePosition()); }, true, true);

		glEnable(GL_LIGHTING);
		foreach(RenderNode rn; queue.array())
		{
			glPushMatrix();
			glLoadMatrixf(rn.transform.v.ptr);
			Model model = rn.model;


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

				//Material matl = rn.materials.length ? rn.materials[0] : m.getMaterial();
				Material matl = rn.materials;


				if (matl !is null)
					foreach (Layer l; matl.getLayers().array())
					{
						l.apply(rn.lights);
						if (model.cached)
						{	glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, m.getTrianglesVBO());
							glDrawElements(GL_TRIANGLES, m.getTriangles().length*3, GL_UNSIGNED_INT, null);
							glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, 0);
						}else
							glDrawElements(GL_TRIANGLES, m.getTriangles().length*3, GL_UNSIGNED_INT, m.getTriangles().ptr);
						l.unApply();
					}
			}
			glPopMatrix();
		}

		// Prevent a costly sizedown() and then erase the queue.
		queue.reserve(queue.length);
		queue.clear();
		glDisable(GL_LIGHTING);
	}


}
