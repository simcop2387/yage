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
import yage.resource.material;
import yage.resource.model;
import yage.resource.manager;
import yage.resource.shader;
import yage.resource.embed.embed;
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

private struct AlphaTriangle
{	
	Geometry geometry;
	Mesh mesh;
	Material material; // Sprites all share the same Mesh, but the material changes
	Matrix matrix;
	LightNode[] lights;	
	int triangle;	
	Vec3f[3] vertices;	
	
	static AlphaTriangle opCall( Geometry geometry, Mesh mesh, Material material, Matrix matrix, LightNode[] lights, int triangle, Vec3f[3] vertices)
	{	AlphaTriangle result = {geometry, mesh, material, matrix, lights, triangle, vertices};
		return result;		
	}
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
	
	protected static ArrayBuilder!(VisibleNode) visibleNodes;
	protected static ArrayBuilder!(AlphaTriangle) alphaTriangles;
	
	protected static Geometry currentGeometry;

	protected static bool cleared; // if false, the color buffer need to be cleared before drawing?
	protected static Geometry spriteQuad;
	
	protected struct ShaderParams
	{	ushort numLights;
		bool hasFog;
		bool hasSpecular;
		bool hasDirectional;
		bool hasSpotlight;
	}
	protected static Shader[ShaderParams] generatedShaders; // TODO: how will these ever get deleted, do they need to be?
	protected static ArrayBuilder!(ShaderUniform) uniformsLookaside;

