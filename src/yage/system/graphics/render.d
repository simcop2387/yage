/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:	   Eric Poggel
 * License:	   <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.graphics.render;

import tango.math.Math;
import tango.io.Stdout;

import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;
import derelict.sdl.sdl;

import yage.core.all;
import yage.gui.surface;
import yage.gui.style;
import yage.system.system;
import yage.system.graphics.graphics;
import yage.system.graphics.probe;
import yage.resource.geometry;
import yage.resource.image;
import yage.resource.layer;
import yage.resource.material;
import yage.resource.model;
import yage.resource.texture;
import yage.scene.all;
import yage.scene.light;
import yage.scene.model;
import yage.scene.camera: CameraNode;
import yage.scene.visible;
import yage.system.window;

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
	
	//double vertexBufferTime=0;		/// time spend binding vertex buffers
	//double lightCalculationTime=0;	/// time spent calculating which lights affect which objects.
	//double materialStateTime=0;		/// time spent changing opengl states to render materials
	//double lightStateTime=0;			/// time spent changing opengl states to apply lights
	//double totalTime=0;
	
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

Timer q;

/**
 * As the nodes of the scene graph are traversed, those to be rendered in
 * the current frame are added to a queue.  They are then reordered for correct
 * and optimal rendering.  Translucent polygons are separated, sorted
 * and rendered in a second pass. */
struct Render
{
	protected static Array!(VisibleNode) visibleNodes;
	protected static AlphaTriangle[] alpha;
	protected static CameraNode current_camera;

	protected static bool cleared; // does the color buffer need to be cleared before drawing?
	
	// Basic shapes
	protected static Model mcube;
	protected static Model msprite;

	// Stats
	protected static uint poly_count;
	protected static uint vertex_count;

