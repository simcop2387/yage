/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:	   Eric Poggel
 * License:	   <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.graphics.render;

import tango.math.Math;

import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;
import derelict.sdl.sdl;

import yage.core.all;
import yage.gui.surface;
import yage.gui.style;
import yage.resource.geometry;
import yage.resource.image;
import yage.resource.material;
import yage.resource.model;
import yage.resource.texture;
import yage.scene.all;
import yage.scene.light;
import yage.scene.model;
import yage.scene.camera: CameraNode;
import yage.scene.visible;
import yage.system.window;
import yage.system.system;
import yage.system.graphics.probe;
import yage.system.graphics.api.api;
import yage.system.graphics.api.opengl;
import yage.system.log;

// Used for translucent polygon rendering
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
}

/**
 * Statistics about the last render operation.*/
struct RenderStatistics
{
	int nodeCount; ///
	int vertexCount; ///
	int triangleCount; ///
	
	///
	RenderStatistics opAdd(RenderStatistics rhs)
	{	RenderStatistics result = *this;
		return result += rhs;
	}
	
	///
	RenderStatistics opAddAssign(RenderStatistics rhs)
	{	nodeCount += rhs.nodeCount;
		vertexCount += rhs.vertexCount;
		triangleCount += rhs.triangleCount;		
		return *this;
	}
}

/**
 * As the nodes of the scene graph are traversed, those to be rendered in
 * the current frame are added to a queue.  They are then reordered for correct
 * and optimal rendering.  Translucent polygons are separated, sorted
 * and rendered in a second pass. */
struct Render
{
	protected static OpenGL graphics; // TODO: Replace with GraphicsAPI when interface is more finalized.
	
	protected static Array!(VisibleNode) visibleNodes;
	protected static AlphaTriangle[] alpha;

	protected static bool cleared; // if false, the color buffer need to be cleared before drawing?


	/**
	 * Generate build-in models (such as the sprite quad). */
	static this()
	{
		graphics = new OpenGL();
			
		/*
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
		*/
	}
	
	/**
	 * Cleanup no-longer used graphics resources. */
	static void cleanup(int age=3600)
	{	graphics.cleanup(age);
	}

	/**
	 * Complete rendering and swap the back buffer to the front buffer. */
	static void complete()
	{	SDL_GL_SwapBuffers();
		cleared = false;
	}

	/*
	 * deprecated
	 * Render the meshes with opaque materials and pass any meshes with materials
	 * that require blending to the queue of translucent meshes.
	 * Rotation can optionally be supplied to rotate sprites so they face the camera. */
	deprecated static RenderStatistics model(Model model, VisibleNode node, Vec3f rotation = Vec3f(0), bool _debug=false)
	{	
		RenderStatistics result;
		/*
		if (!model.getAttribute(Geometry.VERTICES))
			return result;
		
		Vec3f[] v = cast(Vec3f[])model.getAttribute(Geometry.VERTICES);
		Vec3f[] n;
		if (model.getAttribute(Geometry.NORMALS))
			n = cast(Vec3f[])model.getAttribute(Geometry.NORMALS);
		Vec2f[] t;
		if (model.getAttribute(Geometry.TEXCOORDS0))
			t = cast(Vec2f[])model.getAttribute(Geometry.TEXCOORDS0);
		

		Matrix abs_transform = node.getAbsoluteTransform(true);
		result.vertexCount += v.length;
		
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
		
		foreach (type, attrib; model.getVertexBuffers())
			graphics.bindVertexBuffer(attrib, type);

		// Loop through the meshes		
		foreach (Mesh mesh; model.getMeshes())
		{
			result.triangleCount += mesh.getTrianglesVertexBuffer().length;
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
					{	graphics.bindLayer(l, node.getLights(), node.getColor(), model);
						graphics.drawVertexBuffer(mesh.getTrianglesVertexBuffer(), Mesh.TRIANGLES);
						graphics.bindLayer(null); // can this be moved outside the loop?
					} else
					{						
						// Add to translucent.  This may need to be rewritten at some point.
						foreach (int index, Vec3i tri; mesh.getTriangles())						
						{	AlphaTriangle at;
							for (int i=0; i<3; i++)
							{	at.vertices[i] = abs_transform*v[tri.v[i]].scale(node.getSize());
								if (t.length)
									at.texcoords[i] = &t[tri.v[i]];
								if (n.length)
									at.normals[i] = &n[tri.v[i]];
							}
							at.node 	= node;
							at.model	= model;
							at.mesh		= mesh;
							at.matl	 = matl;
							at.triangle = index;		
							
							alpha ~= at;
						}	
					}
					num++;
				}
			}
			else // render with no material
				graphics.drawVertexBuffer(mesh.getTrianglesVertexBuffer(), Mesh.TRIANGLES);
				
			
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
		*/
		return result;
	}

