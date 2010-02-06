/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.graphics.api.opengl;

import tango.stdc.time : time;
import tango.core.Traits;
import tango.math.Math;
import tango.stdc.stringz;
import tango.util.container.HashMap;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;

import yage.core.all;
import yage.gui.surface;
import yage.gui.style;
import yage.resource.geometry;
import yage.resource.image;
import yage.resource.layer;
import yage.resource.material;
import yage.resource.model;
import yage.resource.shader;
import yage.resource.texture;
import yage.scene.all;
import yage.scene.light;
import yage.scene.model;
import yage.scene.camera: CameraNode;
import yage.scene.visible;
import yage.system.window;
import yage.system.system;
import yage.system.graphics.render;
import yage.system.graphics.probe;
import yage.system.graphics.api.api;
import yage.system.log;

private class ResourceInfo
{	uint id;
	uint time; // seconds from 1970, watch out for 2038!
	WeakRef!(Object) resource;
	
	// Create ResourceInfo for a resource in map if it doesn't exist, or return it if it does
	static ResourceInfo getOrCreate(Object resource, HashMap!(uint, ResourceInfo) map)
	{	uint hash = resource.toHash();
		ResourceInfo* temp = (hash in map);
		ResourceInfo info;
		if (!temp)
		{	info = new ResourceInfo();
			map[hash] = info;
			info.resource = new WeakRef!(Object)(resource);
		} else
			info = *temp;	
		info.time = tango.stdc.time.time(null);
		return info;
	}
}


/**
 * The OpenGL class provides a higher level of abstraction over OpenGL, 
 * without limiting what can be done with low-level OpenGL calls.
 * By inherting GraphicsAPI, it can be used interchangeably with other graphics apis, 
 * should they ever be implemented.
 */
class OpenGL : GraphicsAPI 
{
	protected Model msprite;
		
	protected HashMap!(uint, ResourceInfo) textures; // aa's fail, so we have to use Tango's Hashmap
	protected HashMap!(uint, ResourceInfo) vbos;
	protected HashMap!(uint, ResourceInfo) shaders;
	
	
	/**
	 * Free any resources from graphics memory are either:
	 * - haven't been used for longer than age,
	 * - are no longer referenced.
	 * If removed from graphics memory, they will be re-uploaded when needed again.
	 * Params:
	 *     age = maximum age (in seconds) of objects to keep.  Set to 0 to remove all items.  Defaults to 3600.
	 */
	void cleanup(uint age=3600)
	{
		
		foreach (key, info; textures)
		{	if (info.resource is null || info.time <= time(null)-age)
			{	glDeleteTextures(1, &info.id);
				textures.removeKey(key);
				delete info; // nothing else references it at this point.
		}	}
		foreach (key, info; vbos)
		{	if (info.resource is null || info.time <= time(null)-age)
			{	glDeleteBuffersARB(1, &info.id);
				vbos.removeKey(key);
				delete info; // nothing else references it at this point.
		}	}
	}
	
	this()
	{	
		textures = new HashMap!(uint, ResourceInfo);
		vbos = new HashMap!(uint, ResourceInfo);
		shaders = new HashMap!(uint, ResourceInfo);
		
		// Sprite
		msprite = new Model();
		msprite.setVertices([Vec3f(-1,-1, 0), Vec3f( 1,-1, 0), Vec3f( 1, 1, 0), Vec3f(-1, 1, 0)]);
		msprite.setNormals([Vec3f( 0, 0, 1), Vec3f( 0, 0, 1), Vec3f( 0, 0, 1), Vec3f( 0, 0, 1)]);
		msprite.setTexCoords0([Vec2f(0, 1), Vec2f(1, 1), Vec2f(1, 0), Vec2f(0, 0)]);
		msprite.setMeshes([new Mesh(null, [Vec3i(0, 1, 2), Vec3i(2, 3, 0)])]);
	}
	
	void bindCamera(CameraNode camera, int width, int height)
	{	current.camera = camera;
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		float aspect = camera.aspect ? camera.aspect : width/cast(float)height;
		gluPerspective(camera.fov, aspect, camera.near, camera.far);

		glMatrixMode(GL_MODELVIEW);
	}
	
