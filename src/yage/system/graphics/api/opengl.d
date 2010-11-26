/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.graphics.api.opengl;

import tango.stdc.time : time;
import tango.core.Traits;
import tango.core.WeakRef;
import tango.math.Math;
import tango.stdc.stringz;
import tango.util.container.HashMap;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;

import yage.core.all;
import yage.gui.surface;
import yage.gui.style;
import yage.resource.dds;
import yage.resource.geometry;
import yage.resource.image;
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

import yage.resource.manager; // temporary for generateShader

private class ResourceInfo
{	uint id;   // OpenGL's handle
	uint time; // seconds from 1970, watch out for 2038!
	WeakReference!(Object) resource; // A weak reference, so when the resource is deleted, we know to delete this item also
	
	// Create ResourceInfo for a resource in map if it doesn't exist, or return it if it does
	static ResourceInfo getOrCreate(Object resource, HashMap!(uint, ResourceInfo) map)
	{	uint hash = resource.toHash();
		ResourceInfo* temp = (hash in map);
		ResourceInfo info;
		if (!temp)
		{	info = new ResourceInfo();
			map[hash] = info;
			info.resource = new WeakReference!(Object)(resource);
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
	///
	enum MatrixType
	{	PROJECTION = GL_TEXTURE, ///
		TEXTURE = GL_PROJECTION, ///
		TRANSFORM = GL_MODELVIEW ///
	}
	
	// A map from a resource's hash to it's resource info
	// Benchmarking shows this is slower than D's aa's, but using aa's here crashes for unknown reasons.
	protected HashMap!(uint, ResourceInfo) textures;
	protected HashMap!(uint, ResourceInfo) vbos;
	protected HashMap!(uint, ResourceInfo) shaders;
	
	public Matrix cameraInverse;
	protected Shader lastDrawnShader;
	bool[Shader] failedShaders;

	///
	this()
	{	textures = new HashMap!(uint, ResourceInfo);
		vbos = new HashMap!(uint, ResourceInfo);
		shaders = new HashMap!(uint, ResourceInfo);
	}
	
	///
	void bindCamera(CameraNode camera)
	{	current.camera = camera;
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		gluPerspective(camera.fov, camera.aspectRatio, camera.near, camera.far);
		glMatrixMode(GL_MODELVIEW);
	}
 	
	/**
	 * Enable these lights, disabling all others
	 * This function is used internally by the engine and normally doesn't need to be called from user-land. */	
	void bindLights(LightNode[] lights)
	{	int maxLights = Probe.feature(Probe.Feature.MAX_LIGHTS);
		assert (lights.length<=maxLights);
		
		foreach(num, light; lights)
		{	assert(light);
		
			// Used to compare this light's properties to the one currently bound to this slot.
			LightNode currentLight = current.lights[num];
		
			glPushMatrix();
			glLoadMatrixf(cameraInverse.v.ptr); // required for spotlights.
	
			// Set position and direction
			glEnable(GL_LIGHT0+num);
			auto type = light.type;
			Matrix transform_abs = light.getWorldTransform();
			
			Vec4f pos;
			pos.v[0..3] = transform_abs.v[12..15];
			pos.v[3] = type==LightNode.Type.DIRECTIONAL ? 0 : 1;
			glLightfv(GL_LIGHT0+num, GL_POSITION, pos.v.ptr);
	
			// Spotlight settings
			float angleDegrees = type == LightNode.Type.SPOT ? light.spotAngle*180/PI : 180;
			glLightf(GL_LIGHT0+num, GL_SPOT_CUTOFF, angleDegrees);
			if (type==LightNode.Type.SPOT)
			{	glLightf(GL_LIGHT0+num, GL_SPOT_EXPONENT, light.spotExponent);
				// transform_abs.v[8..11] is the opengl default spotlight direction (0, 0, 1),
				// rotated by the node's rotation.  This is opposite the default direction of cameras
				glLightfv(GL_LIGHT0+num, GL_SPOT_DIRECTION, transform_abs.v[8..11].ptr);
			}
			glPopMatrix();
	
			// Light material properties
			if (currentLight.ambient != light.ambient)
				glLightfv(GL_LIGHT0+num, GL_AMBIENT, light.ambient.vec4f.ptr);
			if (currentLight.diffuse != light.diffuse)
				glLightfv(GL_LIGHT0+num, GL_DIFFUSE, light.diffuse.vec4f.ptr);
			if (currentLight.specular != light.specular)
				glLightfv(GL_LIGHT0+num, GL_SPECULAR, light.specular.vec4f.ptr);
			
			// Attenuation properties TODO: only need to do this once per light
			if (currentLight.quadAttenuation != light.quadAttenuation)
			{	glLightf(GL_LIGHT0+num, GL_CONSTANT_ATTENUATION, 0); // requires a 1 but should be zero?
				glLightf(GL_LIGHT0+num, GL_LINEAR_ATTENUATION, 0);
				glLightf(GL_LIGHT0+num, GL_QUADRATIC_ATTENUATION, light.quadAttenuation);
			}
			
			current.lights[num] = light;
		}
		for (int i=lights.length; i<maxLights; i++)
			glDisable(GL_LIGHT0+i);
		
	}
	
	struct GLMatrix {
		void push(MatrixType type=MatrixType.TRANSFORM)
		{	if (type!=MatrixType.TRANSFORM) 
				glMatrixMode(type);
			glPushMatrix();
			if (type!=MatrixType.TRANSFORM) 
				glMatrixMode(GL_MODELVIEW);
		}
		void pop(MatrixType type=MatrixType.TRANSFORM)
		{	if (type!=MatrixType.TRANSFORM) 
				glMatrixMode(type);
			glPopMatrix();
			if (type!=MatrixType.TRANSFORM) 
				glMatrixMode(GL_MODELVIEW);
		}
		void load(Matrix matrix, MatrixType type=MatrixType.TRANSFORM)
		{	if (type!=MatrixType.TRANSFORM) 
				glMatrixMode(type);
			glLoadMatrixf(matrix.v.ptr);
			if (type!=MatrixType.TRANSFORM) 
				glMatrixMode(GL_MODELVIEW);
		}
		void loadIdentity(MatrixType type=MatrixType.TRANSFORM)
		{	if (type!=MatrixType.TRANSFORM) 
				glMatrixMode(type);
			glLoadIdentity();
			if (type!=MatrixType.TRANSFORM) 
				glMatrixMode(GL_MODELVIEW);
		}
		void multiply(Matrix matrix, MatrixType type=MatrixType.TRANSFORM)
		{	if (type!=MatrixType.TRANSFORM) 
				glMatrixMode(type);
			glMultMatrixf(matrix.v.ptr);
			if (type!=MatrixType.TRANSFORM) 
				glMatrixMode(GL_MODELVIEW);
		}
	}
	GLMatrix matrix;
	
	/**
	 * Profiling has shown that changing shaders, textures, and blending operations are the slowest parts of this funciton.
	 * TODO: This can be made faster by only changing the shader and blending when different from a previous pass.
	 * Params:
	 *     pass = 
	 *     lights = Array of LightNodes that affect this material.  Required if the pass's autoShader is not AutoShader.NONE.
	 * Returns: false if Not all of the textures or the shader couldn't be bound.  Even if this happens, as much of the
	 *     pass will be bound as possible, including as many textures as possible.
	 */
	bool bindPass(MaterialPass pass)
	{
		// convert nulls to defaults;					
		MaterialPass currentPass = current.pass;
		if (!currentPass)
			currentPass = defaultPass;
		if (!pass)
			pass = defaultPass;
		
		bool result = true;
		if (pass !is current.pass)
		{	if (pass.lighting)
			{	glEnable(GL_LIGHTING);
				glMaterialfv(GL_FRONT, GL_AMBIENT, pass.ambient.vec4f.ptr);
				glMaterialfv(GL_FRONT, GL_DIFFUSE, pass.diffuse.vec4f.ptr);
				glMaterialfv(GL_FRONT, GL_SPECULAR, pass.specular.vec4f.ptr);
				glMaterialfv(GL_FRONT, GL_EMISSION, pass.emissive.vec4f.ptr);
				glMaterialfv(GL_FRONT, GL_SHININESS, &pass.shininess);
				glColor4f(1, 1, 1, 1);
			} else
			{	glDisable(GL_LIGHTING);
				glMaterialfv(GL_FRONT, GL_AMBIENT, Vec4f().v.ptr);
				glMaterialfv(GL_FRONT, GL_DIFFUSE, Vec4f(1).v.ptr);
				glMaterialfv(GL_FRONT, GL_SPECULAR, Vec4f().v.ptr);
				glMaterialfv(GL_FRONT, GL_EMISSION, Vec4f().v.ptr);
				float s=0;
				glMaterialfv(GL_FRONT, GL_SHININESS, &s);
				glColor4fv(pass.diffuse.vec4f.ptr);
			}
			
			// Blend
			// TODO: If different than current blend
			if (pass.blend != currentPass.blend)
			{	if (pass.blend != MaterialPass.Blend.NONE)
				{	
					glEnable(GL_BLEND);
					glDepthMask(false);
					
					glDisable(GL_ALPHA_TEST);
					glAlphaFunc(GL_ALWAYS, 0);
					
					switch (pass.blend)
					{	case MaterialPass.Blend.ADD:
							glBlendFunc(GL_ONE, GL_ONE);
							break;
						case MaterialPass.Blend.AVERAGE:						
							glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
							break;
						case MaterialPass.Blend.MULTIPLY:
							glBlendFunc(GL_ZERO, GL_SRC_COLOR);
							break;
						default: break;
				}	}
				else
				{	glDisable(GL_BLEND);
					glDepthMask(pass.depthWrite);
					
					glEnable(GL_ALPHA_TEST);
					glAlphaFunc(GL_GREATER, 0.5f); // If blending is disabled, any pixel less than 0.5 opacity will not be drawn
				}
			}
			if (pass.depthRead)
				glEnable(GL_DEPTH_TEST);
			else
				glDisable(GL_DEPTH_TEST);
			
			// Polygon Mode
			if (pass.draw != currentPass.draw)
			{
				short cullMode = GL_FRONT; // TODO Use cull
				switch (pass.draw)
				{	case MaterialPass.Draw.POLYGONS:
						glPolygonMode(cullMode, GL_FILL);
						break;
					case MaterialPass.Draw.LINES:
						glPolygonMode(cullMode, GL_LINE);
						glLineWidth(pass.linePointSize);
						break;
					case MaterialPass.Draw.POINTS:
						glPolygonMode(cullMode, GL_POINT);
						glPointSize(pass.linePointSize);
						break;
				}
			}
			
			// Textures			
			result = result && bindTextures(pass.textures);
		}
		
		// Shader - uniforms may change so this must be called even if the pass is still the current pass.
		if (pass.shader)
		{	if (Probe.feature(Probe.Feature.SHADER))
			{	result = result && !(pass.shader in failedShaders);
				try {
					bindShader(pass.shader, pass.shaderUniforms);
				} catch (GraphicsException e)
				{	Log.info(e);
					result = false;
				}
			} else
				result = false;
		} else
			bindShader(null);
		
		current.pass = pass;
		return result;
	}

	// Part of a test to gt renderTargt to work with fbo's.
	uint fbo;
	uint renderBuffer;
	
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
			Texture texture = cast(Texture)target;
			if (texture)
			{
				// If FBO is supported, use it for texture rendering, otherwise render to framebuffer and copy the image.
				// FBO is currently disabled due to a bug.
				if (false && Probe.feature(Probe.Feature.FBO))
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
			
			Texture texture = cast(Texture)current.renderTarget;
			if (texture)
			{	
				// Framebufferobject currently disabled due to a bug
				if (false && Probe.feature(Probe.Feature.FBO))
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
					texture.format = Texture.Format.RGB8;
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
	{	if (scene !is current.scene)
		{	if (scene)
			{	if (scene.fogEnabled)
				{	glFogfv(GL_FOG_COLOR, scene.fogColor.vec4f.ptr);
					glFogf(GL_FOG_DENSITY, scene.fogDensity);
					glEnable(GL_FOG);
				} else
					glDisable(GL_FOG);
				
				Vec4f color = scene.backgroundColor.vec4f;
				glClearColor(color.x, color.y, color.z, color.w);
				glLightModelfv(GL_LIGHT_MODEL_AMBIENT, scene.ambient.vec4f.ptr);
				
			} else
			{	glFogfv(GL_FOG_COLOR, Vec4f(0).ptr);
				glFogf(GL_FOG_DENSITY, 1);
				glDisable(GL_FOG);				
				
				glClearColor(0, 0, 0, 0);
				glLightModelfv(GL_LIGHT_MODEL_AMBIENT, Vec4f(.2, .2, .2, 1).ptr);
		}	}
		current.scene = scene;
	}
	
	/**
	 * Make this shader program the currently active shader.
	 * It will be compiled if necessary.
	 * Params:
	 *     shader = 
	 *     variables = Unless specified otherwise, the currently bound textures specified by bindTextures will be bound
	 *         to uniform variables texture0, texture1, etc. */
	void bindShader(Shader shader, ShaderUniform[] variables=null)
	{	
		if (!Probe.feature(Probe.Feature.SHADER))
		{	if (shader) // allow at least binding null.
				throw new GraphicsException("OpenGL.bindShader() is only supported on hardware that supports shaders.");
			else
				return;
		}
		
		if (shader)
		{				
			if (shader in failedShaders)
				return;
			
			assert(shader.getVertexSource().length);
			assert(shader.getFragmentSource().length);
					
			ResourceInfo info = ResourceInfo.getOrCreate(shader, shaders);
			
			// Compile shader if not already compiled
			if (!info.id)	
				info.id = compileShader(shader);
			assert(info.id);
			
			if (shader !is current.shader)
			{	glUseProgramObjectARB(info.id);
			
				// Bind textures to "texture0", "texture1", etc. in the shader.
				static char[] glslTextureName = "texture0\0".dup;
				int maxTextures = Probe.feature(Probe.Feature.MAX_TEXTURE_UNITS);
				for (int i=0; i<maxTextures; i++)
				{	
					glslTextureName[7] = i + '0';
					int location = glGetUniformLocationARB(info.id, glslTextureName.ptr);
					if (location != -1)
						glUniform1iARB(location, i);
				}
			}
			
			// Bind uniform variables
			foreach (uniform; variables)
			{
				// Get the location of name.  TODO: Cache locations for names?  Profiling shows this is already fast?
				// Wrapping it in cache!() didn't improve performance.
				int location = glGetUniformLocationARB(info.id, uniform.name.ptr);				
				
				//int location = glGetUniformLocationARB(info.id, uniform.name.ptr);
				if (location == -1)
					throw new GraphicsException("Unable to set OpenGL shader uniform variable: %s", uniform.name);

				// Send the uniform data
				switch (uniform.type)
				{	case ShaderUniform.Type.F1:  glUniform1fARB(location, uniform.floatValues[0]);  break;
					case ShaderUniform.Type.F2:  glUniform2fvARB(location, 2, uniform.floatValues.ptr);  break;
					case ShaderUniform.Type.F3:  glUniform3fvARB(location, 3, uniform.floatValues.ptr);  break;
					case ShaderUniform.Type.F4:  glUniform4fvARB(location, 4, uniform.floatValues.ptr);  break;
					case ShaderUniform.Type.I1:  glUniform1ivARB(location, 1, uniform.intValues.ptr);  break;
					case ShaderUniform.Type.I2:  glUniform2ivARB(location, 2, uniform.intValues.ptr);  break;
					case ShaderUniform.Type.I3:  glUniform3ivARB(location, 3, uniform.intValues.ptr);  break;
					case ShaderUniform.Type.I4:  glUniform4ivARB(location, 4, uniform.intValues.ptr);  break;
					// TODO Other Matrix types
					case ShaderUniform.Type.M2x2: glUniformMatrix2fvARB(location, 4, false, uniform.floatValues.ptr);  break;
					case ShaderUniform.Type.M3x3: glUniformMatrix3fvARB(location, 9, false, uniform.floatValues.ptr);  break;
					case ShaderUniform.Type.M4x4: glUniformMatrix4fvARB(location, 16, false, uniform.floatValues.ptr);  break;
					default: break;
				}				
			}
		} else if (shader !is current.shader)
			glUseProgramObjectARB(0); // no shader
		
		current.shader = shader;		
	}
	
	/**
	 * Bind Textures for rendering.
	 * Params:
	 *     textures = Textures to be bound.  Texture units beyond the array length will be disabled.
	 * Returns:  True if all of the textures were bound.  Otherwise as many as possible will be bound. */
	bool bindTextures(TextureInstance[] textures)
	{		
		bool result = true;
		int maxLength = Probe.feature(Probe.Feature.MAX_TEXTURE_UNITS);
		if (textures.length > maxLength)
		{	textures.length = maxLength;
			result = false;			
		}
		
		// Set states used by all textures
		glMatrixMode(GL_TEXTURE);
		
		foreach (i, texture; textures)
		{
			// Skip if this texture is already bound
			if (current.textures.length > i && *current.textures[i] == texture)
				continue;
			
			// if Multitexturing supported, switch which texture we work with
			if (maxLength > 1)
			{	int GL_TEXTUREI_ARB = GL_TEXTURE0_ARB+i;
	
				// Activate texture unit and enable texturing
				glActiveTextureARB(GL_TEXTUREI_ARB);		
			}
			
			glLoadIdentity();
			glEnable(GL_TEXTURE_2D); // does this need to be done for all textures or just once?			
			
			Texture gpuTexture = texture.texture;
			assert(gpuTexture);
			ResourceInfo info = ResourceInfo.getOrCreate(gpuTexture, this.textures);
			
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
				Timer timer = new Timer(true);
				assert(gpuTexture.getImage() || gpuTexture.ddsFile.length);
				
				// Upload new image to graphics card memory
				Image image = gpuTexture.getImage();
				if (image)
				{
					// Convert auto format to a real format based on the image given.
					Texture.Format format;
					if (gpuTexture.getFormat() == Texture.Format.AUTO)
						switch(image.getChannels()) // This will support float formats when we switch to using Image2.
						{	case 1: format = Texture.Format.COMPRESSED_LUMINANCE; break;
							case 2: format = Texture.Format.COMPRESSED_LUMINANCE_ALPHA; break;
							case 3: format = Texture.Format.COMPRESSED_RGB; break;					
							case 4: format = Texture.Format.COMPRESSED_RGBA; break;					
							default: throw new ResourceException("Images with more than 4 channels are not supported.");
						}
					else if (gpuTexture.getFormat() == Texture.Format.AUTO_UNCOMPRESSED)
						switch(image.getChannels()) // This will support float formats when we switch to using Image2.
						{	case 1: format = Texture.Format.LUMINANCE8; break;
							case 2: format = Texture.Format.LUMINANCE8_ALPHA8; break;
							case 3: format = Texture.Format.RGB8; break;					
							case 4: format = Texture.Format.RGBA8; break;					
							default: throw new ResourceException("Images with more than 4 channels are not supported.");
						}
					
					// Convert from Texture.Format to OpenGL format constants.
					uint[Texture.Format] glFormatMap = [
						Texture.Format.COMPRESSED_LUMINANCE : GL_LUMINANCE,
						Texture.Format.COMPRESSED_LUMINANCE_ALPHA : GL_LUMINANCE_ALPHA,
						Texture.Format.COMPRESSED_RGB : GL_RGB,
						Texture.Format.COMPRESSED_RGBA : GL_RGBA,
						Texture.Format.LUMINANCE8 : GL_LUMINANCE,
						Texture.Format.LUMINANCE8_ALPHA8 : GL_LUMINANCE_ALPHA,
						Texture.Format.RGB8 : GL_RGB,
						Texture.Format.RGBA8 : GL_RGBA,				
					];
					uint[Texture.Format] glInternalFormatMap = [
						Texture.Format.COMPRESSED_LUMINANCE : GL_COMPRESSED_LUMINANCE,
						Texture.Format.COMPRESSED_LUMINANCE_ALPHA : GL_COMPRESSED_LUMINANCE_ALPHA,
						Texture.Format.COMPRESSED_RGB : GL_COMPRESSED_RGB,
						Texture.Format.COMPRESSED_RGBA : GL_COMPRESSED_RGBA,
						Texture.Format.LUMINANCE8 : GL_LUMINANCE,
						Texture.Format.LUMINANCE8_ALPHA8 : GL_LUMINANCE_ALPHA,
						Texture.Format.RGB8 : GL_RGB,
						Texture.Format.RGBA8 : GL_RGBA,				
					];			
					uint glFormat = glFormatMap[format];
					uint glInternalFormat = glInternalFormatMap[format];
					
	
					gpuTexture.width = image.getWidth();
					gpuTexture.height = image.getHeight();
					
					uint max = Probe.feature(Probe.Feature.MAX_TEXTURE_SIZE);
					uint new_width = image.getWidth();
					uint new_height= image.getHeight();
					
					// Ensure power of two sized if required
					if (!Probe.feature(Probe.Feature.NON_2_TEXTURE))
					{
						if (log2(new_height) != floor(log2(new_height)))
							new_height = nextPow2(new_height);
						if (log2(new_width) != floor(log2(new_width)))
							new_width = nextPow2(new_width);
	
						// Resize if necessary
						if (new_width != gpuTexture.width || new_height != gpuTexture.height)
							image = image.resize(min(new_width, max), min(new_height, max));
					}
						
					// Build mipmaps (doing it ourself is several times faster than gluBuild2DMipmaps,
					int level = 0;
					while(true) {
						glTexImage2D(GL_TEXTURE_2D, level, glInternalFormat, image.getWidth(), image.getHeight(), 0, glFormat, GL_UNSIGNED_BYTE, image.getData().ptr);
						level++;
						
						if (!gpuTexture.mipmap || image.getWidth() <= 4 || image.getHeight() <= 4)
							break;
						
						image = image.resize(image.getWidth()/2, image.getHeight()/2);
													
					}
					glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, level-1);
					
				} else if (gpuTexture.getDDSImageData() ){					
					
					// This block is from Bill Baxter's DDS loader, See license in resource/dds.d
					DDSImageData* ddsData = gpuTexture.getDDSImageData();
					if(ddsData) {
						int nHeight = ddsData.height;
						int nWidth = ddsData.width;
						int nNumMipMaps = ddsData.numMipMaps;
						int nBlockSize;
						if(ddsData.format == GL_COMPRESSED_RGBA_S3TC_DXT1_EXT)
							nBlockSize = 8;
						else
							nBlockSize = 16;
						glGenTextures(1, &info.id);
						glBindTexture(GL_TEXTURE_2D, info.id);
						glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
						glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
						int nSize;
						int nOffset = 0;
						// Load the mip-map levels
						for(int k = 0; k < nNumMipMaps; ++k) {
							if(nWidth == 0)
								nWidth = 1;
							if(nHeight == 0)
								nHeight = 1;
							nSize = ((nWidth + 3) / 4) * ((nHeight + 3) / 4) * nBlockSize;
							glCompressedTexImage2DARB(GL_TEXTURE_2D, k, ddsData.format, nWidth, nHeight, 0, nSize, &ddsData.pixels[0] + nOffset);
							nOffset += nSize;
							// Half the image size for the next mip-map level...
							nWidth = (nWidth / 2);
							nHeight = (nHeight / 2);
						}
					}
					// end resource/dds.d license
				}
				gpuTexture.dirty = false;
				gpuTexture.flipped = false;
				
				float time = timer.tell();
				float min = 0.05f;
				if (time > min)
					Log.info("Texture %s uploaded to video memory in %s seconds (times less than %.2fs are not logged)", 
						texture.texture.getSource(), time, min);
			}
			
			// Filtering
			if (texture.filter == TextureInstance.Filter.DEFAULT)
				texture.filter = TextureInstance.Filter.TRILINEAR;	// Create option to set this later
			switch(texture.filter)
			{	case TextureInstance.Filter.NONE:
					glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, gpuTexture.mipmap ?  GL_NEAREST_MIPMAP_NEAREST : GL_NEAREST);
					glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
					break;
				case TextureInstance.Filter.BILINEAR:
					glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, gpuTexture.mipmap ? GL_LINEAR_MIPMAP_NEAREST : GL_NEAREST);
					glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
					break;
				default:
				case TextureInstance.Filter.TRILINEAR:
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
			Vec2f padding = Vec2f(gpuTexture.getPadding().x, gpuTexture.getPadding().y) ;			
			
			// Apply special texture scaling/flipping
			if (texture.texture.flipped || padding.x>0 || padding.y > 0)
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
			{	case TextureInstance.Blend.ADD: blendTranslated = GL_ADD; break;
				case TextureInstance.Blend.AVERAGE: blendTranslated = GL_DECAL; break;
				case TextureInstance.Blend.NONE:
				case TextureInstance.Blend.MULTIPLY:
				default: blendTranslated = GL_MODULATE; break;				
			}
			glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, blendTranslated);

		}
		
		// Reset higher texture units
		for (int i=textures.length; i<maxLength; i++)
		{	
			if (maxLength > 1) // if multitexturing is supported.
			{	int GL_TEXTUREI_ARB = GL_TEXTURE0_ARB+i;
				glActiveTextureARB(GL_TEXTUREI_ARB);
			}
			
			glDisable(GL_TEXTURE_GEN_S);
			glDisable(GL_TEXTURE_GEN_T);
			glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
			glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
			glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
			
			glLoadIdentity();
			glBindTexture(GL_TEXTURE_2D, 0); // Shaders ignore glDisable(GL_TEXTURE_2D)
			glDisable(GL_TEXTURE_2D); // is this for just this state?	
		}
		
		// Undo state changes
		glMatrixMode(GL_MODELVIEW);
		if (textures.length > 1)
			glActiveTextureARB(GL_TEXTURE0_ARB);		
		
		current.textures = textures;
		return result;
	}

