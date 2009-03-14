/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.system.graphics.render;

import tango.math.Math;
import tango.io.Stdout;

import derelict.opengl.gl;
import derelict.opengl.glext;

import yage.core.all;
import yage.system.graphics.probe;
import yage.resource.geometry;
import yage.resource.layer;
import yage.resource.material;
import yage.resource.model;
import yage.resource.lazyresource;
import yage.system.constant;
import yage.scene.all;
import yage.scene.light;
import yage.scene.model;
import yage.scene.camera: CameraNode;
import yage.scene.visible;

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
	Vec2f*[3] texcoords;// by the world coordinates, helps reduce size. (this is incorrect for normals)

	//Attribute2[] attributes;
}

/**
 * Stores statistics about the last render operation.
 * TODO: Finish this. */
struct RenderStatistics
{
	int vertexCount;
	int triangleCount;
	
	//double vertexBufferTime=0;		/// time spend binding vertex buffers
	//double lightCalculationTime=0;	/// time spent calculating which lights affect which objects.
	//double materialStateTime=0;		/// time spent changing opengl states to render materials
	//double lightStateTime=0;			/// time spent changing opengl states to apply lights
	//double totalTime=0;
	
	void reset()
	{	vertexCount = triangleCount = 0;
	}
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
	static RenderStatistics statistics;
	
	/// Add a node to the queue for rendering.
	static void add(VisibleNode node)
	{	nodes ~= node;
	}

