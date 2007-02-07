/**
 * Copyright:  (c) 2006-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.system.render;

import derelict.opengl.gl;
import derelict.opengl.glext;

import std.stdio;
import yage.core.horde;
import yage.core.matrix;
import yage.core.vector;
import yage.core.plane;
import yage.system.constant;
import yage.system.device;
import yage.resource.layer;
import yage.resource.material;
import yage.resource.model;
import yage.resource.mesh;
import yage.node.all;
import yage.node.camera;
import yage.node.node;
import yage.node.light;
import yage.node.scene;


struct AlphaTriangle
{	Vec3f[3] vertices;
	Material material;
}

/**
 * As the nodes of the scene graph are traversed, those to be rendered in
 * the current frame are added to a queue.  They are then reordered for correct
 * and optimal rendering.  Translucent polygons are separated, sorted
 * and rendered in a second pass. */
class Render
{

	protected static Node[] nodes;			// Linking errors when created as a Horde :(
	protected static Horde!(Mesh) translucent;

	// Basic shapes
	protected static Model mcube;
	protected static Model msprite;

	protected static bool models_generated = false;
	protected static CameraNode current_camera;


	/// Add a node to the queue for rendering.
	static void add(Node node)
	{	//if (nodes is null)
		//	nodes = new Horde!(Node);
		nodes ~= node;
	}

	/// Render everything in the queue
	static void all()
	{
		if (!models_generated)
			generate();

		// Loop through all nodes in the queue
		foreach (Node n; nodes)
		{
			glPushMatrix();
			glMultMatrixf(n.getAbsoluteTransformPtr().v.ptr);
			glScalef(n.getScale().x, n.getScale().y, n.getScale().z);
			glColor4fv(n.getColor().v.ptr);
			n.enableLights();

			switch(n.getType())
			{	case "yage.node.model.ModelNode":
					model((cast(ModelNode)n).getModel(), n.getLights(), n.getColor());
					break;
				case "yage.node.sprite.SpriteNode":
					sprite((cast(SpriteNode)n).getMaterial(), n.getLights(), n.getColor());
					break;
				case "yage.node.graph.GraphNode":
					model((cast(GraphNode)n).getModel(), n.getLights(), n.getColor());
					break;
				case "yage.node.terrain.TerrainNode":
					model((cast(TerrainNode)n).getModel(), n.getLights(), n.getColor());
					break;
				case "yage.node.terrain.LightNode":
					// render cube as the color of the light
					cube((cast(LightNode)n).getDiffuse().add((cast(LightNode)n).getAmbient()));
					break;
				default:
					cube(n.getColor());
			}
			glPopMatrix();
		}
		nodes.length = 0;
	}


	/// Get the current (or last) camera that is/was rendering a scene.
	static CameraNode getCurrentCamera()
	{	return current_camera;
	}

	/// Set the current camera for rendering.
	static void setCurrentCamera(CameraNode camera)
	{	current_camera = camera;
	}

	/// Render a cube
	protected static void cube(Vec4f color)
	{	model(mcube, null, color);
	}

	/**
	 * Render the meshes with opaque materials and pass any meshes with materials
	 * that require blending to the queue of translucent meshes. */
	protected static void model(Model model, LightNode[] lights, Vec4f color)
	{
		model.bind();

		// Loop through the meshes
		foreach (Mesh m; model.getMeshes())
		{
			// Bind and draw the triangles
			void draw()
			{	if (model.getCached())
				{	glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, m.getTrianglesVBO());
					glDrawElements(GL_TRIANGLES, m.getTriangles().length*3, GL_UNSIGNED_INT, null);
					// glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, 0);
				}else
					glDrawElements(GL_TRIANGLES, m.getTriangles().length*3, GL_UNSIGNED_INT, m.getTriangles().ptr);
			}

			Material matl = m.getMaterial();
			if (matl !is null)
				// Loop through each layer
				foreach (Layer l; matl.getLayers().array())
				{
					// If not translucent
					//if (l.
						l.apply(lights, color);
						draw();
						l.unApply();
				}
			else
				draw();
		}
	}

	/// Render a sprite
	protected static void sprite(Material material, LightNode[] lights, Vec4f color)
	{
		// Rotate so that sprite always faces camera
		Matrix m;
		glGetFloatv(GL_MODELVIEW_MATRIX, m.v.ptr);
		Vec3f axis = current_camera.getAbsoluteRotation();
		float angle = axis.length();
		axis = axis.scale(1/angle);
		glRotatef(angle*57.295779513, axis.x, axis.y, axis.z);

		// Set material and draw as model
		msprite.getMeshes()[0].setMaterial(material);
		model(msprite, lights, color);
	}


	/**
	 * Generate models used for various Nodes (like the quad for SpriteNodes. */
	protected static void generate()
	{	// Sprite
		msprite = new Model();
		msprite.addVertex(Vec3f(-1,-1, 0), Vec3f(0, 0, 1), Vec2f(0, 1));
		msprite.addVertex(Vec3f( 1,-1, 0), Vec3f(0, 0, 1), Vec2f(1, 1));
		msprite.addVertex(Vec3f( 1, 1, 0), Vec3f(0, 0, 1), Vec2f(1, 0));
		msprite.addVertex(Vec3f(-1, 1, 0), Vec3f(0, 0, 1), Vec2f(0, 0));
		msprite.addMesh(new Mesh(null, [Vec3i(0, 1, 2), Vec3i(2, 3, 0)]));
		msprite.upload();

		// Cube (in as little code as possible :)
		mcube = new Model();
		mcube.addMesh(new Mesh());
		for (int x=-1; x<=1; x+=2)
		{	for (int y=-1; y<=1; y+=2)
			{	for (int z=-1; z<=1; z+=2)
				{	mcube.addVertex(Vec3f(x, y, z), Vec3f(x, 0, 0), Vec2f(y*.5+.5, z*.5+.5));	// +-x
					mcube.addVertex(Vec3f(x, y, z), Vec3f(0, y, 0), Vec2f(x*.5+.5, z*.5+.5));	// +-y
					mcube.addVertex(Vec3f(x, y, z), Vec3f(0, 0, z), Vec2f(x*.5+.5, y*.5+.5));	// +-z
		}	}	}
		mcube.getMesh(0).addTriangle(Vec3i(0, 6, 9));
		mcube.getMesh(0).addTriangle(Vec3i(9, 3, 0));
		mcube.getMesh(0).addTriangle(Vec3i(1, 4, 16));
		mcube.getMesh(0).addTriangle(Vec3i(16, 13, 1));
		mcube.getMesh(0).addTriangle(Vec3i(2, 14, 20));
		mcube.getMesh(0).addTriangle(Vec3i(20, 8, 2));
		mcube.getMesh(0).addTriangle(Vec3i(12, 15, 21));
		mcube.getMesh(0).addTriangle(Vec3i(21, 18, 12));
		mcube.getMesh(0).addTriangle(Vec3i(7, 19, 22));
		mcube.getMesh(0).addTriangle(Vec3i(22, 10, 7));
		mcube.getMesh(0).addTriangle(Vec3i(5, 11, 23));
		mcube.getMesh(0).addTriangle(Vec3i(23, 17, 5));
		mcube.upload();
		models_generated = true;
	}
}