	/**
	 * Bind (and if necessary upload to video memory) a vertex buffer
	 * Params:
	 *   type = A vertex buffer type constant defined in Geometry or Mesh. */
	bool bindVertexBuffer(VertexBuffer vb, char[] type)
	{	if (vb)
			assert(type.length);
	
		// Skip binding if already bound and not dirty	
		if (!vb || !vb.dirty)
		{	auto currentVb = type in current.vertexBuffers;
			if (currentVb && (vb is *currentVb))
				return true;
		}
		
		uint vbo_type = type==Mesh.TRIANGLES ? 
			GL_ELEMENT_ARRAY_BUFFER_ARB :
			GL_ARRAY_BUFFER_ARB;
		
		bool supportsVbo = cast(bool)Probe.feature(Probe.Feature.VBO);
		bool useVbo;
		if (vb)
		{	useVbo = supportsVbo && vb.cache;

			// Bind vbo and update data if necessary.
			if (useVbo)
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
				{	glBufferDataARB(vbo_type, vb.data.length, vb.ptr, GL_STATIC_DRAW_ARB);
					vb.dirty = false;
			}	}
			else if (supportsVbo)
				glBindBufferARB(vbo_type, 0);
				
			// Bind the data			
			if (type==Geometry.VERTICES)
			{	glEnableClientState(GL_VERTEX_ARRAY);				
				glVertexPointer(vb.components, GL_FLOAT, 0, useVbo ? null : vb.ptr);
			}
			else if (type==Geometry.NORMALS)
			{	assert(vb.components == 3); // normals are always Vec3
				glEnableClientState(GL_NORMAL_ARRAY);
				glNormalPointer(GL_FLOAT, 0, useVbo ? null : vb.ptr);
			}
			else if (type[0..$-1]=="gl_MultiTexCoord")
			{	int i = type[$-1] - '0'; // convert ascii to ints
				int maxTextures = Probe.feature(Probe.Feature.MAX_TEXTURE_UNITS);
				if (i > maxTextures)
					return false;
				//	throw new GraphicsException("Cannot set texture coordinates for texture unit %s when only %s texture units are supported", i, maxTextures);
				if (maxTextures > 1)
				{	glClientActiveTextureARB(GL_TEXTURE0_ARB + i);
					
				}
				glEnableClientState(GL_TEXTURE_COORD_ARRAY);
				glTexCoordPointer(vb.components, GL_FLOAT, 0, useVbo ? null : vb.ptr);
				if (maxTextures > 1)
					glClientActiveTextureARB(GL_TEXTURE0_ARB);
			} 
			else if (type==Mesh.TRIANGLES || type==Mesh.LINES || type==Mesh.POINTS)
			{	// glBindBuffer was called above, no other action necessary
			}
			else
			{	// TODO: Pass to shader as vertex attribute
			}
		} else // unbind
		{	if (useVbo)
				glBindBufferARB(vbo_type, 0);
		

			if (type==Geometry.VERTICES)						
				glDisableClientState(GL_VERTEX_ARRAY);
			else if (type==Geometry.NORMALS)
				glDisableClientState(GL_NORMAL_ARRAY);			
			else if (type[0..$-1]=="gl_MultiTexCoord")
			{	int i = type[$-1] - 48; // convert ascii to ints
				int maxTextures = Probe.feature(Probe.Feature.MAX_TEXTURE_UNITS);
				if (i > maxTextures)
					return false;
				glClientActiveTextureARB(GL_TEXTURE0_ARB + i);
				glDisable(GL_TEXTURE_COORD_ARRAY);
				glClientActiveTextureARB(GL_TEXTURE0_ARB);
			}
		}
		current.vertexBuffers[type] = vb;
		return true;
	}
	
	
	/**
	 * Reset OpenGL state and free any resources from graphics memory are either:
	 * - haven't been used for longer than age,
	 * - are no longer referenced.
	 * If removed from graphics memory, they will be re-uploaded when needed again.
	 * Params:
	 *     age = maximum age (in seconds) of objects to keep.  Set to 0 to remove all items.  Defaults to 3600.
	 */
	void cleanup(uint age=3600)
	{	
		foreach (key, info; textures)
		{	if (info.resource.get() is null || info.time <= time(null)-age)
			{	glDeleteTextures(1, &info.id);
				textures.removeKey(key);
				delete info; // nothing else references it at this point.
		}	}
		foreach (key, info; vbos)
		{	if (info.resource.get() is null || info.time <= time(null)-age)
			{	glDeleteBuffersARB(1, &info.id);
				vbos.removeKey(key);
				delete info; // nothing else references it at this point.
		}	}
		
		foreach (key, info; shaders)
		{	if (info.resource.get() is null || info.time <= time(null)-age)
			{	glDeleteBuffersARB(1, &info.id);
				assert((cast(Shader)info.resource.get()) !is null);
				//(cast(Shader)info.resource.get()).failed = false;
				failedShaders.remove(cast(Shader)info.resource.get());
				shaders.removeKey(key);
				delete info; // nothing else references it at this point.
		}	}
		
		// Reset structure of currently bound objects
		Current newCurrent;
		current = newCurrent;
	}

	/**
	 * Draw the contents of a vertex buffer, such as a buffer of triangle indices.
	 * @param triangles If not null, this array of triangle indices will be used for drawing the mesh*/
	void drawPolygons(VertexBuffer polygons, char[] type, bool indexed=true)
	{	
		// Draw the polygons
		int useVbo = Probe.feature(Probe.Feature.VBO) && polygons.cache;
		if (indexed)
		{	bindVertexBuffer(polygons, type); // type is an indexed type
			if (type==Mesh.TRIANGLES)
				glDrawElements(GL_TRIANGLES, polygons.length()*3, GL_UNSIGNED_INT, useVbo ? null : polygons.ptr);
			else
				throw new GraphicsException("Unsupported polygon type %s", type);
		}		
		else
		{	bindVertexBuffer(polygons, Geometry.VERTICES);
			switch (type)
			{	case Mesh.TRIANGLES:
					glDrawArrays(GL_TRIANGLES, 0, polygons.length()*3);
					break;
				case Mesh.LINES:
					glDrawArrays(GL_LINES, 0, polygons.length());
					break;
				case Mesh.POINTS:
					glDrawArrays(GL_POINTS, 0, polygons.length());
					break;
				default:
					throw new GraphicsException("Unsupported polygon type %s", type);					
			}
		}
	}
	
	/// TODO
	void reset()
	{
		bindVertexBuffer(null, Geometry.VERTICES);
		bindVertexBuffer(null, Geometry.NORMALS);
		bindVertexBuffer(null, Geometry.TEXCOORDS0); // ...
		
		bindShader(null);
		bindPass(null);
		bindLights(null);
		bindTextures(null);
	}
	
	/*
	 * Compile a Shader and return its new OpenGL handle. 
	 * On failure, temporary opengl objects are cleaned up and an exception is thrown. */
	private int compileShader(Shader shader)
	{
		int result=0;
		
		// Mark as failed on exit, unless something sets failed to false.
		bool failed = true;
		scope(exit)
			if (failed)
				failedShaders[shader] = true;
			
		shader.compileLog = "";
		uint vertexObj, fragmentObj;
		
		// Cleanup on exit
		scope(exit)
		{	if (vertexObj) // Mark shader objects for deletion 
				glDeleteObjectARB(vertexObj); // so they'll be deleted when the shader program is deleted.
			if (fragmentObj)
				glDeleteObjectARB(fragmentObj);
		}
		scope(failure)
			if (result)
				glDeleteObjectARB(result);
		
		// Get OpenGL's log for a shader object.
		char[] getLog(uint id)
		{	int len;  char *log;
			glGetObjectParameterivARB(id, GL_OBJECT_INFO_LOG_LENGTH_ARB, &len);
			if (len > 0)
			{	log = (new char[len]).ptr;
				glGetInfoLogARB(id, len, &len, log);
			}
			return log[0..len];
		}
		
		// Compile a shader into object code.
		uint compile(char[] source, uint type)
		{
			// Compile this shader into a binary object					
			char* sourceZ = source.ptr;
			uint shaderObj = glCreateShaderObjectARB(type);
			glShaderSourceARB(shaderObj, 1, &sourceZ, null);
			glCompileShaderARB(shaderObj);
			
			// Get the compile log and check for errors
			char[] compileLog = getLog(shaderObj);
			shader.compileLog ~= compileLog;
			int status;
			glGetObjectParameterivARB(shaderObj, GL_OBJECT_COMPILE_STATUS_ARB, &status);
			if (!status)
				throw new GraphicsException("Could not compile %s shader.\nReason:  %s", 
					type==GL_VERTEX_SHADER_ARB ? "vertex" : "fragment", compileLog);
			
			return shaderObj;
		}
		
		// Compile
		vertexObj = compile(shader.getVertexSource(true), GL_VERTEX_SHADER_ARB);
		fragmentObj = compile(shader.getFragmentSource(true), GL_FRAGMENT_SHADER_ARB);
		assert(vertexObj);
		assert(fragmentObj);
		
		// Link
		result = glCreateProgramObjectARB();
		glAttachObjectARB(result, vertexObj);
		glAttachObjectARB(result, fragmentObj);
		glLinkProgramARB(result); // common failure point
		
		// Check for errors
		char[] linkLog = getLog(result);
		shader.compileLog ~= "\n"~linkLog;
		int status;
		glGetObjectParameterivARB(result, GL_OBJECT_LINK_STATUS_ARB, &status);
		if (!status)					
			throw new GraphicsException("Could not link the shaders.\nReason:  %s", linkLog);
		
		// Validate
		glValidateProgramARB(result);
		char[] validateLog = getLog(result);
		shader.compileLog ~= validateLog;
		int isValid;				
		glGetObjectParameterivARB(result, GL_VALIDATE_STATUS, &isValid);
		if (!isValid)
			throw new GraphicsException("Shader failed validation.\nReason:  %s", validateLog);
			
		failed = false;
		
		// Temporary?
		Log.info(shader.compileLog);
		
		return result;
	}
}