	/**
	 * Generate build-in models (such as the sprite quad). */
	static this()
	{
		// Sprite
		msprite = new Model();
		msprite.setVertices([Vec3f(-1,-1, 0), Vec3f( 1,-1, 0), Vec3f( 1, 1, 0), Vec3f(-1, 1, 0)]);
		msprite.setNormals([Vec3f( 0, 0, 1), Vec3f( 0, 0, 1), Vec3f( 0, 0, 1), Vec3f( 0, 0, 1)]);
		msprite.setTexCoords0([Vec2f(0, 1), Vec2f(1, 1), Vec2f(1, 0), Vec2f(0, 0)]);
		msprite.setMeshes([new Mesh(null, [Vec3i(0, 1, 2), Vec3i(2, 3, 0)])]);
		
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
	static void cleanup()
	{
		// Delete old unused ids
		foreach (oldId; IVertexBuffer.getGarbageIds())
			Graphics.deleteBuffer(oldId);
		IVertexBuffer.clearGarbageIds();
		
		foreach (oldId; GPUTexture.getGarbageIds())
			Graphics.deleteTexture(oldId);
		GPUTexture.clearGarbageIds();
	}

	/**
	 * Complete rendering and swap the back buffer to the front buffer. */
	static void complete()
	{	SDL_GL_SwapBuffers();
		cleared = false;
	}
	
	/**
	 * Get / set the current (or last) camera that is/was rendering a scene.
	 * This is mostly for internal use. */
	static CameraNode getCurrentCamera()
	{	return current_camera;
	}

	static RenderStatistics geometry(Geometry geometry)
	{	RenderStatistics result;
		
		if (!geometry.hasAttribute(Geometry.VERTICES))
			return result;
		
		// Bind each vertx buffer
		foreach (name, attrib; geometry.getAttributes())
		{	Bind.vertexBuffer(name, attrib);
			if (name==Geometry.VERTICES)
				result.vertexCount += attrib.length;
		}
		
		/* // temporary to get surfaces to render properly until everything is migrated to Graphics. */
		glDisable(GL_LIGHTING);
		glDisable(GL_TEXTURE_2D);
		glEnable(GL_BLEND);
		
		
		// Loop through the meshes		
		foreach (mesh; geometry.getMeshes())
		{	if (mesh.getMaterial() !is null) // Must have a material to render
			{	foreach (Layer l; mesh.getMaterial().getLayers()) // Loop through each layer (rendering pass)
				{	Bind.layer(l);
					vertexBuffer(Mesh.TRIANGLES, mesh.getTriangles());
					Bind.layerUnbind(l);
			}	}
		
			result.triangleCount += mesh.getTriangles().length;
		}
		
		return result;
	}
	
	/*
	 * Render the meshes with opaque materials and pass any meshes with materials
	 * that require blending to the queue of translucent meshes.
	 * Rotation can optionally be supplied to rotate sprites so they face the camera. 
	 * TODO: Make all vbo's optional.
	 * TODO: Rewrite this around the simpler Render.geometry */
	static RenderStatistics model(Model model, VisibleNode node, Vec3f rotation = Vec3f(0), bool _debug=false)
	{	
		RenderStatistics result;
		
		if (!model.hasAttribute(Geometry.VERTICES))
			return result;
		
		Vec3f[] v = cast(Vec3f[])model.getVertices().getData();
		Vec3f[] n = cast(Vec3f[])model.getNormals().getData();
		Vec2f[] t = cast(Vec2f[])model.getTexCoords0().getData();
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
		
		foreach (name, attrib; model.getAttributes())
			Bind.vertexBuffer(name, attrib);

		// Loop through the meshes		
		foreach (Mesh mesh; model.getMeshes())
		{
			result.triangleCount += mesh.getTriangles().length;
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
					{	Bind.layer(l, node.getLights(), node.getColor(), model);
						vertexBuffer(Mesh.TRIANGLES, mesh.getTriangles());
						Bind.layerUnbind(l);
					} else
					{						
						// Add to translucent.  This may need to be rewritten at some point.
						foreach (int index, Vec3i tri; cast(Vec3i[])mesh.getTriangles().getData())						
						{	AlphaTriangle at;
							for (int i=0; i<3; i++)
							{	at.vertices[i] = abs_transform*v[tri.v[i]].scale(node.getSize());
								at.texcoords[i] = &t[tri.v[i]];
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
			//	drawTriangles();
				vertexBuffer(Mesh.TRIANGLES, mesh.getTriangles());
				
			
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
		
		return result;
	}

	/**
	 * Render noes to the current rendering target.
	 * Params:
	 *	 nodes = Array of nodes to render.
	 * Returns: A struct with statistics about this rendering call. */
	static RenderStatistics nodes(VisibleNode[] nodes)
	{
		RenderStatistics result;
		result.nodeCount = nodes.length;

		int num_lights = Probe.feature(Probe.Feature.MAX_LIGHTS);
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
					Bind.light(lights[i], i);
				
				
				// Render
				if (cast(ModelNode)n)
					result += model((cast(ModelNode)n).getModel(), n);			
				else if (cast(SpriteNode)n)
					result += sprite((cast(SpriteNode)n).getMaterial(), n);
				
				glPopMatrix();
			}
		}
		
		// Sort alpha (translucent) triangles
		Vec3f camera = Vec3f(current_camera.getAbsoluteTransform(true).v[12..15]);
		radixSort(alpha, true, (AlphaTriangle a)
		{	Vec3f center = (a.vertices[0]+a.vertices[1]+a.vertices[2]).scale(1/3);
			return -camera.distance2(center); // distance squared is faster and values still compare the same
		});
		
		// Render alpha triangles
		foreach (AlphaTriangle at; alpha)
		{	foreach (layer; at.matl.getLayers())
			{	Bind.layer(layer, at.node.getLights(), at.node.getColor());
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
				Bind.layerUnbind(layer);
			}			
		}

		// Unbind current VBO
		if(Probe.feature(Probe.Feature.VBO))
			glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);

		alpha.length = 0;

		return result;
	}
	
	/**
	 * Render a camera's view to target.
	 * The previous contents of target are first cleared.
	 * Params:
	 *	 camera = Render what the camera sees.
	 *	 target = Render to this target.  TODO: Convert to IRenderTarget.
	 *	 scene = Used internally for rendering skyboxes recursively.
	 * Returns:
	 *	 A struct containing rendering statistics */
	static RenderStatistics scene(CameraNode camera, IRenderTarget target, Scene scene=null)
	{		
		Bind.renderTarget(target);
		
		RenderStatistics recurse(CameraNode camera, IRenderTarget target, Scene scene=null)
		{
			Graphics.pushState();			
			
			RenderStatistics result;
			
			if (!scene)
				scene = camera.getScene();
			
			// start reading from the most recently updated set of buffers.
			scene.swapTransformRead();
			
			Bind.camera(camera, target.getWidth(), target.getHeight());			
			Graphics.loadIdentity();
			
			// Precalculate the inverse of the Camera's absolute transformation Matrix.
			camera.inverse_absolute = camera.getAbsoluteTransform(true).inverse();
			if (scene == camera.scene)
				Graphics.multMatrix(camera.inverse_absolute);
			else
			{	Vec3f axis = camera.inverse_absolute.toAxis();
				Graphics.rotate(axis.length(), axis.x, axis.y, axis.z);
			}
			
			// Recurse through skyboxes
			if (scene.skyBox)
			{	Graphics.pushMatrix();
				recurse(camera, target, scene.skyBox);
				Graphics.clear(GL_DEPTH_BUFFER_BIT);
				Graphics.popMatrix();
			}
			
			// Apply scene state and clear background if necessary.
			Bind.scene(scene);
			if (!scene.skyBox)
			{	if (!cleared) // reset everyting the first time.
				{	Graphics.clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
					cleared = true;
				}
				else
					Graphics.clear(GL_DEPTH_BUFFER_BIT); // reset depth buffer for drawing after a skybox
			}
			
			Graphics.applyState();
	
			camera.buildFrustum(scene);
			visibleNodes = camera.getVisibleNodes(scene, visibleNodes);
			result += Render.nodes(visibleNodes.data);
			visibleNodes.reserve = visibleNodes.length;
			visibleNodes.length = 0;
	
			Graphics.popState();
			return result;
		}
		
		auto result = recurse(camera, target, scene);
		Bind.renderTargetRelease();
		cleanup();		
		return result;
	}
	
	// Render a sprite
	static RenderStatistics sprite(Material material, VisibleNode node)
	{	msprite.getMeshes()[0].setMaterial(material);
		return model(msprite, node, current_camera.getAbsoluteTransform(true).toAxis());
	}
	
	/// Render a surface
	static void surface(Surface surface, IRenderTarget target=null)
	{
		Bind.renderTarget(target);
		
		Graphics.pushState();
		
		glPushAttrib(0xFFFFFFFF);	// all attribs
		glDisableClientState(GL_NORMAL_ARRAY);
		
		// Setup the viewport in orthogonal mode,
		// with dimensions 0..width, 0..height
		// with 0,0 being at the top left.
		glViewport(0, 0, target.getWidth(), target.getHeight()); // [below] ortho perspective, near and far are arbitrary.
		
		/*// broken
		if (cast(Window)target)
			(cast(Window)target).setViewport(Vec2i(), Vec2i(target.getWidth(), target.getHeight()));
		Graphics.loadProjectionMatrix(Matrix(0, target.getWidth(), target.getHeight(), 0, -32768, 32768)); 
		Graphics.loadIdentity();
		*/

		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0, target.getWidth(), target.getHeight(), 0, -32768, 32768);
		glMatrixMode(GL_MODELVIEW);
		Graphics.loadIdentity();
		
		
		
		Graphics.disable(Enable.DEPTH_TEST); // TODO: something is re-enabling this further along.
		Graphics.disable(Enable.LIGHTING);
			
		//This may need to be changed for when people wish to render surfaces individually so the already rendered are not cleared.
		if (!cleared)
		{	Graphics.clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT); // TODO: Clearing depth buffer should be un-necessary
			cleared = true;
		}
		
		surface.update();
		
		
		// We increment the stencil buffer with each stencil write.
		// This allows two partially overlapping clip regions to only allow writes in their intersection.
		ubyte stencil=0;
		
		// Function to draw surface and recurse through children.
		void draw(Surface surface) {
			Graphics.pushMatrix();
			
			// Bind surface properties			
			Graphics.multMatrix(surface.style.transform);
			Graphics.translate(surface.left(), surface.top(), 0);
			surface.style.backfaceVisibility ? Graphics.disable(Enable.CULL_FACE) : Graphics.enable(Enable.CULL_FACE);
			
			Graphics.applyState(); // temporary
			
			Render.geometry(surface.getGeometry());
			
			// Apply or remove a stencil mask
			void doStencil(bool on)
			{
				// Apply Stencil if overflow is used.  TODO: Convert to using Graphics.
				if (surface.style.overflowX == Style.Overflow.HIDDEN || surface.style.overflowY == Style.Overflow.HIDDEN)
				{	
					if (on)
					   stencil++;
					else
					   stencil--;
									
					Graphics.colorMask(0, 0, 0, 0); // Disable drawing to other buffers
					Graphics.stencilMask(uint.max); // write everything to the stencil buffer
					Graphics.stencilFunc(GL_ALWAYS, 0, 0);// Make the stencil test always pass, increment existing value
					Graphics.stencilOp(GL_KEEP, GL_KEEP, on ? GL_INCR : GL_DECR);
					
					// Allow overflowing in only one direction by scaling the stencil in that direction
					if (surface.style.overflowX != Style.Overflow.HIDDEN)
					{	Graphics.pushMatrix();
						Graphics.translate(-surface.offsetAbsolute.x, 0, 0);
						Graphics.scale(Window.getInstance().getWidth() / surface.outerWidth(), 1, 1);
						
					}
					else if (surface.style.overflowY != Style.Overflow.HIDDEN)
					{	Graphics.pushMatrix();
						Graphics.translate(0, -surface.offsetAbsolute.y, 0);
						Graphics.scale(1, Window.getInstance().getHeight() / surface.outerHeight(), 1);						
					}
										
					Graphics.applyState(); // temporary
					Render.geometry(surface.getGeometry().getClipGeometry());
					
					if (surface.style.overflowX != Style.Overflow.HIDDEN || surface.style.overflowY != Style.Overflow.HIDDEN)
						Graphics.popMatrix();

					// Undo state changes above (this is faster than push/popState)
					Graphics.colorMask(1, 1, 1, 1);
					Graphics.stencilOp(GL_KEEP, GL_KEEP, GL_KEEP);
					
					Graphics.stencilFunc(GL_EQUAL, stencil, uint.max); //Draw only where stencil buffer = current stencil level (broken?)
						
					Graphics.applyState(); // temporary
				}
			}
			
			doStencil(true);
			
			// Recurse through and draw children.
			foreach(child; surface.getChildren())
				draw(child);
			
			doStencil(false);
			
			Graphics.popMatrix();
			Graphics.applyState(); // temporary
		}
		
		glEnable(GL_STENCIL_TEST);
		draw(surface);
		glDisable(GL_STENCIL_TEST);
		glStencilFunc(GL_ALWAYS, 0, 0xff); // reset to default value
		
		
		glEnableClientState(GL_NORMAL_ARRAY);
		glPopAttrib();
		Graphics.popState();
		
		Bind.renderTargetRelease();
	}