	/**
	 * Set all of the OpenGL states to the values of this material layer.
	 * Params:
	 * lights = An array containing the LightNodes that affect this material,
	 *     passed to the shader through uniform variables (unfinished).
	 *     This function is used internally by the engine and doesn't normally need to be called.
	 * color = Used to set color on a per-instance basis, combined with existing material colors.
	 * Model = Used to retrieve texture coordinates for multitexturing. */
	void bindLayer(Layer layer, LightNode[] lights = null, Color color = Color("white"), Geometry model=null)
	{
		if (layer)
		{	// Material
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
				// TODO: there's currently no coverage for this block
				for (int i=0; i<length; i++)
				{	int GL_TEXTUREI_ARB = GL_TEXTURE0_ARB+i;

					// Activate texture unit and enable texturing
					glActiveTextureARB(GL_TEXTUREI_ARB);
					glEnable(GL_TEXTURE_2D);
					glClientActiveTextureARB(GL_TEXTUREI_ARB);
					
					// TODO: bind closest level of texture coordinates available instead of always using 0.
					bindVertexBuffer(model.getTexCoords0, Geometry.TEXCOORDS0);
					bindTexture(layer.textures[i]);
				}
			}
			else if(layer.textures.length == 1){
				glEnable(GL_TEXTURE_2D);
				bindTexture(layer.textures[0]);
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
					layer.setUniform("fog_enabled", cast(float)current.camera.getScene().fogEnabled);
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
			}
		} else // unbind
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
			if (current.layer.blend != BLEND_NONE)
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
			if (current.layer.textures.length>1 && Probe.feature(Probe.Feature.VBO))
			{	int length = min(layer.textures.length, Probe.feature(Probe.Feature.MAX_TEXTURE_UNITS));

				for (int i=length-1; i>=0; i--)
				{	glActiveTextureARB(GL_TEXTURE0_ARB+i);
					glDisable(GL_TEXTURE_2D);

					if (layer.textures[i].reflective)
					{	glDisable(GL_TEXTURE_GEN_S);
						glDisable(GL_TEXTURE_GEN_T);
					}
					glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
					textureUnbind(layer.textures[i]);
				}
				glClientActiveTextureARB(GL_TEXTURE0_ARB);
			}
			else if(current.layer.textures.length == 1){	
				textureUnbind(current.layer.textures[0]);			
				//glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_REPLACE);
			}
			glDisable(GL_TEXTURE_2D);
			