	/**
	 * Render a camera's view to target.
	 * The previous contents of target are first cleared.
	 * Params:
	 *	 camera = Render what the camera sees.
	 *	 target = Render to this target.  TODO: Convert to IRenderTarget.
	 * Returns:
	 *	 A struct containing rendering statistics */
	static RenderStatistics scene(CameraNode camera, IRenderTarget target)
	{		
		/*
		 * Render an array of nodes to the current rendering target, saving
		 * any alpha triangles to the end and then rendering them.
		 * Params:
		 *	 nodes = Array of nodes to render.
		 * Returns: A struct with statistics about this rendering call. */
		RenderStatistics drawNodes(VisibleNode[] nodes)
		{
			RenderStatistics result;
			result.nodeCount = nodes.length;
			CameraNode currentCamera = graphics.Current.camera;

			int num_lights = Probe.feature(Probe.Feature.MAX_LIGHTS);
			LightNode[] all_lights = currentCamera.getScene().getLights().values; // creates garbage, but this copy also prevents threading issues.
			
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
					
					// Enable the lights that affect this node
					// TODO: This seems inefficient
					auto lights = n.getLights(all_lights, num_lights);
					for (int i=lights.length; i<num_lights; i++)
						glDisable(GL_LIGHT0+i);
					for (int i=0; i<min(num_lights, lights.length); i++)
						graphics.bindLight(lights[i], i);
					
					// Render
					if (cast(ModelNode)n)
						result += graphics.drawModel((cast(ModelNode)n).getModel());			
					else if (cast(SpriteNode)n)
						result += graphics.drawSprite((cast(SpriteNode)n).getMaterial());
					
					glPopMatrix();
				}
			}
			
			// Sort alpha (translucent) triangles
			Vec3f camera = Vec3f(currentCamera.getAbsoluteTransform(true).v[12..15]);
			radixSort(alpha, true, (AlphaTriangle a)
			{	Vec3f center = (a.vertices[0]+a.vertices[1]+a.vertices[2]).scale(1/3);
				return -camera.distance2(center); // distance squared is faster and values still compare the same
			});
			/*
			// Render alpha triangles
			foreach (AlphaTriangle at; alpha)
			{	foreach (layer; at.matl.getLayers())
				{	graphics.bindLayer(layer, at.node.getLights(), at.node.getColor());
					glBegin(GL_TRIANGLES);
					
					Vec3i triangle = at.mesh.getTriangles()[at.triangle];
					
					for (int i=0; i<3; i++)
					{	
						glTexCoord2fv(at.texcoords[i].v.ptr);
						//glTexCoord2fv(at.model.getAttribute("gl_Vertex").vec3f[triangle.v[i]].ptr);
						glNormal3fv(at.normals[i].ptr);
						glVertex3fv(at.vertices[i].ptr);
					}
					glEnd();
					graphics.bindLayer(null); // can this be moved outside the loop?
			}	}
			*/