	/**
	 * Draw the contents of a vertex buffer, such as a buffer of triangle indices. */
	static void vertexBuffer(char[] type, IVertexBuffer triangles=null)
	{	int vbo = Probe.feature(Probe.Feature.VBO);
		if (triangles)
		{	Bind.vertexBuffer(type, triangles);
			glDrawElements(GL_TRIANGLES, triangles.length*3, GL_UNSIGNED_INT, vbo ? null : triangles.ptr);
		}
		// else
		//	glDrawArrays();
	}
}


private struct Bind
{
	static IRenderTarget currentRenderTarget;
	
	static void camera(CameraNode camera, int width, int height)
	{	Render.current_camera = camera;
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		float aspect = camera.aspect ? camera.aspect : width/cast(float)height;
		gluPerspective(camera.fov, aspect, camera.near, camera.far);

		glMatrixMode(GL_MODELVIEW);
	}
	
	/*
	 * Set all of the OpenGL states to the values of this material layer.
	 * This essentially applies the material.  Call unApply() to reset
	 * the OpenGL states back to the engine defaults in preparation for
	 * whatever will be rendered next.
	 * Params:
	 * lights = An array containing the LightNodes that affect this material,
	 * passed to the shader through uniform variables (unfinished).
	 * This function is used internally by the engine and doesn't normally need to be called.
	 * color = Used to set color on a per-instance basis, combined with existing material colors.
	 * Model = Used to retrieve texture coordinates for multitexturing. */
	static void layer(Layer layer, LightNode[] lights = null, Color color = Color("white"), Geometry model=null)
	{
		// Material
		glMaterialfv(GL_FRONT, GL_AMBIENT, layer.ambient.vec4f.scale(color.vec4f).v.ptr);
		glMaterialfv(GL_FRONT, GL_DIFFUSE, layer.diffuse.vec4f.scale(color.vec4f).v.ptr);
		glMaterialfv(GL_FRONT, GL_SPECULAR, layer.specular.vec4f.scale(color.vec4f).v.ptr);
		glMaterialfv(GL_FRONT, GL_EMISSION, layer.emissive.vec4f.scale(color.vec4f).v.ptr);
		glMaterialfv(GL_FRONT, GL_SHININESS, &layer.specularity);	
		
		glColor4fv(layer.color.vec4f.ptr);

		// Blend
		if (layer.blend != BLEND_NONE)
		{	glEnable(GL_BLEND);
			glDepthMask(false);
			switch (layer.blend)
			{	case BLEND_ADD:
					glBlendFunc(GL_ONE, GL_ONE);
					break;
				case BLEND_AVERAGE:
					glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
					break;
				case BLEND_MULTIPLY:
					glBlendFunc(GL_ZERO, GL_SRC_COLOR);
					break;
				default: break;
		}	}
		else
		{	glEnable(GL_ALPHA_TEST);
			glAlphaFunc(GL_GREATER, 0.5f); // If blending is disabled, any pixel less than 0.5 opacity will not be drawn
		}

		// Cull
		if (layer.cull == LAYER_CULL_FRONT)
			glCullFace(GL_FRONT);

		// Polygon
		switch (layer.draw)
		{	default:
			case LAYER_DRAW_FILL:
				glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
				break;
			case LAYER_DRAW_LINES:
				glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
				glLineWidth(layer.width);
				break;
			case LAYER_DRAW_POINTS:
				glPolygonMode(GL_FRONT_AND_BACK, GL_POINT);
				glPointSize(layer.width);
				break;
		}
		
		// Textures
		if (layer.textures.length>1 && Probe.feature(Probe.Feature.MULTITEXTURE))
		{	int length = min(layer.textures.length, Probe.feature(Probe.Feature.MAX_TEXTURE_UNITS));

			// Loop through all of Layer's textures up to the maximum allowed.
			for (int i=0; i<length; i++)
			{	int GL_TEXTUREI_ARB = GL_TEXTURE0_ARB+i;

				// Activate texture unit and enable texturing
				glActiveTextureARB(GL_TEXTUREI_ARB);
				glEnable(GL_TEXTURE_2D);
				glClientActiveTextureARB(GL_TEXTUREI_ARB);

				// Set texture coordinates
				IVertexBuffer texcoords = model.getTexCoords0();
				if (Probe.feature(Probe.Feature.VBO))
				{	glBindBufferARB(GL_ARRAY_BUFFER, texcoords.id);
					glTexCoordPointer(texcoords.getComponents(), GL_FLOAT, 0, null);
				} else
					glTexCoordPointer(texcoords.getComponents(), GL_FLOAT, 0, texcoords.ptr);

				// Bind and blend
				Bind.texture(layer.textures[i]);
			}
		}
		else if(layer.textures.length == 1){
			glEnable(GL_TEXTURE_2D);
		//	textures[0].bind();
			Bind.texture(layer.textures[0]);
		} else
			glDisable(GL_TEXTURE_2D);

		// Shader
		if (layer.program != 0)
		{	glUseProgramObjectARB(layer.program);
		layer.current_program = layer.program;

			// Try to light and fog variables?
			try {	// bad for performance?
				layer.setUniform("light_number", lights.length);
			} catch{}
			try {
				layer.setUniform("fog_enabled", cast(float)Render.getCurrentCamera().getScene().fogEnabled);
			} catch{}

			// Enable
			for (int i=0; i<layer.textures.length; i++)
			{	if (layer.textures[i].name.length)
				{	char[256] cname = 0;
					cname[0..layer.textures[i].name.length]= layer.textures[i].name;
					int location = glGetUniformLocationARB(layer.program, cname.ptr);
					if (location == -1)
					{}//	throw new Exception("Warning:  Unable to set texture sampler: " ~ textures[i].name);
					else
						glUniform1iARB(location, i);
			}	}
			
			/*
			// Attributes
			foreach (name, attrib; model.getAttributes())
			{	int location = glGetAttribLocation(program, toStringz(name));
				if (location != -1)
				{


					if (model.getCached())
					{	// This works as is, don't yet know why
						//int vbo;
						//glBindBufferARB(GL_ARRAY_BUFFER, vbo);

						glEnableVertexAttribArray(location);
						glBindBuffer(GL_ARRAY_BUFFER_ARB, attrib.index);
						glVertexAttribPointer(location, 4, GL_FLOAT, false, 0, null);

						writefln(1);
						void **values;
						glGetVertexAttribPointerARB(location, program, values);
						writefln(2);
						//writefln(values[0..attrib.values.length]);
					}
					else
					{	glEnableVertexAttribArray(location);
						glVertexAttribPointer(location, 4, GL_FLOAT, false, 0, &attrib.values[0]);
					}
				}

			}
			
			//glBufferDataARB(GL_ARRAY_BUFFER, values.length*Vec3f.sizeof, values.ptr, GL_STATIC_DRAW);
			//glBindBufferARB( GL_ARRAY_BUFFER_ARB, vbo);
			//glVertexAttribPointerARB(location, 4, GL_FLOAT, 0, 0, null);

			// Attributes
			// Apparently attributes have to be used as vbo's if vertices are also
			foreach (name, values; model.getAttributes())
			{	int location = glGetAttribLocation(program, toStringz(name));

				if (location != -1)
				{	int vbo;
					glBindBufferARB(GL_ARRAY_BUFFER, vbo);
					glEnableVertexAttribArray(location);
					glVertexAttribPointer(location, 4, 0x1406, false, 0, &values[0]);
				}
			}
			*/
		}
	}
	