	/**
	 * Generate build-in models (such as the sprite quad). */
	static this()
	{	graphics = new OpenGL();
		spriteQuad = Geometry.createPlane();
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

	// TODO: Move this to Render since it's higher level
	static Shader generateShader(MaterialPass pass, LightNode[] lights, bool fog, inout ArrayBuilder!(ShaderUniform) uniforms)
	{	
		// Use fixed function rendering, return null.
		if (pass.autoShader == MaterialPass.AutoShader.NONE)
			return null;
		
		// Set parameters for shader generation
		ShaderParams params;		
		params.numLights = lights.length;
		params.hasFog = fog;
		params.hasSpecular = (pass.specular.ui & 0xffffff) != 0; // ignore alpha in comparrison
		foreach (light; lights)
		{	params.hasDirectional = params.hasDirectional  ||  (light.type == LightNode.Type.DIRECTIONAL);
			params.hasSpotlight  = params.hasSpotlight || (light.type == LightNode.Type.SPOT);
		}
	
		Shader result;
		
		// Get shader, either a cached version or create a new one.		
		auto existingPtr = params in generatedShaders;
		if (existingPtr)
			result =  *existingPtr;		
		else
		{
			if (pass.autoShader == MaterialPass.AutoShader.PHONG)
			{
				char[] defines = format("#version 110\n#define NUM_LIGHTS %s\n", params.numLights);
				if (params.hasFog)
					defines ~= "#define HAS_FOG\n";
				if (params.hasSpecular)
					defines ~= "#define HAS_SPECULAR\n";
				if (params.hasDirectional)
					defines ~= "#define HAS_DIRECTIONAL\n";
				if (params.hasSpotlight)
					defines ~= "#define HAS_SPOTLIGHT\n";
		
				// TODO: embed these
				char[] vertex   = defines ~ cast(char[])Embed.phong_vert;
				char[] fragment = defines ~ cast(char[])Embed.phong_frag;
				result = new Shader(vertex, fragment);
		
			} else
				assert(0); // TODO
			
			generatedShaders[params] = result;
		}
		
		// Set uniform values
		if (pass.autoShader == MaterialPass.AutoShader.PHONG)
		{			
			Matrix camInverse = graphics.current.camera.getInverseAbsoluteMatrix();
			uniforms.length = lights.length * (params.hasSpotlight ? 5 : 2);			
			
			int idx=0;
			assert(lights.length < 10);
			foreach (i, light; lights)
			{	
				char[] makeName(char[] name, int i)
				{	name[7] = i + 48; // convert int to single digit ascii.
					return name;
				}
				
				// Doing it inline seems to make things slightly faster
				ShaderUniform* su = &uniforms.data[idx];
				char[] name = makeName("lights[_].position\0", i);
				su.name[0..name.length] = name[0..$];
				su.type = ShaderUniform.Type.F4;
				su.floatValues[0..3] = light.inverseCameraPosition.v[0..3];
				su.floatValues[4] = light.type == LightNode.Type.DIRECTIONAL ? 0.0 : 1.0;
				idx++;
				
				su = &uniforms.data[idx];
				name = makeName("lights[_].quadraticAttenuation\0", i);
				su.name[0..name.length] = name[0..$];
				su.type = ShaderUniform.Type.F1;
				su.floatValues[0] =light.getQuadraticAttenuation();
				idx++;
							
				if (params.hasSpotlight)
				{	Vec3f lightDirection = Vec3f(0, 0, 1).rotate(light.getAbsoluteTransform()).rotate(camInverse); 
					uniforms[idx++] = 
						ShaderUniform(makeName("lights[_].spotDirection", i), ShaderUniform.Type.F3, lightDirection.v);
					
					float angle = light.type == LightNode.Type.SPOT ? light.spotAngle : 2*PI;
					uniforms[idx++] =
						ShaderUniform(makeName("lights[_].spotCutoff", i), ShaderUniform.Type.F1, angle);
											
					uniforms[idx++] = 
						ShaderUniform(makeName("lights[_].spotExponent", i), ShaderUniform.Type.F1, light.spotExponent);
				}
			}			
		}
		
		return result;
	}
	
	/**
	 * Bind a MaterialPass, generating a shader based on the number of lights. */
	static void bindPass(MaterialPass pass, LightNode[] lights)
	{	
		if (pass.autoShader != MaterialPass.AutoShader.NONE)
		{	Shader oldShader = pass.shader;
			ShaderUniform[] oldUniforms = pass.shaderUniforms;
		
			pass.shader = generateShader(pass, lights, graphics.current.scene.fogEnabled, uniformsLookaside);
			pass.shaderUniforms = Render.uniformsLookaside.data;
			graphics.bindPass(pass);
			
			pass.shader = oldShader;
			pass.shaderUniforms = oldUniforms;
		} else
			graphics.bindPass(pass);
	}
	
	///
	static RenderStatistics geometry(Geometry geometry, LightNode[] lights=null)
	{	RenderStatistics result;
		
		assert(geometry.getAttribute(Geometry.VERTICES));
		
		// Bind each vertex buffer
		VertexBuffer[char[]] vertexBuffers = geometry.getVertexBuffers();
		if (geometry !is currentGeometry) // benchmarks show this makes things a little faster
		{	
			foreach (name, vb; vertexBuffers)
			{	graphics.bindVertexBuffer(vb, name);
				if (name==Geometry.VERTICES)
					result.vertexCount += vb.length;
			}
			currentGeometry = geometry;
		} else
			result.vertexCount += vertexBuffers[Geometry.VERTICES].length;
		
		
		// Loop through the meshes		
		foreach (mesh; geometry.getMeshes())
		{	
			if (mesh.material)
				if (mesh.material.techniques.length) // TODO: Honor techniques
				{
					if (!mesh.material.techniques[0].hasTranslucency() ||
					    geometry.getVertexBuffer(Geometry.VERTICES).components != 3)
					{	foreach (pass; mesh.material.techniques[0].passes)
						{	bindPass(pass, lights);
							graphics.drawPolygons(mesh.getTrianglesVertexBuffer(), Mesh.TRIANGLES);
						}
					} else
					{	Profile.start("Add Alpha");
						foreach (i, tri; mesh.getTriangles())
						{							
							// Find center
							Vec3f[] vertices = (cast(Vec3f[])geometry.getAttribute(Geometry.VERTICES));	
							Vec3f[3] v;
							v[0] = vertices[tri.x];
							v[1] = vertices[tri.y];
							v[2] = vertices[tri.z];

							alphaTriangles ~= AlphaTriangle(geometry, mesh, mesh.material, graphics.current.transformMatrix, lights, i, v);;
						}
						Profile.stop("Add Alpha");	
					}
				}
					
			result.triangleCount += mesh.getTrianglesVertexBuffer().length;
		}
		
		return result;
	}
	
	///
	static RenderStatistics model(Geometry geometry, LightNode[] lights=null, float animationTime=0) 
	{	auto result = Render.geometry(geometry, lights);  // TODO: animationTime won't support blending animations.
		return result;
	}
	
	/// Why does this draw the same material on different sprites?
	/// It has something to do with them all sharing the same Geometry?
	protected static void postRender()
	{	
		scope mesh = new Mesh();
		int num_lights = Probe.feature(Probe.Feature.MAX_LIGHTS);
		
		Profile.start("Sort Alpha");		
		
		// Sort alpha (translucent) triangles
		Vec3f cameraPosition = Vec3f(graphics.current.camera.getAbsoluteTransform(true).v[12..15]);
		radixSort(alphaTriangles.data, true, (AlphaTriangle a)
		{	Vec3f center = (a.vertices[0]+a.vertices[1]+a.vertices[2]).scale(1/3f);
			center = center.transform(a.matrix);
			return -cameraPosition.distance2(center); // distance squared is faster and values still compare the same
		});
		
		Profile.stop("Sort Alpha");
	
		Profile.start("Render Alpha");
		
		// Render alpha triangles
		foreach (at; alphaTriangles.data)
		{	
			Vec3i[1] triangle = at.mesh.getTriangles()[at.triangle];			
			mesh.setMaterial(at.material);
			mesh.setTriangles(triangle);
						
			// ATI Fails to draw when vertices have VBO's and triangles don't.
			// It's a shame because this makes it about 60% faster to render.
			//mesh.getTrianglesVertexBuffer().cache = false;
			
			graphics.bindMatrix(&at.matrix);
			
			if (currentGeometry != at.geometry)
			{	foreach (name, vb; at.geometry.getVertexBuffers())				
					graphics.bindVertexBuffer(vb, name);				
				currentGeometry = at.geometry;
			}
			
			if (mesh.material)
				if (mesh.material.techniques.length) // TODO: Honor techniques
				{	
					for (int i=at.lights.length; i<num_lights; i++)
						glDisable(GL_LIGHT0+i);					
					for (int i=0; i<min(num_lights, at.lights.length); i++)
						graphics.bindLight(at.lights[i], i);
					
					foreach (pass; mesh.material.techniques[0].passes)
					{	bindPass(pass, at.lights);
						graphics.drawPolygons(mesh.getTrianglesVertexBuffer(), Mesh.TRIANGLES);
					}
				}
			
			graphics.bindMatrix(null);
		}
		Profile.stop("Render Alpha");
		
		
		if (alphaTriangles.reserve < alphaTriangles.length)
			alphaTriangles.reserve = alphaTriangles.length;
		alphaTriangles.length = 0;		
	}
	
	/**
	 * Render a camera's view to target.
	 * The previous contents of target are first cleared.
	 * Params:
	 *	 camera = Render what the camera sees.
	 *	 target = Render to this target.
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

			int num_lights = Probe.feature(Probe.Feature.MAX_LIGHTS);
			LightNode[] all_lights = camera.getScene().getLights().values; // creates garbage, but this copy also prevents threading issues.
			
			foreach (light; all_lights)
				light.inverseCameraPosition = light.getAbsolutePosition().transform(camera.getInverseAbsoluteMatrix());
			
			// Loop through all nodes in the queue and render them
			foreach (VisibleNode n; nodes)
			{	synchronized (n)
				{	if (!n.getScene()) // was recently removed from its scene.
						continue;
				
					// Transform
					Vec3f size = n.getSize();
					Matrix transform = n.getAbsoluteTransform(true).transformAffine(Matrix().scale(size));			
					
					graphics.bindMatrix(&transform);
					
					// Enable the lights that affect this node
					// TODO: Two things that can speed this up:
					// Only test light spheres that overlap the view frustum
					// Do a distance test for an early rejection of get light brightness.
					scope lights = n.getLights(all_lights, num_lights);					
					for (int i=lights.length; i<num_lights; i++)
						glDisable(GL_LIGHT0+i);					
					for (int i=0; i<min(num_lights, lights.length); i++)
						graphics.bindLight(lights[i], i);
					
					// Render
					if (cast(ModelNode)n)
						result +=model((cast(ModelNode)n).getModel(), lights);						
					else if (cast(SpriteNode)n)
						result += sprite((cast(SpriteNode)n).getMaterial(), lights);
					
					graphics.bindMatrix(null);
				}
			}
			
			postRender();
			
			graphics.bindVertexBuffer(null);
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
				glDepthMask(true);
				glClear(GL_DEPTH_BUFFER_BIT);
				glPopMatrix();
			}
			
			// Apply scene state and clear background if necessary.
			graphics.bindScene(scene);
			if (!scene.skyBox)
			{	glDepthMask(true);
				if (!cleared) // reset everyting the first time.
				{	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
					cleared = true;
				}
				else
					glClear(GL_DEPTH_BUFFER_BIT); // reset depth buffer for drawing after a skybox
			}
				
			camera.buildFrustum(scene);
			Profile.start("getVisibleNodes");
			visibleNodes = camera.getVisibleNodes(scene, visibleNodes);
			Profile.stop("getVisibleNodes");
			result += drawNodes(visibleNodes.data);
			visibleNodes.reserve = visibleNodes.length;
			visibleNodes.length = 0;
	
			return result;
		}		
		
		graphics.bindRenderTarget(target);
		auto result = skyboxRecurse(camera, target);
		graphics.bindRenderTarget(null);
		graphics.bindPass(null);
		cleanup();
		
		/*
		float* image = new float[1920*1080*3];
		Timer a = new Timer(true);
		glReadPixels(0, 0, 1920, 1080, GL_RGB, GL_BYTE, image);
		Log.trace(a.tell());	
		delete image;
		*/
		
		return result;
	}
	
	// Render a sprite
	static RenderStatistics sprite(Material material, LightNode[] lights=null)
	{			
		// Rotate if rotation is nonzero.
		Vec3f rotation = graphics.current.camera.getAbsoluteTransform(true).toAxis();
		if (rotation.length2())			
		{	// TODO: zero the rotation along the axis from the node to the camera.						
			Matrix transform;
			transform.setRotation(rotation);
			graphics.bindMatrix(&transform);			
		}
		
		spriteQuad.getMeshes()[0].material = material;
		auto result = geometry(spriteQuad, lights);
		
		// Pop the matrix stack
		if (rotation.length2())
			graphics.bindMatrix(null);
			
		return result;
	}
	
	/// Render a surface.  TODO: Move parts of this to OpenGL.d
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
			
			geometry(surface.getGeometry());
			
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
					
					geometry(surface.getGeometry().getClipGeometry());
					
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
			graphics.bindPass(null);
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