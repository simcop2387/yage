/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:	   Eric Poggel
 * License:	   <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.graphics.render;

import tango.math.Math;

import derelict.opengl.gl;
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
import yage.system.graphics.api;
import yage.system.graphics.opengl;
import yage.system.log;

private struct AlphaTriangle
{	Geometry geometry;
	Mesh mesh;
	Material material; // Sprites all share the same Mesh, but the material changes
	Matrix matrix;
	LightNode[] lights;	
	int triangle;	
	Vec3f[3] vertices;	
	
	static AlphaTriangle opCall(Geometry geometry, Mesh mesh, Material material, Matrix matrix, LightNode[] lights, int triangle, Vec3f[3] vertices)
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
	int lightCount; ///
	
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
		lightCount += rhs.lightCount;
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
	protected static ArrayBuilder!(AlphaTriangle) alphaTriangles;	
	protected static Geometry currentGeometry;

	protected static bool cleared; // if false, the color buffer need to be cleared before drawing?
	protected static Geometry spriteQuad; // TODO: Move to SpriteNode
	
	protected struct ShaderParams
	{	ushort numLights;
		bool hasFog;
		bool hasSpecular;
		bool hasDirectional;
		bool hasSpotlight;
		bool hasTexture;
		bool hasBump;
	}
	protected static Shader[ShaderParams] generatedShaders;
	protected static ArrayBuilder!(ShaderUniform) uniformsLookaside; // TODO: Can we use Memory.allocate instead?
	protected static bool[MaterialTechnique] failedTechniques;
	

	/**
	 * Generate built-in models (such as the sprite quad). */
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

	/**
	 * Generate a phong/normal map shader for the pass.
	 * Params:
	 *     pass = 
	 *     lights = 
	 *     fog = 
	 *     uniforms = Uniform variables to pass to the shader when binding.
	 * Returns: */
	static Shader generateShader(MaterialPass pass, LightNode[] lights, bool fog, ref ArrayBuilder!(ShaderUniform) uniforms)
	{	
		//if (lights.length  >2)
		//	lights.length = 2;
		
		// Use fixed function rendering, return null.
		if (pass.autoShader == MaterialPass.AutoShader.NONE)
			return null;
		
		// Set parameters for shader generation
		ShaderParams params;		
		params.numLights = lights.length;
		params.hasFog = fog;
		params.hasSpecular = (pass.specular.ui & 0xffffff) != 0; // ignore alpha in comparrison
		params.hasTexture = pass.textures.length > 0;
		params.hasBump = pass.textures.length > 1;
		foreach (light; lights)
		{	assert(light);
			params.hasDirectional = params.hasDirectional || (light.type == LightNode.Type.DIRECTIONAL);
			params.hasSpotlight  = params.hasSpotlight || (light.type == LightNode.Type.SPOT);
		}
	
		Shader result;
		
		// Get shader, either a cached version or create a new one.		
		auto existingPtr = params in generatedShaders;
		if (existingPtr)
			result = *existingPtr;		
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
				if (params.hasTexture)
					defines ~= "#define HAS_TEXTURE\n";
				if (params.hasBump)
					defines ~= "#define HAS_BUMP\n";
		
				// Shader source code.
				char[] vertex   = defines ~ cast(char[])Embed.phong_vert;
				char[] fragment = defines ~ cast(char[])Embed.phong_frag;
				result = new Shader(vertex, fragment);
				try {					
					graphics.bindShader(result);
				} catch (GraphicsException e)
				{	//result.failed = true;
					Log.info(e.toString());
					if (lights.length > 1)
						Log.info("Could not generate phong shader for %s lights, %s lights will be attempted instead.", lights.length, lights.length-1);
					else
						Log.info("Could not use phong auto-shader.");
					graphics.bindShader(null);
				}
			} else
				assert(0); // TODO
			