	/*
	 * This function will no longer be necessary once all OpenGL calls go through graphics.Graphics, since
	 * it will allow the OpenGL state to be pushed and popped. */
	static void layerUnbind(Layer layer)
	{
		glColor4f(1, 1, 1, 1);
		
		// Material
		float s=0;
		glMaterialfv(GL_FRONT, GL_AMBIENT, Vec4f().v.ptr);
		glMaterialfv(GL_FRONT, GL_DIFFUSE, Vec4f(1).v.ptr);
		glMaterialfv(GL_FRONT, GL_SPECULAR, Vec4f().v.ptr);
		glMaterialfv(GL_FRONT, GL_EMISSION, Vec4f().v.ptr);
		glMaterialfv(GL_FRONT, GL_SHININESS, &s);

		// Blend
		if (layer.blend != BLEND_NONE)
		{	glDisable(GL_BLEND);
			glDepthMask(true);
		}else
		{	glDisable(GL_ALPHA_TEST);
			glAlphaFunc(GL_ALWAYS, 0);
		}

		// Cull, polygon
		glCullFace(GL_BACK);
		glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
		
		
		// Textures
		if (layer.textures.length>1 && Probe.feature(Probe.Feature.VBO))
		{	int length = min(layer.textures.length, Probe.feature(Probe.Feature.MAX_TEXTURE_UNITS));

			for (int i=length-1; i>=0; i--)
			{	glActiveTextureARB(GL_TEXTURE0_ARB+i);
				glDisable(GL_TEXTURE_2D);

				if (layer.textures[i].reflective)
				{	glDisable(GL_TEXTURE_GEN_S);
					glDisable(GL_TEXTURE_GEN_T);
				}
				glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
				Bind.textureUnbind(layer.textures[i]);
			}
			glClientActiveTextureARB(GL_TEXTURE0_ARB);
		}
		else if(layer.textures.length == 1){	
			Bind.textureUnbind(layer.textures[0]);			
			//glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
		}
		glDisable(GL_TEXTURE_2D);
		

		// Shader
		if (layer.program != 0)
		{	glUseProgramObjectARB(0);
			layer.current_program = 0;
		}
	}
	
