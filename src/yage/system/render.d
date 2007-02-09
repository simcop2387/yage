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


/// Used for translucent polygon rendering
private struct AlphaTriangle
{	Vec3f[3] vertices;	// in worldspace coordinates
	Vec3f*[3] normals;	// store pointers to these since the values aren't transformed
	Vec2f*[3] texcoords;// by the world coordinates, helps reduce size.
	Layer layer;
	LightNode[] lights;
	Vec4f color;
	int order;	// order to draw if the same distance as another polygon
				// this is commonly needed for polygons from different layers of the same mesh.
				// Useless, since they should already be in the order they're added and
				// because radix preserves order
}

/**
 * As the nodes of the scene graph are traversed, those to be rendered in
 * the current frame are added to a queue.  They are then reordered for correct
 * and optimal rendering.  Translucent polygons are separated, sorted
 * and rendered in a second pass. */
class Render
{

	protected static Node[] nodes;			// Linking errors when created as a Horde :(
	protected static Horde!(AlphaTriangle) alpha;

	// Basic shapes
	protected static Model mcube;
	protected static Model msprite;

	protected static bool models_generated = false;
	protected static CameraNode current_camera;


	/// Add a node to the queue for rendering.
	static void add(Node node)
	{	//if (nodes is null)
		//	nodes = new Horde!(Node);
		if (alpha is null)
			 alpha = new Horde!(AlphaTriangle);
		nodes ~= node;
	}

	/// Render everything in the queue
	static void all()
	{
		if (!models_generated)
			generate();

		// Loop through all nodes in the queue and render them
		foreach (Node n; nodes)
		{
			glPushMatrix();
			glMultMatrixf(n.getAbsoluteTransformPtr().v.ptr);
			glScalef(n.getScale().x, n.getScale().y, n.getScale().z);
			n.enableLights();

			switch(n.getType())
			{	case "yage.node.model.ModelNode":
					model((cast(ModelNode)n).getModel(), n);
					break;
				case "yage.node.sprite.SpriteNode":
					sprite((cast(SpriteNode)n).getMaterial(), n);
					break;
				case "yage.node.graph.GraphNode":
					model((cast(GraphNode)n).getModel(), n);
					break;
				case "yage.node.terrain.TerrainNode":
					model((cast(TerrainNode)n).getModel(), n);
					break;
				case "yage.node.terrain.LightNode":
					cube(n);	// todo: render as color of light?
					break;
				default:
					cube(n);
			}
			glPopMatrix();
		}

		// Sort alpha (translucent) triangles
		Vec3f camera = getCurrentCamera().getAbsolutePosition();
		float triSort(AlphaTriangle a)
		{	Vec3f center = (a.vertices[0]+a.vertices[1]+a.vertices[2]).scale(.33333333333);
			return -camera.distance2(center); // distance squared is faster and values still compare the same
		}
		alpha.sortType!(float).radix(&triSort, true, true);

		// Render alpha triangles
		foreach (AlphaTriangle a; alpha.array())
		{	a.layer.apply(a.lights, a.color);

			glBegin(GL_TRIANGLES);
				for (int i=0; i<3; i++)
				{	glTexCoord2fv(a.texcoords[i].v.ptr);
					glNormal3fv(a.normals[i].ptr);
					glVertex3fv(a.vertices[i].ptr);
				}

			glEnd();
			a.layer.unApply();
		}

		nodes.length = 0;
		alpha.reserve(alpha.length);
		alpha.length = 0;

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
	protected static void cube(Node node)
	{	model(mcube, node);
		// (cast(LightNode)n).getDiffuse().add((cast(LightNode)n).getAmbient())
	}

	/**
	 * Render the meshes with opaque materials and pass any meshes with materials
	 * that require blending to the queue of translucent meshes. */
	protected static void model(Model model, Node node)
	{
		model.bind();
		Vec3f[] v = model.getVertices();
		Vec3f[] n = model.getNormals();
		Vec2f[] t = model.getTexCoords();
		Matrix abs_transform = node.getAbsoluteTransform();

		// Loop through the meshes
		foreach (Mesh mesh; model.getMeshes())
		{
			// Bind and draw the triangles
			void draw()
			{	if (model.getCached())
				{	glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, mesh.getTrianglesVBO());
					glDrawElements(GL_TRIANGLES, mesh.getTriangles().length*3, GL_UNSIGNED_INT, null);
					// glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, 0);
				}else
					glDrawElements(GL_TRIANGLES, mesh.getTriangles().length*3, GL_UNSIGNED_INT, mesh.getTriangles().ptr);
			}

			Material matl = mesh.getMaterial();
			if (matl !is null)
			{	bool sort = false;

				// Loop through each layer
				foreach (Layer l; matl.getLayers().array())
				{
					// Sort every l including and after the first blended one.
					if (l.blend != LAYER_BLEND_NONE)
						sort = true;

					// If not translucent
					if (!sort)
					{	l.apply(node.getLights(), node.getColor());
						draw();
						l.unApply();
					} else
					{	//l.apply(lights, color);
						//draw();
						//l.unApply();

						foreach (Vec3i tri; mesh.getTriangles())
						// Add to translucent
						{	AlphaTriangle at;
							for (int i=0; i<3; i++)
							{	at.vertices[i] = abs_transform*v[tri.v[i]].scale(node.getScale());
								at.texcoords[i] = &t[tri.v[i]];
								at.normals[i] = &n[tri.v[i]];
							}
							at.layer = l;
							at.color = node.getColor();
							alpha.add(at);
						}
					}
				}
			}
			else // render with no material
				draw();
		}
	}

	/// Render a sprite
	protected static void sprite(Material material, Node node)
	{
		// Rotate so that sprite always faces camera
		Vec3f axis = current_camera.getAbsoluteRotation();
		float angle = axis.length();
		axis = axis.scale(1/angle);
		glRotatef(angle*57.295779513, axis.x, axis.y, axis.z);

		//Matrix m = node.getAbsoluteTransform();
		node.rotate(current_camera.getAbsoluteRotation());

		// Set material and draw as model
		msprite.getMeshes()[0].setMaterial(material);
		model(msprite, node);

		node.rotate(-current_camera.getAbsoluteRotation());

	}


	/**
	 * Generate models used for various Nodes (like the quad for SpriteNodes). */
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