			generatedShaders[params] = result;
		}
		
		// Recursively try fewer lights until we have a shader that works or reach 1 light.
		if (result in graphics.failedShaders)
		{	if (lights.length > 1)
				return generateShader(pass, lights[0..$-1], fog, uniforms);
			else
				return result; // return it anyway so it can fail higherup the chain
		}
		
		// Set uniform values
		if (pass.autoShader == MaterialPass.AutoShader.PHONG)
		{	/* static char[] is a problem on Linux, it causes a segfault */
			// Static makes .dup only occur once.
			char[] lightPosition = "lights[_].position\0".dup;
			char[] lightQuadraticAttenuation = "lights[_].quadraticAttenuation\0".dup;
			char[] lightSpotDirection = "lights[_].spotDirection\0".dup;
			char[] lightSpotCutoff = "lights[_].spotCutoff\0".dup;
			char[] lightSpotExponent = "lights[_].spotExponent\0".dup;
			
			uniforms.length = lights.length * (params.hasSpotlight ? 5 : 2);			
			
			int idx=0;
			assert(lights.length < 10);
			foreach (i, light; lights)
			{	
				char[] makeName(char[] name, int i)
				{	name[7] = i + '0'; // convert int to single digit ascii.
					return name;
				}
				
				// Doing it inline seems to make things slightly faster
				ShaderUniform* su = &uniforms.data[idx];
				char[] name = makeName(lightPosition, i);
				su.name[0..name.length] = name[0..$];
				su.type = ShaderUniform.Type.F4;
				su.floatValues[0..3] = light.cameraSpacePosition.v[0..3];
				su.floatValues[4] = light.type == LightNode.Type.DIRECTIONAL ? 0.0 : 1.0;
				idx++;
				
				su = &uniforms.data[idx];
				name = makeName(lightQuadraticAttenuation, i);
				su.name[0..name.length] = name[0..$];
				su.type = ShaderUniform.Type.F1;
				su.floatValues[0] =light.getQuadraticAttenuation();
				idx++;
							
				if (params.hasSpotlight)
				{	Matrix camInverse = graphics.cameraInverse;
					
					Vec3f lightDirection = Vec3f(0, 0, 1).rotate(light.getWorldTransform()).rotate(camInverse); 
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
	static bool bindPass(MaterialPass pass, LightNode[] lights)
	{	bool result;
		if (pass && pass.autoShader != MaterialPass.AutoShader.NONE)
		{	Shader oldShader = pass.shader;
			ShaderUniform[] oldUniforms = pass.shaderUniforms;
		
			pass.shader = generateShader(pass, lights, graphics.current.scene.fogEnabled, uniformsLookaside);
			pass.shaderUniforms = Render.uniformsLookaside.data;
			result = graphics.bindPass(pass);
			
			pass.shader = oldShader;
			pass.shaderUniforms = oldUniforms;
		} else
			result = graphics.bindPass(pass);
		
		return result;
	}
	
	/**
	 * Get the first technique that can be used without issue, or the last technique if all have issues. */ 
	static MaterialTechnique getTechnique(Material material, LightNode[] lights=null)
	{	foreach (technique; material.techniques)
		{	if (technique in failedTechniques)
				continue;
			foreach (pass; technique.passes)
				if (!bindPass(pass, lights))
				{	failedTechniques[technique] = true; // so we don't have to bind the pass next time.
					break; // skip to next technique				
				}			
			return technique;
		}
		return material.techniques[$-1]; // return the last one even if it doesn't work.
	}
	
	
	///
	static RenderStatistics geometry(ref RenderCommand command)
	{	RenderStatistics result;
	
		Geometry geometry = command.geometry;
		auto lights = command.getLights();
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
		foreach (i, mesh; geometry.getMeshes())
		{	
			auto material = command.materialOverrides.length > i ? command.materialOverrides[i] : mesh.material;			
			if (material)
			{	
				auto technique = getTechnique(material, lights);
				
				if (technique) // TODO: Honor techniques
				{
					assert(technique.passes.length);
					
					if (!technique.hasTranslucency() ||
					    geometry.getVertexBuffer(Geometry.VERTICES).components != 3)
					{	foreach (pass; technique.passes)
						{	bindPass(pass, lights);
							graphics.drawPolygons(mesh.getTrianglesVertexBuffer(), Mesh.TRIANGLES);
						}
					} else if (technique.passes[0].diffuse.a > 0) // Don't render it at all if we have 0 alpha.
					{	
						foreach (j, tri; mesh.getTriangles())
						{							
							// Find center
							Vec3f[] vertices = (cast(Vec3f[])geometry.getAttribute(Geometry.VERTICES));	
							Vec3f[3] v;
							v[0] = vertices[tri.x];
							v[1] = vertices[tri.y];
							v[2] = vertices[tri.z];

							alphaTriangles ~= AlphaTriangle(geometry, mesh, material, command.transform, lights, j, v);
						}						
					}					
				}
			}
					
			result.triangleCount += mesh.getTrianglesVertexBuffer().length;
		}
		
		// Geometry debugging properties
		if (geometry.drawNormals || geometry.drawTangents)
		{
			MaterialPass pass = new MaterialPass(); // TODO: static
			pass.lighting = false;
			
			Vec3f[] vertices = cast(Vec3f[])geometry.getAttribute(Geometry.VERTICES);
			Vec3f[] normals = cast(Vec3f[])geometry.getAttribute(Geometry.NORMALS);
			Vec3f[] tangents = cast(Vec3f[])geometry.getAttribute(Geometry.TEXCOORDS1);
			
			Vec3f[] lines = Memory.allocate!(Vec3f)(vertices.length * 2);
			scope VertexBuffer vb = new VertexBuffer();
			
			if (tangents.length && geometry.drawTangents)
			{	for (int i=0; i<vertices.length; i++)
				{	lines[i*2] = vertices[i];
					lines[i*2+1] = vertices[i] + tangents[i];
				}
				
				pass.diffuse = "green";
				graphics.bindPass(pass);
				vb.setData(lines);
				graphics.drawPolygons(vb, Mesh.LINES, false);
			}
			
			if (normals.length && geometry.drawNormals)
			{	for (int i=0; i<vertices.length; i++)
				{	lines[i*2] = vertices[i];
					lines[i*2+1] = vertices[i] + normals[i];
				}
				
				graphics.current.pass = null;
				pass.diffuse = "magenta";
				graphics.bindPass(pass);
				vb.setData(lines);
				graphics.drawPolygons(vb, Mesh.LINES, false);
			}
			
			Memory.free(lines);
		}
		
		return result;
	}	
	
	// deprecated.  Model animation will be handled in the update, or possibly another thread.
	static RenderStatistics model(Model model, LightNode[] lights=null, Material[] materialOverrides=null, float animationTime=0) 
	{	//auto result = Render.geometry(model, lights, materialOverrides);  // TODO: animationTime won't support blending animations.
		RenderStatistics result;
		
		if (model.joints.length)
		{
			// Calculate joint positions
			static bool positionsWritten = false;
			
			foreach (i, joint; model.joints) // this works because the joints are stored in order.
			{	if (joint.getParent())
					joint.absolute = joint.getParent().absolute.transformAffine(joint.relative);
				else
					joint.absolute = joint.relative;
			}
			
			/*	
			void calculateJoints(Joint joint)
			{	
				if (joint.getParent())
					joint.absolute = joint.getParent().absolute.transformAffine(joint.relative);
					// joint.absolute = joint.relative.transformAffine(joint.getParent().absolute
				else
					joint.absolute = joint.relative;
				foreach (child; joint.getChildren())
					calculateJoints(child);				
			}
			if (model.joints.length)
				calculateJoints(model.joints[0]);

			if (!positionsWritten)
				foreach (i, joint; model.joints)
					Log.trace(joint.absolute.getPosition());
				
			*/
			positionsWritten = true;
			
		
			// Geometry debugging properties
			if (model.drawJoints)
			{
				MaterialPass pass = new MaterialPass(); // TODO: static
				pass.lighting = false;
				pass.depthRead = false;
				
				Vec3f[] points = Memory.allocate!(Vec3f)(model.joints.length);
				Vec3f[] lines = Memory.allocate!(Vec3f)(model.joints.length*2);
				int lineIndex;
				foreach (i, joint; model.joints)			
				{	points[i] = joint.absolute.getPosition();
					if (joint.getParent())				
					{	lines[lineIndex] = joint.absolute.getPosition();
						lines[lineIndex+1] = joint.getParent().absolute.getPosition();
						lineIndex+=2;
				}	}
				
				scope VertexBuffer vb = new VertexBuffer();
				vb.cache = false; // don't cache since we're just using it once
				
				// A point for each joint
				pass.diffuse = "magenta";
				pass.linePointSize = 10;
				pass.draw = MaterialPass.Draw.POINTS; // req'd for line width to be used.
				graphics.bindPass(pass);
				vb.setData(points);
				graphics.drawPolygons(vb, Mesh.POINTS, false);
				
				// And a line connecting them
				graphics.current.pass = null; // reset cache		
				pass.diffuse = "blue";
				pass.linePointSize = 2;
				pass.draw = MaterialPass.Draw.LINES; // req'd for line width to be used.
				graphics.bindPass(pass);
				vb.setData(lines);
				graphics.drawPolygons(vb, Mesh.LINES, false);

				Memory.free(lines);
				Memory.free(points);
			}
		}
	
		return result;
	}
			
	/**
	 * Perform aditional render steps that must be done after all normal rendering is done,
	 * such as alpha triangles. */
	protected static void postRender()
	{	
		// Declaring it this way instead of scope allows the same vbo to be reused each time. 
		static Mesh mesh;
		if (!mesh)
			mesh = new Mesh();
		mesh.getTrianglesVertexBuffer().cache = false; // Makes things just a little faster.
		
		int num_lights = Probe.feature(Probe.Feature.MAX_LIGHTS);
				
		// Sort alpha (translucent) triangles
		Vec3f cameraPosition = graphics.cameraInverse.inverse().getPosition(); // Inverse of the inverse is wasteful.
		radixSort(alphaTriangles.data, true, (AlphaTriangle a)
		{	Vec3f center = (a.vertices[0]+a.vertices[1]+a.vertices[2]).scale(1/3f);
			center = center.transform(a.matrix);
			return -cameraPosition.distance2(center); // distance squared is faster and values still compare the same
		});
		
		// Render alpha triangles
		foreach (ref at; alphaTriangles.data)
		{	Vec3i[1] triangle = at.mesh.getTriangles()[at.triangle];			
			mesh.setMaterial(at.material);
			mesh.setTriangles(triangle);
			
			graphics.matrix.push();
			graphics.matrix.multiply(at.matrix);
			
			if (currentGeometry != at.geometry)
			{	foreach (name, vb; at.geometry.getVertexBuffers())				
					graphics.bindVertexBuffer(vb, name);				
				currentGeometry = at.geometry;
			}
			
			if (mesh.material)							
			{	auto technique = getTechnique(mesh.material, at.lights); // slows it down a little bit				
				if (technique)
				{	
					graphics.bindLights(at.lights);
					
					// This is the slowest part, probably due to so many state changes
					foreach (pass; technique.passes)
					{	bindPass(pass, at.lights);
						graphics.drawPolygons(mesh.getTrianglesVertexBuffer(), Mesh.TRIANGLES);
					}
			}	}
			graphics.matrix.pop();
		}		
		
		if (alphaTriangles.reserve < alphaTriangles.length)
			alphaTriangles.reserve = alphaTriangles.length;
		alphaTriangles.length = 0;
	}
	
	/**
	 * Completely reset the Rendering engine.
	 * All shaders will be regenerated. 
	 * TODO: As of now, only a few things are actually reset. */
	static void reset()
	{	graphics.reset();
		generatedShaders = null;
		failedTechniques = null;		
		currentGeometry = null;
		uniformsLookaside.length = 0;
		alphaTriangles.length = 0;
	}

	///
	static RenderStatistics scene(CameraNode camera, IRenderTarget target)
	{	
		RenderStatistics result;
		
		camera.aspectRatio = target.getWidth()/ cast(float)target.getHeight();
		graphics.bindRenderTarget(target);
		
		// Loop through each commandSet.  A commandSet will be created for the camera's main scene and another for its skybox.
		auto renderList = camera.getRenderList();
		graphics.cameraInverse = renderList.cameraInverse;
		graphics.bindCamera(camera);
		foreach_reverse (i, renderScene; renderList.scenes)
		{			
			// Bind matrices for camera position
			graphics.matrix.loadIdentity();			
			if (i==0) // base scene
				glMultMatrixf(renderList.cameraInverse.v.ptr);
			else // only rotate by the camera's matrix if in a skybox.
			{	Vec3f axis = renderList.cameraInverse.toAxis().oldVec;
				glRotatef(axis.length()*57.295779513, axis.x, axis.y, axis.z);
			}
			
			// Clear buffers
			graphics.bindScene(renderScene.scene);
			if (!cleared) // reset everyting the first time.
			{	glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT | GL_STENCIL_BUFFER_BIT); // is stencil necessary?
				cleared = true;
			} else
				glClear(GL_DEPTH_BUFFER_BIT);
			
			result.lightCount += renderScene.lights.length;
						
			// Process all render commands in the set
			result.nodeCount += renderScene.commands.length;
			foreach (ref RenderCommand command; renderScene.commands.data)
			{	graphics.matrix.push();
				graphics.matrix.multiply(command.transform);
				graphics.bindLights(command.getLights()); 
				result += geometry(command);
				graphics.matrix.pop();
			}
			
			// Take care of special rendering jobs that must occur last (like translucent polygons)
			postRender();
		}		
		
		graphics.bindRenderTarget(null);
		graphics.bindPass(null);
		//graphics.bindVertexBuffer(null);
		cleanup();
		
		return result;
	}
		
	/// Render a surface.  TODO: Move parts of this to OpenGL.d
	static void surface(Surface surface, IRenderTarget target=null)
	{	
		graphics.bindRenderTarget(target);
		
		// Setup the viewport in orthogonal mode,
		// with dimensions 0..width, 0..height
		// with 0,0 being at the top left.
		glViewport(0, 0, target.getWidth(), target.getHeight()); 
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();  // [below] ortho perspective, near and far are arbitrary.
		glOrtho(0, target.getWidth(), target.getHeight(), 0, -32768, 32768);
		glMatrixMode(GL_MODELVIEW);
		glLoadIdentity();	
			
		// This may need to be changed for when people wish to render surfaces individually so the already rendered are not cleared.
		if (!cleared)
		{	glClear(GL_COLOR_BUFFER_BIT);
			cleared = true;
		}
		
		Vec2f size = Vec2f(target.getWidth(), target.getHeight());
		surface.update(&size);
		
		
		// We increment the stencil buffer with each stencil write.
		// This allows two partially overlapping clip regions to only allow writes in their intersection.
		ubyte stencil=0;
		
		// Function to draw surface and recurse through children.
		void draw(Surface surface) {
			
			if (!surface.style.visible || !surface.style.display)
				return;
			
			// Bind surface properties	
			graphics.matrix.push();
			glTranslatef(surface.offsetX(), surface.offsetY(), 0);
			graphics.matrix.multiply(surface.style.transform);
			surface.style.backfaceVisibility ? glDisable(GL_CULL_FACE) : glEnable(GL_CULL_FACE);
			
			// Render the surface
			RenderCommand command;
			command.geometry = surface.getGeometry();
			geometry(command);
			
			// Apply or remove a layer in the stencil mask
			void doStencil(bool on)
			{
				// Apply Stencil if overflow is used.
				if (surface.style.overflow == Style.Overflow.HIDDEN)
				{	
					if (on)
					   stencil++;
					else
					   stencil--;
					
					// stencil mask defaults to 0xff
					glColorMask(0, 0, 0, 0); // Disable drawing to other buffers					
					glStencilFunc(GL_ALWAYS, 0, 0);// Make the stencil test always pass, increment existing value
					glStencilOp(GL_KEEP, GL_KEEP, on ? GL_INCR : GL_DECR);
					
					RenderCommand command;
					command.geometry = surface.getGeometry().getClipGeometry();
					geometry(command); // draw stencil
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
			graphics.matrix.pop();
			graphics.bindPass(null);
		}
		
		// Draw the surface with and its chilren the stencil applied.
		glEnable(GL_STENCIL_TEST);
		draw(surface);
		glDisable(GL_STENCIL_TEST);		
		glStencilFunc(GL_ALWAYS, 0, 0xff); // reset to default value		
		
		// Reset state
		glEnable(GL_CULL_FACE);		
		
		graphics.bindRenderTarget(null);	
	}
}