	/*
	 * Enable this light as the given light number and apply its properties.
	 * This function is used internally by the engine and should not be called manually or exported. */
	static void light(LightNode light, int num)
	{	assert (num<=Probe.feature(Probe.Feature.MAX_LIGHTS));
		
		glPushMatrix();
		glLoadMatrixf(Render.current_camera.getInverseAbsoluteMatrix().v.ptr); // required for spotlights.

		// Set position and direction
		glEnable(GL_LIGHT0+num);
		auto type = light.type;
		Matrix transform_abs = light.getAbsoluteTransform(true);
		
		Vec4f pos;
		pos.v[0..3] = transform_abs.v[12..15];
		pos.v[3] = type==LightNode.Type.DIRECTIONAL ? 0 : 1;
		glLightfv(GL_LIGHT0+num, GL_POSITION, pos.v.ptr);

		// Spotlight settings
		float angle = type == LightNode.Type.SPOT ? light.spotAngle : 180;
		glLightf(GL_LIGHT0+num, GL_SPOT_CUTOFF, angle);
		if (type==LightNode.Type.SPOT)
		{	glLightf(GL_LIGHT0+num, GL_SPOT_EXPONENT, light.spotExponent);
			// transform_abs.v[8..11] is the opengl default spotlight direction (0, 0, 1),
			// rotated by the node's rotation.  This is opposite the default direction of cameras
			glLightfv(GL_LIGHT0+num, GL_SPOT_DIRECTION, transform_abs.v[8..11].ptr);
		}

		// Light material properties
		glLightfv(GL_LIGHT0+num, GL_AMBIENT, light.ambient.vec4f.ptr);
		glLightfv(GL_LIGHT0+num, GL_DIFFUSE, light.diffuse.vec4f.ptr);
		glLightfv(GL_LIGHT0+num, GL_SPECULAR, light.specular.vec4f.ptr);
		
		// Attenuation properties
		glLightf(GL_LIGHT0+num, GL_CONSTANT_ATTENUATION, 0); // requires a 1 but should be zero?
		glLightf(GL_LIGHT0+num, GL_LINEAR_ATTENUATION, 0);
		glLightf(GL_LIGHT0+num, GL_QUADRATIC_ATTENUATION, light.getQuadraticAttenuation());

		glPopMatrix();
	}