			// Shader
			if (current.layer.program != 0)
			{	glUseProgramObjectARB(0);
				current.layer.current_program = 0;
			}
		}
		current.layer = layer;
	}
	
	/**
	 * Enable this light as the given light number and apply its properties.
	 * This function is used internally by the engine and should not be called manually or exported. */
	void bindLight(LightNode light, int num)
	{	assert (num<=Probe.feature(Probe.Feature.MAX_LIGHTS));
		
		glPushMatrix();
		glLoadMatrixf(current.camera.getInverseAbsoluteMatrix().v.ptr); // required for spotlights.

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
	
	/**
	 * Call this function twice, the first time with a render target, and then again with null to complete.
	 * TODO, allow specifying which buffers to draw to (color, depth, stencil, etc). 
	 * Params:
	 *     target = Render to this target*/
	void bindRenderTarget(IRenderTarget target)
	{	
		assert((target && !current.renderTarget) || (!target && current.renderTarget));
		
		
		if (target)
		{			
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

					/// TODO: textures[texture].id will fail if Texture isn't bound.
					glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, textures[texture.toHash()].id, 0);
					
					auto status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
				} else
					Window.getInstance().setViewport(Vec2i(0), Vec2i(target.getWidth(), target.getHeight()));
			}			
		}
		else if (current.renderTarget) // release
		{
			
			GPUTexture texture = cast(GPUTexture)current.renderTarget;
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
					
					// TODO: textures[texture].id will fail if Texture isn't created.
					glBindTexture(GL_TEXTURE_2D, textures[texture.toHash()].id);
					glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 0, 0, texture.width, texture.height, 0);
					texture.format = 3;	// RGB
					texture.flipped = true;
				}					
			}
		}
		
		current.renderTarget = target;
	}
	
	/**
	 * Bind global scene properties, like ambient light and fog.
	 * Params:
	 *     scene = If non null, bind the properties of this scene, otherwise set them back to the defalts. */
	void bindScene(Scene scene)
	{	if (scene)
		{	with (scene)
			{
				
				if (fogEnabled)
				{	glFogfv(GL_FOG_COLOR, fogColor.vec4f.ptr);
					glFogf(GL_FOG_DENSITY, fogDensity);
					glEnable(GL_FOG);
				} else
					glDisable(GL_FOG);
				
				Vec4f color = backgroundColor.vec4f;
				glClearColor(color.x, color.y, color.z, color.w);
				glLightModelfv(GL_LIGHT_MODEL_AMBIENT, ambient.vec4f.ptr);
			}
		} else // TODO: track these values so they're only changed if necessary?
		{	glFogfv(GL_FOG_COLOR, Vec4f(0).ptr);
			glFogf(GL_FOG_DENSITY, 1);
			glDisable(GL_FOG);				
			
			glClearColor(0, 0, 0, 0);
			glLightModelfv(GL_LIGHT_MODEL_AMBIENT, Vec4f(.2, .2, .2, 1).ptr);
		}
	}
	
	
	/// Doesn't work and isn't used yet.
	void bindShader(Shader shader)
	{	
		//if (shader==current.shader)
		//	return;
		
		if (shader)
		{	assert(shader.getVertexSource());
			assert(shader.getFragmentSource());
			
			ResourceInfo info = ResourceInfo.getOrCreate(shader, shaders);
			
			// Compile and link shader if necessary.
			if (!info.id)
			{	char[] log;
				
				char[] getLog(uint id)
				{	int len;  char *log;
					glGetObjectParameterivARB(id, GL_OBJECT_INFO_LOG_LENGTH_ARB, &len);
					if (len > 0)
					{	log = (new char[len]).ptr;
						glGetInfoLogARB(id, len, &len, log);
					}
					return log[0..len];
				}
				
				uint compile(char[] source, uint type)
				{
					// Compile this shader into a binary object
					uint shaderObj;
					{	scope char** sourceZ = (new char*[1]).ptr;
						shaderObj = glCreateShaderObjectARB(type);
						sourceZ[0] = (source ~ "\0").ptr;
						glShaderSourceARB(shaderObj, 1, sourceZ, null);
						glCompileShaderARB(shaderObj);
						delete sourceZ[0];
					}
					
					// Get the compile log and check for errors
					char[] objLog = getLog(shaderObj);
					log ~= log;
					int status;
					glGetObjectParameterivARB(shaderObj, GL_OBJECT_COMPILE_STATUS_ARB, &status);
					if (!status)
					{	try {
							glDeleteObjectARB(shaderObj);
						} finally {
							throw new GraphicsException("Could not compile %s shader.\nReason:  %s\nSource:  %s", 
								type==GL_VERTEX_SHADER_ARB ? "vertex" : "fragment", objLog, source);
					}	}
					
					return shaderObj;
				}
				
				// Compile
				uint vertexObj = compile(shader.getVertexSource(), GL_VERTEX_SHADER_ARB);
				uint fragmentObj = compile(shader.getFragmentSource(), GL_FRAGMENT_SHADER_ARB);
				assert(vertexObj);
				assert(fragmentObj);
				
				// Link				
				info.id = glCreateProgramObjectARB();
				glAttachObjectARB(info.id, vertexObj);
				glAttachObjectARB(info.id, fragmentObj);
				glLinkProgramARB(info.id); // common failure point
				
				char[] linkLog = getLog(info.id);
				log ~= linkLog;
			
				// Check for errors
				int status;
				glGetObjectParameterivARB(info.id, GL_OBJECT_LINK_STATUS_ARB, &status);
				if (!status)
				{	throw new GraphicsException("Could not link the shaders.\nReason:  %s", linkLog);
				
				}
				
				glValidateProgramARB(info.id);
				log ~= getLog(info.id);
				
				
				Log.info(log); // temporary
			}
			
			assert(info.id);
			glUseProgramObjectARB(info.id);
		} else
			glUseProgramObjectARB(0); // no shader
		
		current.shader = shader;
	}
	
	///
	void bindTexture(ref Texture texture)
	{	GPUTexture gpuTexture = texture.texture;
		assert(gpuTexture);
		
		ResourceInfo info = ResourceInfo.getOrCreate(gpuTexture, textures);
		
		// If it doesn't have an OpenGL id
		if (!info.id)
		{				
			glGenTextures(1, &info.id);
			glBindTexture(GL_TEXTURE_2D, info.id);
			assert(glIsTexture(info.id)); // why does this fail if before bindTexture (because we need glFlush?)
			
			// For some reason these need to be called or everything runs slowly.			
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
			
			gpuTexture.dirty = true;
		}
		else
			glBindTexture(GL_TEXTURE_2D, info.id);
		
		// If texture needs to be uploaded
		if (gpuTexture.dirty)
		{	
			// Upload new image to graphics card memory
			Image image = gpuTexture.getImage();
			assert(image);
				
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
			if (!Probe.feature(Probe.Feature.NON_2_TEXTURE))
			{	Log.info("resizing texture");
				if (log2(new_height) != floor(log2(new_height)))
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
			
			gpuTexture.dirty = false;
			gpuTexture.flipped = false;	
		}
		
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
	
	/// TODO: merge into bindTexture
	void textureUnbind(Texture texture)
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

	/**
	 * Bind (and if necessary upload to video memory) a vertex buffer
	 * Params:
	 *   type = A vertex buffer type constant defined in Geometry or Mesh. */
	void bindVertexBuffer(IVertexBuffer vb, char[] type="")
	{	if (vb)
			assert(type.length);
		
		uint vbo_type = type==Mesh.TRIANGLES ? 
				GL_ELEMENT_ARRAY_BUFFER_ARB :
				GL_ARRAY_BUFFER_ARB;
		
		if (vb)
		{
			int featureVbo = Probe.feature(Probe.Feature.VBO);
			
			// Bind vbo and update data if necessary.
			if (featureVbo)
			{	
				// Get a new OpenGL buffer if there isn't one assigned yet.
				ResourceInfo info = ResourceInfo.getOrCreate(vb, vbos);
				if (!info.id)
				{	glGenBuffersARB(1, &info.id);
					vb.dirty = true;
				}
			
				// Bind buffer and update with new data if necessary.
				glBindBufferARB(vbo_type, info.id);
				if (vb.dirty)
				{	glBufferDataARB(vbo_type, vb.getData().length, vb.getData().ptr, GL_STATIC_DRAW_ARB);
					vb.dirty = false;
				}
			}
			
			// Bind the data
			switch (type)
			{
				case Geometry.VERTICES:
					glVertexPointer(vb.getComponents(), GL_FLOAT, 0, featureVbo ? null : vb.ptr);
					break;
				case Geometry.NORMALS:
					assert(vb.getComponents() == 3); // normals are always Vec3
					glNormalPointer(GL_FLOAT, 0, featureVbo ? null : vb.ptr);
					break;
				case Geometry.TEXCOORDS0:
					glTexCoordPointer(vb.getComponents(), GL_FLOAT, 0, featureVbo ? null : vb.ptr);
					break;
				case Mesh.TRIANGLES: // no binding necessary
				default:
					// TODO: Support custom types.
					//if (vb.length())
					//	throw new GraphicsException("Unsupported vertex buffer type %s", type);
					break;
			}		
		} else // unbind
			glBindBufferARB(vbo_type, 0);
	}
	
	
	
	///
	RenderStatistics drawGeometry(Geometry geometry)
	{	RenderStatistics result;
		
		if (!geometry.hasAttribute(Geometry.VERTICES))
			return result;
		
		// Bind each vertx buffer
		foreach (name, attrib; geometry.getAttributes())
		{	bindVertexBuffer(attrib, name);
			if (name==Geometry.VERTICES)
				result.vertexCount += attrib.length;
		}
		// Loop through the meshes		
		foreach (mesh; geometry.getMeshes())
		{	if (mesh.getMaterial() !is null) // Must have a material to render
			{	foreach (Layer l; mesh.getMaterial().getLayers()) // Loop through each layer (rendering pass)
				{	bindLayer(l);
					drawVertexBuffer(mesh.getTriangles(), Mesh.TRIANGLES);
					bindLayer(null); // can this be moved outside this loop?
			}	}
		
			result.triangleCount += mesh.getTriangles().length;
		}
		
		return result;
	}
	
	// Render a sprite
	RenderStatistics drawSprite(Material material, VisibleNode node)
	{	msprite.getMeshes()[0].setMaterial(material);
		return Render.model(msprite, node, Current.camera.getAbsoluteTransform(true).toAxis());
	}
	
	/**
	 * Draw the contents of a vertex buffer, such as a buffer of triangle indices. 
	 * @param triangles If not null, this array of triangle indices will be used for drawing the mesh*/
	void drawVertexBuffer(IVertexBuffer polygons, char[] type)
	{	int vbo = Probe.feature(Probe.Feature.VBO);
		if (polygons)
		{	bindVertexBuffer(polygons, type);
			if (type==Mesh.TRIANGLES)
				glDrawElements(GL_TRIANGLES, polygons.length*3, GL_UNSIGNED_INT, vbo ? null : polygons.ptr);
			else
				throw new YageException("Unsupported polygon type %s", type);
		}
		// else TODO
		//	glDrawArrays();
	}
	
	/*
	 * Create a wrapper around any OpenGL function, but check for errors when finished
	 * The simplified signature is: ReturnType execute(FunctionName)(Arguments ...);
	 * 
	 * Example:
	 * OpenGL.execute!(glColor3f)(0f, 1f, 1f, 1f);
	 */
	private static R executeAndCheck(alias T, R=ReturnTypeOf!(baseTypedef!(typeof(T))))(ParameterTupleOf!(baseTypedef!(typeof(T))) args)
	{	static if (is (R==void))
		{	T();
			check();
		} else
		{
			R result = T();
			check();
			return result;
		}
		void check()
		{	int err = glGetError();
			if (err != GL_NO_ERROR)
				throw new GraphicsException("Error %s, %s", err, fromStringz(cast(char*)gluErrorString(err)));
		}
	}
	
	
}


