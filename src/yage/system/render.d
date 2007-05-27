/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.system.render;

import derelict.opengl.gl;
import derelict.opengl.glext;

import std.stdio;
import yage.core.all;
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
	protected static Node[] nodes;	
	protected static AlphaTriangle[] alpha;

	// Basic shapes
	protected static Model mcube;
	protected static Model msprite;

	protected static bool models_generated = false;
	protected static CameraNode current_camera;

	// Stats
	protected static uint poly_count;
	protected static uint vertex_count;


	/// Add a node to the queue for rendering.
	static void add(Node node)
	{	nodes ~= node;
	}

	/// Render everything in the queue
	static void all(inout uint poly_count, inout uint vertex_count)
	{
		this.poly_count = poly_count;
		this.vertex_count = vertex_count;

		if (!models_generated)
			generate();

		// Loop through all nodes in the queue and render them
		foreach (Node n; nodes)
		{
			glPushMatrix();
			glMultMatrixf(n.getAbsoluteTransform(true).v.ptr);
			glScalef(n.getScale().x, n.getScale().y, n.getScale().z);
			n.enableLights();

			switch(n.getType())
			{	case "yage.node.model.ModelNode":
					model((cast(ModelNode)n).getModel(), n);
					//writefln((cast(ModelNode)n).getModel().getSource());
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
		Vec3f camera = Vec3f(getCurrentCamera().getAbsoluteTransform(true).v[12..15]);
		float triSort(AlphaTriangle a)
		{	Vec3f center = (a.vertices[0]+a.vertices[1]+a.vertices[2]).scale(.33333333333);
			return -camera.distance2(center); // distance squared is faster and values still compare the same
		}
		//alpha.sortType!(float).radix(&triSort, true, true);
		sort(alpha, &triSort);

		// Render alpha triangles
		foreach (AlphaTriangle a; alpha)
		{	a.layer.bind(a.lights, a.color);
			glBegin(GL_TRIANGLES);
				for (int i=0; i<3; i++)
				{	glTexCoord2fv(a.texcoords[i].v.ptr);
					glNormal3fv(a.normals[i].ptr);
					glVertex3fv(a.vertices[i].ptr);
				}
			glEnd();
			a.layer.unbind();
		}

		nodes.length = 0;
		//yage.core.array.reserve(alpha, alpha.length);
		alpha.length = 0;

		poly_count = this.poly_count;
		vertex_count = this.vertex_count;
	}


	/// Get the current (or last) camera that is/was rendering a scene.
	static CameraNode getCurrentCamera()
	{	return current_camera;
	}

	/// Set the current camera for rendering.
	static void setCurrentCamera(CameraNode camera)
	{	current_camera = camera;
	}

	// Render a cube
	protected static void cube(Node node)
	{	model(mcube, node);
		// (cast(LightNode)n).getDiffuse().add((cast(LightNode)n).getAmbient())
	}

	/*
	 * Render the meshes with opaque materials and pass any meshes with materials
	 * that require blending to the queue of translucent meshes.
	 * Rotation can optionally be supplied to rotate sprites so they face the camera. */
	protected static void model(Model model, Node node, Vec3f rotation = Vec3f(0))
	{
		model.bind();
		Vec3f[] v = model.getVertices();
		Vec3f[] n = model.getNormals();
		Vec2f[] t = model.getTexCoords();
		Matrix abs_transform = node.getAbsoluteTransform(true);
		vertex_count += model.getVertices().length;

		// Rotate by rotation, if nonzero
		if (rotation.length2())
		{	abs_transform = abs_transform.rotate(rotation);
			glRotatef(rotation.length()*57.295779513, rotation.x, rotation.y, rotation.z);
		}

		// Loop through the meshes
		foreach (Mesh mesh; model.getMeshes())
		{
			// Bind and draw the triangles
			void draw()
			{	if (mesh.getCached())
				{	glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, mesh.getTrianglesVBO());
					glDrawElements(GL_TRIANGLES, mesh.getTriangles().length*3, GL_UNSIGNED_INT, null);
				}else
					glDrawElements(GL_TRIANGLES, mesh.getTriangles().length*3, GL_UNSIGNED_INT, mesh.getTriangles().ptr);
			}

			poly_count += mesh.getTriangles().length;
			Material matl = mesh.getMaterial();
			if (matl !is null)
			{
				// Loop through each layer
				int num=0;
				bool sort = false;
				foreach (Layer l; matl.getLayers())
				{
					// Sorting rules:
					// If the first layer has blending, sort it and every layer
					// otherwise, sort none of them
					if (l.blend != BLEND_NONE && num==0)
						sort = true;

					// If not translucent
					if (!sort)
					{	l.bind(node.getLights(), node.getColor(), model);
						draw();
						l.unbind();

					} else
					{
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
							alpha ~= at;
						}
					}
					num++;
				}

				/*
				// Draw normals
				foreach (Vec3i tri; mesh.getTriangles())
				// Add to translucent
				{	AlphaTriangle at;
					for (int i=0; i<3; i++)
					{	Vec3f vertex = v[tri.v[i]];
						Vec3f normal = n[tri.v[i]];
						glColor3f(0, 1, 1);
						glDisable(GL_LIGHTING);
						glBegin(GL_LINES);
							glVertex3fv(vertex.ptr);
							glVertex3fv((vertex+normal.scale(.01)).ptr);
						glEnd();
						glEnable(GL_LIGHTING);
						glColor3f(1, 1, 1);
					}
				}*/
			}
			else // render with no material
				draw();
		}
	}

	// Render a sprite
	protected static void sprite(Material material, Node node)
	{	msprite.getMeshes()[0].setMaterial(material);
		model(msprite, node, current_camera.getAbsoluteTransform(true).toAxis());
	}


	// Generate models used for various Nodes (like the quad for SpriteNodes).
	protected static void generate()
	{	// Sprite
		msprite = new Model();
		msprite.setAttribute("gl_Vertex",   [Vec3f(-1,-1, 0), Vec3f( 1,-1, 0), Vec3f( 1, 1, 0), Vec3f(-1, 1, 0)]);
		msprite.setAttribute("gl_Normal",   [Vec3f( 0, 0, 1), Vec3f( 0, 0, 1), Vec3f( 0, 0, 1), Vec3f( 0, 0, 1)]);
		msprite.setAttribute("gl_TexCoord", [Vec2f(0, 1), Vec2f(1, 1), Vec2f(1, 0), Vec2f(0, 0)]);
		msprite.setMeshes([new Mesh(null, [Vec3i(0, 1, 2), Vec3i(2, 3, 0)])]);
		//msprite.upload();

		// Cube (in as little code as possible :)
		mcube = new Model();
		Vec3f[] vertices, normals;
		Vec2f[] texcoords;
		for (int x=-1; x<=1; x+=2)
		{	for (int y=-1; y<=1; y+=2)
			{	for (int z=-1; z<=1; z+=2)
				{	vertices ~= [Vec3f(x, y, z), Vec3f(x, y, z), Vec3f(x, y, z)];
					normals  ~= [Vec3f(x, 0, 0), Vec3f(0, y, 0), Vec3f(0, 0, z)];
					texcoords~= [Vec2f(y*.5+.5, z*.5+.5), Vec2f(x*.5+.5, z*.5+.5), Vec2f(x*.5+.5, y*.5+.5)];
		}	}	}
		mcube.setAttribute("gl_Vertex", vertices);
		mcube.setAttribute("gl_TexCoord", texcoords);
		mcube.setAttribute("gl_Normal", normals);

		Vec3i[] triangles = [
			Vec3i(0,  6,  9), Vec3i( 9,  3, 0), Vec3i( 1,  4, 16), Vec3i(16, 13, 1),
			Vec3i(2, 14, 20), Vec3i(20,  8, 2), Vec3i(12, 15, 21), Vec3i(21, 18, 12),
			Vec3i(7, 19, 22), Vec3i(22, 10, 7), Vec3i( 5, 11, 23), Vec3i(23, 17, 5)];
		Mesh mesh = new Mesh();
		mesh.setTriangles(triangles);
		mcube.setMeshes([mesh]);
		mcube.setMeshes([new Mesh()]);
		models_generated = true;
	}
}