	// Part of a test to gt renderTargt to work with fbo's.
	static uint fbo;
	static uint renderBuffer;
	
	/*
	 * Rendering will occur on this target. */
	static void renderTarget(IRenderTarget target)
	{	assert(target);
		assert(!currentRenderTarget);
		
		currentRenderTarget = target;
		
		// If target is a texture to render to
		GPUTexture texture = cast(GPUTexture)target;
		if (texture)
		{
			// If FBO is supported, use it for texture rendering, otherwise render to framebuffer and copy the image.
			// FBO is currently disabled due to a bug.
			if (false && Probe.Feature.FBO)
			{
				glGenFramebuffersEXT(1, &fbo);
				glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, fbo); // why does this line fail?

				glGenRenderbuffersEXT(1, &renderBuffer);
				glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, renderBuffer);
				
				// Currently testing rendering the depth component, since that's what the tutorial used.
				glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, target.getWidth(), target.getHeight());
				glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, renderBuffer);

				glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, texture.getId(), 0);
				
				auto status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
			}
		}
		
		Window.getInstance().setViewport(Vec2i(0), Vec2i(target.getWidth(), target.getHeight()));
	}
	
	/*
	 * Release a previously bound IRenderTarget */
	static void renderTargetRelease()
	{	assert(currentRenderTarget);
		
		GPUTexture texture = cast(GPUTexture)currentRenderTarget;
		if (texture)
		{	
			// Framebufferobject currently disabled due to a bug
			if (false && Probe.Feature.FBO)
			{	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT, 0);

				glDeleteFramebuffersEXT(1, &fbo);
				glDeleteRenderbuffersEXT(1, &renderBuffer);
				
			}
			else
			{	Vec2i viewportSize = Window.getInstance().getViewportSize();
				
				//if (!Probe.feature(NON_2_TEXTURE))
				if (true)
				{	texture.width = nextPow2(viewportSize.x);
					texture.height= nextPow2(viewportSize.y);
					texture.padding = Vec2i(texture.width-viewportSize.x, texture.height-viewportSize.y);
		
				} else
				{	texture.width = viewportSize.x;
					texture.height = viewportSize.y;
					texture.padding = Vec2i(0);
				}
				
				glBindTexture(GL_TEXTURE_2D, texture.getId());
				glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 0, 0, texture.width, texture.height, 0);
				texture.format = 3;	// RGB
				texture.flipped = true;
			}
			
		}
		
		currentRenderTarget = null;
	}
	
	/*
	 * Bind global scene properties, like ambient light and fog. */
	static void scene(Scene scene)
	{	with (scene)
		{
			glLightModelfv(GL_LIGHT_MODEL_AMBIENT, ambient.vec4f.ptr);
			if (fogEnabled)
			{	glFogfv(GL_FOG_COLOR, fogColor.vec4f.ptr);
				glFogf(GL_FOG_DENSITY, fogDensity);
				glEnable(GL_FOG);
			} else
				glDisable(GL_FOG);
			
			Vec4f color = backgroundColor.vec4f;
			glClearColor(color.x, color.y, color.z, color.w);		
		}
	}
	
	///
	static void texture(Texture texture)
	{	GPUTexture gpuTexture = texture.texture;
		
		Image image = gpuTexture.image;
		
		bool reload = !gpuTexture.getId() || image;
		if (reload)
		{	
			if (!gpuTexture.id)
			{	glGenTextures(1, &gpuTexture.id);
				glBindTexture(GL_TEXTURE_2D, gpuTexture.id);
				assert(glIsTexture(gpuTexture.id)); // why does this fail if before bindTexture?
				
				// For some reason these need to be called or everything runs slowly.			
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			}
			else
				glBindTexture(GL_TEXTURE_2D, gpuTexture.id);
			
			// Upload new image to graphics card memory
			if (image)
			{	
				// Calculate formats
				uint glformat, glinternalformat;
				gpuTexture.format = image.getChannels();
				switch(gpuTexture.format)
				{	case Image.Format.GRAYSCALE:
						glformat = GL_LUMINANCE;
						glinternalformat = gpuTexture.compress ? GL_COMPRESSED_LUMINANCE : GL_LUMINANCE;
						break;
					case Image.Format.RGB:
						glformat = GL_RGB;
						glinternalformat = gpuTexture.compress ? GL_COMPRESSED_RGB : GL_RGB;
						break;
					case Image.Format.RGBA:
						glformat = GL_RGBA;
						glinternalformat = gpuTexture.compress ? GL_COMPRESSED_RGBA : GL_RGBA;
						break;
					default:
						throw new ResourceException("Unknown texture format {}", gpuTexture.format);
				}
				
				gpuTexture.width = image.getWidth();
				gpuTexture.height = image.getHeight();
				
				uint max = Probe.feature(Probe.Feature.MAX_TEXTURE_SIZE);
				uint new_width = image.getWidth();
				uint new_height= image.getHeight();
				
				// Ensure power of two sized if required
				//if (!Probe.getSupport(DEVICE_NON_2_TEXTURE))
				if (true)
				{	if (log2(new_height) != floor(log2(new_height)))
						new_height = nextPow2(new_height);
					if (log2(new_width) != floor(log2(new_width)))
						new_width = nextPow2(new_width);
	
					// Resize if necessary
					if (new_width != gpuTexture.width || new_height != gpuTexture.height)
						image = image.resize(min(new_width, max), min(new_height, max));
				}
					
				// Build mipmaps (doing it ourself is about 20% faster than gluBuild2DMipmaps,
				int level = 0; //  but image.resize can be optimized further.
				do {
					glTexImage2D(GL_TEXTURE_2D, level, glinternalformat, image.getWidth(), image.getHeight(), 0, glformat, GL_UNSIGNED_BYTE, image.getData().ptr);
					image = image.resize(image.getWidth()/2, image.getHeight()/2);
					level ++;							
				} while (gpuTexture.mipmap && image.getWidth() >= 4 && image.getHeight() >= 4)
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, level-1);
				
				
				gpuTexture.flipped = false;
			} else
				gpuTexture.format = gpuTexture.width = gpuTexture.height = 0;
			
			
			gpuTexture.image = null;
		}
		else
			glBindTexture(GL_TEXTURE_2D, gpuTexture.id);
		
		// Filtering
		if (texture.filter == Texture.Filter.DEFAULT)
			texture.filter = Texture.Filter.TRILINEAR;	// Create option to set this later
		switch(texture.filter)
		{	case Texture.Filter.NONE:
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, gpuTexture.mipmap ?  GL_NEAREST_MIPMAP_NEAREST : GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
				break;
			case Texture.Filter.BILINEAR:
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, gpuTexture.mipmap ? GL_LINEAR_MIPMAP_NEAREST : GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
				break;
			default:
			case Texture.Filter.TRILINEAR:
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, gpuTexture.mipmap ? GL_LINEAR_MIPMAP_LINEAR : GL_LINEAR);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
				break;
		}

		// Clamping
		if (texture.clamp)
		{	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		}else // OpenGL Default
		{	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		}


		// Texture Matrix operations
		//if (position.length2() || scale.length2() || rotation!=0)
		{	glMatrixMode(GL_TEXTURE);
			glPushMatrix();
			
			Vec2f padding = gpuTexture.getPadding();			
			
			// Apply special texture scaling/flipping
			if (texture.texture.flipped || padding.length2())
			{	Vec2f size = Vec2f(gpuTexture.getWidth(), gpuTexture.getHeight());
				Vec2f scale = (size-padding)/size;
				
				if (texture.texture.flipped)
				{	glTranslatef(0, scale.y, 0);					
					glScalef(scale.x, -scale.y, 1);
				}
				else
					glScalef(scale.x, scale.y, 1);
			}			
			
			glMultMatrixf(texture.transform.v.ptr);			
			glMatrixMode(GL_MODELVIEW);
		}

		// Environment Mapping
		if (texture.reflective)
		{	glEnable(GL_TEXTURE_GEN_S);
			glEnable(GL_TEXTURE_GEN_T);
			glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
			glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
		}

		// Blend Mode
		uint blendTranslated;
		switch (texture.blend)
		{	case Texture.Blend.ADD: blendTranslated = GL_ADD; break;
			case Texture.Blend.AVERAGE: blendTranslated = GL_DECAL; break;
			case Texture.Blend.NONE:
			case Texture.Blend.MULTIPLY:
			default: blendTranslated = GL_MODULATE; break;				
		}
		glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, blendTranslated);
	}
	
	// This won't be necessary once the transition to using Graphics is complete
	static void textureUnbind(Texture texture)
	{
		// Texture Matrix
		//if (position.length2() || scale.length2() || rotation!=0)
		{	glMatrixMode(GL_TEXTURE);
			glPopMatrix();
			glMatrixMode(GL_MODELVIEW);
		}

		// Environment Map
		if (texture.reflective)
		{	glEnable(GL_TEXTURE_GEN_S);
			glEnable(GL_TEXTURE_GEN_T);
			glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
			glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
		}

		// Blend
		if (texture.blend != Texture.Blend.MULTIPLY)
			glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
		
		glBindTexture(GL_TEXTURE_2D, 0);
	}

	/*
	 * Bind (and if necessary upload to video memory) a vertex buffer
	 * Params:
	 *   type = A vertex buffer type constant defined in Geometry or Mesh. */
	static void vertexBuffer(char[] type, IVertexBuffer vb)
	{	
		int vbo = Probe.feature(Probe.Feature.VBO);
		
		// Bind vbo and update data if necessary.
		if (vbo)
		{	
			uint vbo_type = type==Mesh.TRIANGLES ? 
				GL_ELEMENT_ARRAY_BUFFER_ARB :
				GL_ARRAY_BUFFER_ARB;
			
			// Get a new OpenGL buffer if there isn't one assigned yet.
			if (!vb.id)
			{	assert(vb.dirty); // sanity check.				
				vb.id = Graphics.genBuffer();
			}
		
			// Bind buffer and update with new data if necessary.
			Graphics.bindBuffer(vbo_type, vb.id);
			if (vb.dirty)
			{	Graphics.bufferData(vbo_type, vb.getData(), GL_STATIC_DRAW_ARB);
				vb.dirty = false;
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
}