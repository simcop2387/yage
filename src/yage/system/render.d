/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.system.render;

import derelict.opengl.gl;
import derelict.opengl.glext;

import std.stdio;
import yage.core.all;
import yage.system.probe;
import yage.resource.layer;
import yage.resource.material;
import yage.resource.model;
import yage.resource.mesh;
import yage.system.constant;
import yage.scene.all;
import yage.scene.model;
import yage.scene.camera: CameraNode;

private struct Attribute2
{	char[] name;
	float[] values;	
}

/// Used for translucent polygon rendering
private struct AlphaTriangle
{	VisibleNode node;
	Model model;
	Mesh mesh;
	Material matl;
	int triangle;
	Matrix transform;
	
	Vec3f[3] vertices;	// in worldspace coordinates
	Vec3f*[3] normals;	// store pointers to these since the values aren't transformed
	Vec2f*[3] texcoords;// by the world coordinates, helps reduce size.

	//Attribute2[] attributes;
}

/**
 * As the nodes of the scene graph are traversed, those to be rendered in
 * the current frame are added to a queue.  They are then reordered for correct
 * and optimal rendering.  Translucent polygons are separated, sorted
 * and rendered in a second pass. */
class Render
{
	protected static VisibleNode[] nodes;	
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
	static void add(VisibleNode node)
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
		foreach (VisibleNode n; nodes)
		{
			glPushMatrix();
			glMultMatrixf(n.getAbsoluteTransform(true).v.ptr);
			Vec3f size = n.getSize();
			glScalef(size.x, size.y, size.z);
			n.enableLights();
			
			if (cast(ModelNode)n)
				model((cast(ModelNode)n).getModel(), n);			
			else if (cast(SpriteNode)n)
				sprite((cast(SpriteNode)n).getMaterial(), n);
			else if (cast(GraphNode)n)
				model((cast(GraphNode)n).getModel(), n);
			else if (cast(TerrainNode)n)
				model((cast(TerrainNode)n).getModel(), n);
			else if (cast(LightNode)n)
				cube(n);	// todo: render as color of light?
			else
				cube(n);
			
			glPopMatrix();
		}

		// Sort alpha (translucent) triangles
		Vec3f camera = Vec3f(getCurrentCamera().getAbsoluteTransform(true).v[12..15]);
		float triSort(AlphaTriangle a)
		{	Vec3f center = (a.vertices[0]+a.vertices[1]+a.vertices[2]).scale(.33333333333);
			return -camera.distance2(center); // distance squared is faster and values still compare the same
		}
		//radixSort(alpha, &triSort);

		// Render alpha triangles
		foreach (AlphaTriangle at; alpha)
		{	foreach (layer; at.matl.getLayers())
			{	layer.bind(at.node.getLights(), at.node.getColor());
				glBegin(GL_TRIANGLES);
				
				Vec3i triangle = at.mesh.getTriangles[at.triangle];
				
				for (int i=0; i<3; i++)
				{	
					glTexCoord2fv(at.texcoords[i].v.ptr);
					//glTexCoord2fv(at.model.getAttribute("gl_Vertex").vec3f[triangle.v[i]].ptr);
					glNormal3fv(at.normals[i].ptr);
					glVertex3fv(at.vertices[i].ptr);
					
					
				}
				glEnd();
				layer.unbind();			
			}			
		}
		/*
		for (int i=0; i<3; i++)
		{	at.vertices[i] = abs_transform*v[tri.v[i]].scale(node.getSize());
			at.texcoords[i] = &t[tri.v[i]];
			at.normals[i] = &n[tri.v[i]];
		}*/
		