			// Unbind current VBO
			graphics.bindVertexBuffer(null);
			alpha.length = 0;
			return result;
		}
		
		// Allows one scene to act as the skybox for another.
		RenderStatistics skyboxRecurse(CameraNode camera, IRenderTarget target, Scene scene=null)
		{			
			RenderStatistics result;			
			if (!scene)
				scene = camera.getScene();
			if (!scene)
				throw new GraphicsException("Camera must be added to a scene before rendering.");
			
			// start reading from the most recently updated set of buffers.
			scene.swapTransformRead();
			
			graphics.bindCamera(camera, target.getWidth(), target.getHeight());	
			glLoadIdentity();
			
			// Precalculate the inverse of the Camera's absolute transformation Matrix.
			camera.inverse_absolute = camera.getAbsoluteTransform(true).inverse();
			if (scene == camera.scene)
				glMultMatrixf(camera.inverse_absolute.v.ptr);
			else
			{	Vec3f axis = camera.inverse_absolute.toAxis();
				glRotatef(axis.length()*57.295779513, axis.x, axis.y, axis.z);
			}
			
			// Recurse through skyboxes
			if (scene.skyBox)
			{	
				glPushMatrix();
				skyboxRecurse(camera, target, scene.skyBox);
				glClear(GL_DEPTH_BUFFER_BIT);
				glPopMatrix();
			}
			
			// Apply scene state and clear background if necessary.
			graphics.bindScene(scene);
			if (!scene.skyBox)
			{	if (!cleared) // reset everyting the first time.
				{	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
					cleared = true;
				}
				else
					glClear(GL_DEPTH_BUFFER_BIT); // reset depth buffer for drawing after a skybox
			}
				
			camera.buildFrustum(scene);
			visibleNodes = camera.getVisibleNodes(scene, visibleNodes);
			result += drawNodes(visibleNodes.data);
			visibleNodes.reserve = visibleNodes.length;
			visibleNodes.length = 0;
	
			return result;
		}		
		
		graphics.bindRenderTarget(target);
		auto result = skyboxRecurse(camera, target);
		graphics.bindRenderTarget(null);
		cleanup();		
		return result;
	}
	
	
	/// Render a surface
	static void surface(Surface surface, IRenderTarget target=null)
	{	
		graphics.bindRenderTarget(target);
		
		glDisableClientState(GL_NORMAL_ARRAY);
		glDisable(GL_LIGHTING); // TODO: Have surface materials be 100% emissive instead.
		glDisable(GL_DEPTH_TEST);
		
		// Setup the viewport in orthogonal mode,
		// with dimensions 0..width, 0..height
		// with 0,0 being at the top left.
		glViewport(0, 0, target.getWidth(), target.getHeight()); 
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();  // [below] ortho perspective, near and far are arbitrary.
		glOrtho(0, target.getWidth(), target.getHeight(), 0, -32768, 32768);
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();	
			
		//This may need to be changed for when people wish to render surfaces individually so the already rendered are not cleared.
		if (!cleared)
		{	glClear(GL_COLOR_BUFFER_BIT);
			cleared = true;
		}
		
		surface.update();
		
		
		// We increment the stencil buffer with each stencil write.
		// This allows two partially overlapping clip regions to only allow writes in their intersection.
		ubyte stencil=0;
		
		// Function to draw surface and recurse through children.
		void draw(Surface surface) {
			
			// Bind surface properties	
			glPushMatrix();
			glMultMatrixf(surface.style.transform.ptr);
			glTranslatef(surface.left(), surface.top(), 0);
			surface.style.backfaceVisibility ? glDisable(GL_CULL_FACE) : glEnable(GL_CULL_FACE);
			
			graphics.drawGeometry(surface.getGeometry()); // TODO: This completely obscures everything below it in white!!!!!!!!
			
			// Apply or remove a layer in the stencil mask
			void doStencil(bool on)
			{
				// Apply Stencil if overflow is used.
				if (surface.style.overflowX == Style.Overflow.HIDDEN || surface.style.overflowY == Style.Overflow.HIDDEN)
				{	
					if (on)
					   stencil++;
					else
					   stencil--;
					
					// stencil mask defaults to 0xff
					glColorMask(0, 0, 0, 0); // Disable drawing to other buffers					
					glStencilFunc(GL_ALWAYS, 0, 0);// Make the stencil test always pass, increment existing value
					glStencilOp(GL_KEEP, GL_KEEP, on ? GL_INCR : GL_DECR);
					
					// Allow overflowing in only one direction by scaling the stencil in that direction
					if (surface.style.overflowX != Style.Overflow.HIDDEN)
					{	glPushMatrix();
						glTranslatef(-surface.offsetAbsolute.x, 0, 0);
						glScalef(Window.getInstance().getWidth() / surface.outerWidth(), 1, 1);
						
					}
					else if (surface.style.overflowY != Style.Overflow.HIDDEN)
					{	glPushMatrix();
						glTranslatef(0, -surface.offsetAbsolute.y, 0);
						glScalef(1, Window.getInstance().getHeight() / surface.outerHeight(), 1);						
					}										
					
					graphics.drawGeometry(surface.getGeometry().getClipGeometry());
					
					if (surface.style.overflowX != Style.Overflow.HIDDEN || surface.style.overflowY != Style.Overflow.HIDDEN)
						glPopMatrix();

					// Undo state changes above (this is faster than push/popState)
					glColorMask(1, 1, 1, 1);
					glStencilFunc(GL_EQUAL, stencil, uint.max); //Draw only where stencil buffer = current stencil level (broken?)
					glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
				}
			}
			
			// We only need to do clipping if the surface has children
			if (surface.getChildren().length)
				doStencil(true);
			
			// Recurse through and draw children.
			foreach(child; surface.getChildren())
				draw(child);
			
			doStencil(false);
			glPopMatrix();
			
		}
		
		// Draw the surface with and its chilren the stencil applied.
		glEnable(GL_STENCIL_TEST);
		draw(surface);
		glDisable(GL_STENCIL_TEST);
		
		glStencilFunc(GL_ALWAYS, 0, 0xff); // reset to default value
		
		
		// Reset state
		glEnable(GL_DEPTH_TEST);
		glEnable(GL_LIGHTING);
		glEnableClientState(GL_NORMAL_ARRAY);
		glEnable(GL_CULL_FACE);
		
		
		graphics.bindRenderTarget(null);	
			
		
	}

}