	/// Render everything in the queue and empty it.
	static void all(inout uint poly_count, inout uint vertex_count)
	{
		statistics.reset();
		
		LazyResourceManager.processQueue();
		//VertexBuffer!(Vec3f).collect();
		
		this.poly_count = poly_count;
		this.vertex_count = vertex_count;

		if (!models_generated)
			generate();

		int num_lights = Probe.openGL(Probe.OpenGL.MAX_LIGHTS);
		LightNode[] all_lights = current_camera.getScene().getLights().values; // creates garbage, but this copy also prevents threading issues.
		
		// Loop through all nodes in the queue and render them
		foreach (VisibleNode n; nodes)
		{	synchronized (n)
			{	if (!n.getScene()) // was recently removed from its scene.
					continue;
			
				// Transform
				glPushMatrix();
				glMultMatrixf(n.getAbsoluteTransform(true).v.ptr);
				Vec3f size = n.getSize();
				glScalef(size.x, size.y, size.z);
				
				// Enable the appropriate lights
				auto lights = n.getLights(all_lights, num_lights);
				for (int i=0; i<num_lights; i++)
					glDisable(GL_LIGHT0+i);
				for (int i=0; i<min(num_lights, lights.length); i++)
					light(lights[i], i);
				
				
				// Render
				if (cast(ModelNode)n)
					model((cast(ModelNode)n).getModel(), n);			
				else if (cast(SpriteNode)n)
					sprite((cast(SpriteNode)n).getMaterial(), n);
				//else if (cast(GraphNode)n)
				//	model((cast(GraphNode)n).getModel(), n);
				//else if (cast(TerrainNode)n)
				//	model((cast(TerrainNode)n).getModel(), n);
				//else if (cast(LightNode)n)
				//	cube(n);	// todo: render as color of light?
				//else
				//	cube(n);
				
				glPopMatrix();
			}
		}

		// Sort alpha (translucent) triangles
		Vec3f camera = Vec3f(getCurrentCamera().getAbsoluteTransform(true).v[12..15]);
		
		radixSort(alpha, true, (AlphaTriangle a)
		{	Vec3f center = (a.vertices[0]+a.vertices[1]+a.vertices[2]).scale(1/3);
			return -camera.distance2(center); // distance squared is faster and values still compare the same
		});
		
		// Render alpha triangles
		foreach (AlphaTriangle at; alpha)
		{	foreach (layer; at.matl.getLayers())
			{	layer.bind(at.node.getLights(), at.node.getColor());
				glBegin(GL_TRIANGLES);
				
				Vec3i triangle = (cast(Vec3i[])(at.mesh.getTriangles().getData()))[at.triangle];
				
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

	/**
	 * Get / set the current (or last) camera that is/was rendering a scene.
	 * This is mostly for internal use. */
	static CameraNode getCurrentCamera()
	{	return current_camera;
	}
	static void setCurrentCamera(CameraNode camera) /// ditto;
	{	current_camera = camera;
	}
	
	/*
	 * Enable this light as the given light number and apply its properties.
	 * This function is used internally by the engine and should not be called manually or exported. */
	static void light(LightNode light, int num)
	in { assert (num<=Probe.openGL(Probe.OpenGL.MAX_LIGHTS));
	} body
	{
		glPushMatrix();
		glLoadMatrixf(current_camera.getInverseAbsoluteMatrix().v.ptr); // required for spotlights.

		// Set position and direction
		glEnable(GL_LIGHT0+num);
		auto type = light.getLightType();
		Matrix transform_abs = light.getAbsoluteTransform(true);
		
		Vec4f pos;
		pos.v[0..3] = transform_abs.v[12..15];
		pos.v[3] = type==LightNode.Type.DIRECTIONAL ? 0 : 1;
		glLightfv(GL_LIGHT0+num, GL_POSITION, pos.v.ptr);

		// Spotlight settings
		float angle = type == LightNode.Type.SPOT ? light.getSpotAngle() : 180;
		glLightf(GL_LIGHT0+num, GL_SPOT_CUTOFF, angle);
		if (type==LightNode.Type.SPOT)
		{	glLightf(GL_LIGHT0+num, GL_SPOT_EXPONENT, light.getSpotExponent());
			// transform_abs.v[8..11] is the opengl default spotlight direction (0, 0, 1),
			// rotated by the node's rotation.  This is opposite the default direction of cameras
			glLightfv(GL_LIGHT0+num, GL_SPOT_DIRECTION, transform_abs.v[8..11].ptr);
		}

		// Light material properties
		glLightfv(GL_LIGHT0+num, GL_AMBIENT, light.getAmbient().vec4f.ptr);
		glLightfv(GL_LIGHT0+num, GL_DIFFUSE, light.getDiffuse().vec4f.ptr);
		glLightfv(GL_LIGHT0+num, GL_SPECULAR, light.getSpecular().vec4f.ptr);

		// Attenuation properties
		glLightf(GL_LIGHT0+num, GL_CONSTANT_ATTENUATION, 0); // requires a 1 but should be zero?
		glLightf(GL_LIGHT0+num, GL_LINEAR_ATTENUATION, 0);
		glLightf(GL_LIGHT0+num, GL_QUADRATIC_ATTENUATION, light.getQuadraticAttenuation());

		glPopMatrix();
	}
	
	/**
	 * Bind (and if necessary upload to video memory) a vertex buffer
	 * Params:
	 *     type = A vertex buffer type constant defined in Geometry or Mesh. */
	static void vertexBufferBind(char[] type, IVertexBuffer vb)
	{	uint id = vb.getId();
		int vbo = Probe.openGL(Probe.OpenGL.VBO);
		uint vbo_type = type==Mesh.TRIANGLES ? 
				GL_ELEMENT_ARRAY_BUFFER_ARB :
				GL_ARRAY_BUFFER_ARB;
		
		// Bind vbo and update data if necessary.
		if (vbo)
		{	glBindBufferARB(vbo_type, id);
			if (vb.getDirty())
			{	glBufferDataARB(vbo_type, vb.getSizeInBytes(), vb.ptr, GL_STATIC_DRAW_ARB);
				vb.setDirty(false);
			}
		}
		
		// Bind the data
		switch (type)
		{
			case Geometry.VERTICES:
				glVertexPointer(vb.getComponents(), GL_FLOAT, 0, vbo ? null : vb.ptr);
				break;
			case Geometry.NORMALS:
				assert(vb.getComponents() == 3); // normals are always Vec3
				glNormalPointer(GL_FLOAT, 0, vbo ? null : vb.ptr);
				break;
			case Geometry.TEXCOORDS0:
				glTexCoordPointer(vb.getComponents(), GL_FLOAT, 0, vbo ? null : vb.ptr);
				break;
			case Mesh.TRIANGLES: // no binding necessary
				break;
			default:
				// TODO: Support custom types.
				break;
		}		
	}
	
	/**
	 * Draw the contents of a vertex buffer, such as a buffer of triangle indices. */
	static void vertexBufferDraw(char[] type, IVertexBuffer triangles=null)
	{	int vbo = Probe.openGL(Probe.OpenGL.VBO);
		if (triangles)
		{	vertexBufferBind(type, triangles);
			glDrawElements(GL_TRIANGLES, triangles.length*3, GL_UNSIGNED_INT, vbo ? null : triangles.ptr);
		}
		// else
		//	glDrawArrays();
	}
	
	static void geometry(Geometry geometry)
	{
		if (!geometry.hasAttribute(Geometry.VERTICES))
			return;
		
		// Bind each vertx buffer
		foreach (name, attrib; geometry.getAttributes())
		{	vertexBufferBind(name, attrib);
			if (name==Geometry.VERTICES)
				statistics.vertexCount += attrib.length;
		}
		
		// Loop through the meshes		
		foreach (mesh; geometry.getMeshes())
		{	if (mesh.getMaterial() !is null) // Must have a material to render
			{	foreach (Layer l; mesh.getMaterial().getLayers()) // Loop through each layer (rendering pass)
				{	l.bind();
					vertexBufferDraw(Mesh.TRIANGLES, mesh.getTriangles());
					l.unbind();
			}	}
		
			statistics.triangleCount += mesh.getTriangles().length;
		}
	}
	
	/*
	 * Render the meshes with opaque materials and pass any meshes with materials
	 * that require blending to the queue of translucent meshes.
	 * Rotation can optionally be supplied to rotate sprites so they face the camera. 
	 * TODO: Remove dependence on node. 
	 * TODO: Make all vbo's optional.
	 * TODO: Rewrite this around the simpler Render.geometry */
	static void model(Model model, VisibleNode node, Vec3f rotation = Vec3f(0), bool _debug=false)
	{	
		if (!model.hasAttribute(Geometry.VERTICES))
			return;
		
		foreach (name, attrib; model.getAttributes())
			vertexBufferBind(name, attrib);		
		
		Vec3f[] v = cast(Vec3f[])model.getVertices().getData();
		Vec3f[] n = cast(Vec3f[])model.getNormals().getData();
		Vec2f[] t = cast(Vec2f[])model.getTexCoords0().getData();
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
						vertexBufferDraw(Mesh.TRIANGLES, mesh.getTriangles());
						l.unbind();
					} else
					{						
						// Add to translucent
						foreach (int index, Vec3i tri; cast(Vec3i[])mesh.getTriangles().getData())						
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
						}	
					}
					num++;
				}
			}
			else // render with no material
			//	drawTriangles();
				vertexBufferDraw(Mesh.TRIANGLES, mesh.getTriangles());
				
			
			if (_debug)
			{	// Draw normals
				glColor3f(0, 1, 1);
				glDisable(GL_LIGHTING);
				foreach (Vec3i tri; cast(Vec3i[])mesh.getTriangles().getData())
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

	
	// Render a cube
	protected static void cube(VisibleNode node)
	{	model(mcube, node);
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
		msprite.setVertices([Vec3f(-1,-1, 0), Vec3f( 1,-1, 0), Vec3f( 1, 1, 0), Vec3f(-1, 1, 0)]);
		msprite.setNormals([Vec3f( 0, 0, 1), Vec3f( 0, 0, 1), Vec3f( 0, 0, 1), Vec3f( 0, 0, 1)]);
		msprite.setTexCoords0([Vec2f(0, 1), Vec2f(1, 1), Vec2f(1, 0), Vec2f(0, 0)]);
		msprite.setMeshes([new Mesh(null, [Vec3i(0, 1, 2), Vec3i(2, 3, 0)])]);

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
		mcube.setVertices(vertices);
		mcube.setNormals(normals);
		mcube.setTexCoords0(texcoords);

		Vec3i[] triangles = [
			Vec3i(0,  6,  9), Vec3i( 9,  3, 0), Vec3i( 1,  4, 16), Vec3i(16, 13, 1),
			Vec3i(2, 14, 20), Vec3i(20,  8, 2), Vec3i(12, 15, 21), Vec3i(21, 18, 12),
			Vec3i(7, 19, 22), Vec3i(22, 10, 7), Vec3i( 5, 11, 23), Vec3i(23, 17, 5)];
		mcube.setMeshes([new Mesh(null, triangles)]);
		
		models_generated = true;
	}
}