		// Unbind current VBO
		if(Probe.openGL(Probe.OpenGL.VBO))
			glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);

		nodes.length = 0;
		alpha.length = 0;

		poly_count = this.poly_count;
		vertex_count = this.vertex_count;
	}

	/*
	 * Render the meshes with opaque materials and pass any meshes with materials
	 * that require blending to the queue of translucent meshes.
	 * Rotation can optionally be supplied to rotate sprites so they face the camera. 
	 * TODO: Remove dependence on node. */
	protected static void model(Model model, VisibleNode node, Vec3f rotation = Vec3f(0), bool _debug=false)
	{
		model.bind();
		Vec3f[] v = model.getAttribute("gl_Vertex").vec3f;
		Vec3f[] n = model.getAttribute("gl_Normal").vec3f;
		Vec2f[] t = model.getAttribute("gl_TexCoord").vec2f;
		Matrix abs_transform = node.getAbsoluteTransform(true);
		vertex_count += v.length;
		
		// Apply skeletal animation.
		if (cast(ModelNode)node)
		{
			if (model.getAnimated())
			{	auto mnode = cast(ModelNode)node;
				model.animateTo(mnode.getAnimationTimer().tell());
			
				// Forces an update of the node's culling radius.
				// This isn't perfect, since this is after CameraNode's culling, but a model's radius is
				// usually temporaly coherent so this takes advantage of that for the next render.
				mnode.setModel(model); 
			}
		}

		// Rotate if rotation is nonzero.
		if (rotation.length2())
		{	abs_transform = abs_transform.rotate(rotation);
			glRotatef(rotation.length()*PI_180, rotation.x, rotation.y, rotation.z);
		}

		// Loop through the meshes
		foreach (Mesh mesh; model.getMeshes())
		{
			// Bind and draw the triangles
			void drawTriangles()
			{	if (mesh.getCached()){
					glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, mesh.getTrianglesVBO());
					glDrawElements(GL_TRIANGLES, mesh.getTriangles().length*3, GL_UNSIGNED_INT, null);
				}
				else
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
					if ((l.blend != BLEND_NONE) && num==0)
						sort = true;

					// If not translucent
					if (!sort)
					{	l.bind(node.getLights(), node.getColor(), model);
					drawTriangles();
						l.unbind();

					} else
					{
						// Add to translucent
						foreach (int index, Vec3i tri; mesh.getTriangles())						
						{	AlphaTriangle at;
							for (int i=0; i<3; i++)
							{	at.vertices[i] = abs_transform*v[tri.v[i]].scale(node.getSize());
								at.texcoords[i] = &t[tri.v[i]];
								at.normals[i] = &n[tri.v[i]];
							}
							// New
							at.node 	= node;
							at.model	= model;
							at.mesh		= mesh;
							at.matl     = matl;
							at.triangle = index;						
							
							alpha ~= at;
					}	}
					num++;
				}
			}
			else // render with no material
				drawTriangles();

			
			if (_debug)
			{	// Draw normals
				glColor3f(0, 1, 1);
				glDisable(GL_LIGHTING);
				foreach (Vec3i tri; mesh.getTriangles())
				{	for (int i=0; i<3; i++)
					{	Vec3f vertex = v[tri.v[i]];
						Vec3f normal = n[tri.v[i]];						
						glBegin(GL_LINES);
							glVertex3fv(vertex.ptr);
							glVertex3fv((vertex+normal.scale(.5)).ptr);
						glEnd();
				}	}	
				
				glEnable(GL_LIGHTING);
				glColor3f(1, 1, 1);
			}			
		}
		
		// Draw joints
		if (_debug)
		{	glDisable(GL_DEPTH_TEST);
			glDisable(GL_LIGHTING);
			foreach (cb; model.getJoints())
			{
				Vec3f vec, parentvec;
				vec = vec.transform(cb.transformAbs);
			
				// Joint connections.
				if (cb.parent)
				{	parentvec = parentvec.transform(cb.parent.transformAbs);	
					glLineWidth(2.0);
					glColor3f(0.0, 1.0, 0.0);
					glBegin(GL_LINES);
					glVertex3fv(vec.ptr);
					glVertex3fv(parentvec.ptr);
					glEnd();
				}
	
				// Joints
				glPointSize(8.0);
				glColor3f(1.0, 0, 1.0);
				glBegin(GL_POINTS);
					glVertex3fv(vec.ptr);
				glEnd();
				
				glLineWidth(1.0);
				glPointSize(1.0);
				glColor3f(1.0, 1.0, 1.0);
			}
			glEnable(GL_LIGHTING);
			glEnable(GL_DEPTH_TEST);
		}
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
	protected static void cube(VisibleNode node)
	{	model(mcube, node);
		// (cast(LightNode)n).getDiffuse().add((cast(LightNode)n).getAmbient())
	}

	// Render a sprite
	protected static void sprite(Material material, VisibleNode node)
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
