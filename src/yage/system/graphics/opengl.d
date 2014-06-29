/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.system.graphics.opengl;

import tango.stdc.time : time;
import tango.core.Traits;
// TODO this needs to be removed/reimplemented
// import tango.core.WeakRef;
import tango.math.Math;
import tango.stdc.stringz;
//import tango.util.container.HashMap;
import derelict.opengl3.gl;
import derelict.opengl3.ext;

import std.math : PI;

import yage.core.all;
import yage.gui.surface;
import yage.gui.style;
import yage.resource.dds;
import yage.resource.graphics.all;
import yage.resource.image;
import yage.resource.model;
import yage.scene.all;
import yage.scene.light;
import yage.scene.model;
import yage.scene.camera: CameraNode;
import yage.scene.visible;
import yage.system.window;
import yage.system.system;
import yage.system.graphics.api;
import yage.system.graphics.probe;
import yage.system.graphics.render;
import yage.system.log;

import yage.resource.manager; // temporary for generateShader

/// Replaces gluPerspective.
/// fovY     - Field of vision in degrees in the y direction
/// aspect   - Aspect ratio of the viewport
/// zNear    - The near clipping distance
/// zFar     - The far clipping distance
void gluPerspective(GLdouble fovY, GLdouble aspect, GLdouble zNear, GLdouble zFar)
{
    GLdouble fH = tan(fovY / 360 * PI) * zNear;
    GLdouble fW = fH * aspect;
    glFrustum(-fW, fW, -fH, fH, zNear, zFar);
}

private class ResourceInfo
{	uint id;   // OpenGL's handle
	long time; // seconds from 1970, watch out for 2038!
	// WeakReference!(Object) resource; // A weak reference, so when the resource is deleted, we know to delete this item also
	Object resource;

	// Create ResourceInfo for a resource in map if it doesn't exist, or return it if it does
	static ResourceInfo getOrCreate(Object resource, ResourceInfo[uint] map)
	{	uint hash = cast(uint) resource.toHash();
		ResourceInfo* temp = (hash in map);
		ResourceInfo info;
		if (!temp)
		{	info = new ResourceInfo();
			map[hash] = info;
			// MASSIVE TODO this needs to be a weak reference but that seems to be difficult to do right now?
			info.resource = resource; //new WeakReference!(Object)(resource);
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
 * should they ever be implemented. */
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
	//protected HashMap!(uint, ResourceInfo) textures;
	//protected HashMap!(uint, ResourceInfo) vbos;
	//protected HashMap!(uint, ResourceInfo) shaders;
	ResourceInfo[uint] textures;
	ResourceInfo[uint] vbos;
	ResourceInfo[uint] shaders;

	public Matrix cameraInverse;
	protected Shader lastDrawnShader;
	bool[Shader] failedShaders;

	///
	this()
	{	/*textures = new HashMap!(uint, ResourceInfo);
		vbos = new HashMap!(uint, ResourceInfo);
		shaders = new HashMap!(uint, ResourceInfo);*/
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
			glEnable(cast(uint)(GL_LIGHT0+num));
			auto type = light.type;
			Matrix transform_abs = light.getWorldTransform();

			Vec4f pos;
			pos.v[0..3] = transform_abs.v[12..15];
			pos.v[3] = type==LightNode.Type.DIRECTIONAL ? 0 : 1;
			glLightfv(cast(uint)(GL_LIGHT0+num), GL_POSITION, pos.v.ptr);

			// Spotlight settings
			float angleDegrees = type == LightNode.Type.SPOT ? light.spotAngle*180/PI : 180;
			glLightf(cast(uint)(GL_LIGHT0+num), GL_SPOT_CUTOFF, angleDegrees);
			if (type==LightNode.Type.SPOT)
			{	glLightf(cast(uint)(GL_LIGHT0+num), GL_SPOT_EXPONENT, light.spotExponent);
				// transform_abs.v[8..11] is the opengl default spotlight direction (0, 0, 1),
				// rotated by the node's rotation.  This is opposite the default direction of cameras
				glLightfv(cast(uint)(GL_LIGHT0+num), GL_SPOT_DIRECTION, transform_abs.v[8..11].ptr);
			}
			glPopMatrix();

			// Light material properties
			if (currentLight.ambient != light.ambient)
				glLightfv(cast(uint)(GL_LIGHT0+num), GL_AMBIENT, light.ambient.asVec4f.ptr);
			if (currentLight.diffuse != light.diffuse)
				glLightfv(cast(uint)(GL_LIGHT0+num), GL_DIFFUSE, light.diffuse.asVec4f.ptr);
			if (currentLight.specular != light.specular)
				glLightfv(cast(uint)(GL_LIGHT0+num), GL_SPECULAR, light.specular.asVec4f.ptr);

			// Attenuation properties TODO: only need to do this once per light
			if (currentLight.quadAttenuation != light.quadAttenuation)
			{	glLightf(cast(uint)(GL_LIGHT0+num), GL_CONSTANT_ATTENUATION, 0); // requires a 1 but should be zero?
				glLightf(cast(uint)(GL_LIGHT0+num), GL_LINEAR_ATTENUATION, 0);
				glLightf(cast(uint)(GL_LIGHT0+num), GL_QUADRATIC_ATTENUATION, light.quadAttenuation);
			}

			current.lights[num] = light;
		}
		for (ulong i=lights.length; i<maxLights; i++)
			glDisable(cast(uint)(GL_LIGHT0+i));

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
				glMaterialfv(GL_FRONT, GL_AMBIENT, pass.ambient.asVec4f.ptr);
				glMaterialfv(GL_FRONT, GL_DIFFUSE, pass.diffuse.asVec4f.ptr);
				glMaterialfv(GL_FRONT, GL_SPECULAR, pass.specular.asVec4f.ptr);
				glMaterialfv(GL_FRONT, GL_EMISSION, pass.emissive.asVec4f.ptr);
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
				glColor4fv(pass.diffuse.asVec4f.ptr);
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
					default: break; // do nothing in the default case
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

	// Part of a test to get renderTargt to work with fbo's.
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
					glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, cast(int)target.getWidth(), cast(int)target.getHeight());
					glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, renderBuffer);

					/// TODO: textures[texture].id will fail if Texture isn't bound.
					glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, textures[cast(uint)(texture.toHash())].id, 0);

					auto status = glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
				} else
					Window.getInstance().setViewport(Vec2i(0), Vec2i(cast(int)target.getWidth(), cast(int)target.getHeight()));
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
						texture.padding = Vec2ul(texture.width-viewportSize.x, texture.height-viewportSize.y);

					} else
					{	texture.width = viewportSize.x;
						texture.height = viewportSize.y;
						texture.padding = Vec2ul(0);
					}

					// TODO: textures[texture].id will fail if Texture isn't created.
					glBindTexture(GL_TEXTURE_2D, textures[cast(uint)(texture.toHash())].id);
					glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 0, 0, cast(int)texture.width, cast(int)texture.height, 0);
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
				{	glFogfv(GL_FOG_COLOR, scene.fogColor.asVec4f.ptr);
					glFogf(GL_FOG_DENSITY, scene.fogDensity);
					glEnable(GL_FOG);
				} else
					glDisable(GL_FOG);

				vec4f color = scene.backgroundColor.asVec4f;
				glClearColor(color.x, color.y, color.z, color.w);
				glLightModelfv(GL_LIGHT_MODEL_AMBIENT, scene.ambient.asVec4f.ptr);

			} else
			{	glFogfv(GL_FOG_COLOR, vec4f(0).ptr);
				glFogf(GL_FOG_DENSITY, 1);
				glDisable(GL_FOG);

				glClearColor(0, 0, 0, 0);
				glLightModelfv(GL_LIGHT_MODEL_AMBIENT, vec4f(.2, .2, .2, 1).ptr);
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
			{	glUseProgram(info.id);

				// Bind textures to "texture0", "texture1", etc. in the shader.
				string glslTextureName = "texture";
				int maxTextures = Probe.feature(Probe.Feature.MAX_TEXTURE_UNITS);
				for (int i=0; i<maxTextures; i++)
				{
					glslTextureName ~= cast(char)(i + '0');
					int location = glGetUniformLocation(info.id, glslTextureName.ptr);
					if (location != -1)
						glUniform1i(location, i);
				}
			}

			// Bind uniform variables
			foreach (uniform; variables)
			{
				// Get the location of name.  TODO: Cache locations for names?  Profiling shows this is already fast?
				// Wrapping it in cache!() didn't improve performance.
				int location = glGetUniformLocation(info.id, uniform.name.ptr);

				//int location = glGetUniformLocationARB(info.id, uniform.name.ptr);
				if (location == -1)
					throw new GraphicsException("Unable to set OpenGL shader uniform variable: %s", uniform.name);

				// Send the uniform data
				switch (uniform.type)
				{	case ShaderUniform.Type.F1:  glUniform1f(location, uniform.floatValues[0]);  break;
					case ShaderUniform.Type.F2:  glUniform2fv(location, 2, uniform.floatValues.ptr);  break;
					case ShaderUniform.Type.F3:  glUniform3fv(location, 3, uniform.floatValues.ptr);  break;
					case ShaderUniform.Type.F4:  glUniform4fv(location, 4, uniform.floatValues.ptr);  break;
					case ShaderUniform.Type.I1:  glUniform1iv(location, 1, uniform.intValues.ptr);  break;
					case ShaderUniform.Type.I2:  glUniform2iv(location, 2, uniform.intValues.ptr);  break;
					case ShaderUniform.Type.I3:  glUniform3iv(location, 3, uniform.intValues.ptr);  break;
					case ShaderUniform.Type.I4:  glUniform4iv(location, 4, uniform.intValues.ptr);  break;
					// TODO Other Matrix types
					case ShaderUniform.Type.M2x2: glUniformMatrix2fv(location, 4, false, uniform.floatValues.ptr);  break;
					case ShaderUniform.Type.M3x3: glUniformMatrix3fv(location, 9, false, uniform.floatValues.ptr);  break;
					case ShaderUniform.Type.M4x4: glUniformMatrix4fv(location, 16, false, uniform.floatValues.ptr);  break;
					default: break;
				}
			}
		} else if (shader !is current.shader)
			glUseProgram(0); // no shader

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
			// Skip if this texture is already bound to this unit.
			if (current.textures.length > i && *current.textures[i] == texture)
				continue;

			// if Multitexturing supported, switch which texture we work with
			if (maxLength > 1)
			{	uint GL_TEXTUREI_ARB = cast(uint)(GL_TEXTURE0+i);

				// Activate texture unit and enable texturing
				//glActiveTexture(GL_TEXTUREI_ARB); // FIXME this is crashing the program
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
					uint new_width = cast(uint) image.getWidth();
					uint new_height= cast(uint) image.getHeight();

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
						glTexImage2D(GL_TEXTURE_2D, level, glInternalFormat, cast(int) image.getWidth(), cast(int)image.getHeight(), 0, glFormat, GL_UNSIGNED_BYTE, image.getData().ptr);
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
						
						// TODO try to get this constant into Derelict GL3
						assert(ddsData.format != 0x83F1); // Make sure that we NEVER have the compressed data since at the moment I'm not supporting it since the library doesn't either
/*						if(ddsData.format == GL_COMPRESSED_RGBA_S3TC_DXT1_EXT)
							nBlockSize = 8;
						else*/
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
							glCompressedTexImage2D(GL_TEXTURE_2D, k, ddsData.format, nWidth, nHeight, 0, nSize, &ddsData.pixels[0] + nOffset);
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

			// Set filtering parameters
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
		for (ulong i=textures.length; i<maxLength; i++)
		{
			if (maxLength > 1) // if multitexturing is supported.
			{	int GL_TEXTUREI_ARB = cast(int) (GL_TEXTURE0+i);
				//glActiveTexture(GL_TEXTUREI_ARB);
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
			glActiveTexture(cast(int)GL_TEXTURE0);

		current.textures = textures;
		return result;
	}

	/**
	 * Bind (and if necessary upload to video memory) a vertex buffer
	 * Params:
	 *   type = A vertex buffer type constant defined in Geometry or Mesh. */
	bool bindVertexBuffer(VertexBuffer vb, string type)
	{	if (vb)
			assert(type.length);

		// Skip binding if already bound and not dirty
		if (!vb || !vb.dirty)
		{	auto currentVb = type in current.vertexBuffers;
			if (currentVb && (vb is *currentVb))
				return true;
		}

		uint vbo_type = type==Mesh.TRIANGLES ?
			GL_ELEMENT_ARRAY_BUFFER :
			GL_ARRAY_BUFFER;

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
				{       glGenBuffers(1, &info.id);
					vb.dirty = true;
				}
				// Bind buffer and update with new data if necessary.
				glBindBuffer(vbo_type, info.id);
				if (vb.dirty)
				{	glBufferData(vbo_type, vb.data.length, vb.ptr, GL_STATIC_DRAW);
					vb.dirty = false;
			}	}
			else if (supportsVbo)
				glBindBuffer(vbo_type, 0);

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
				{	glClientActiveTexture(cast(int)(GL_TEXTURE0 + i));

				}
				glEnableClientState(GL_TEXTURE_COORD_ARRAY);
				glTexCoordPointer(vb.components, GL_FLOAT, 0, useVbo ? null : vb.ptr);
				if (maxTextures > 1)
					glClientActiveTexture(cast(int)GL_TEXTURE0);
			}
			else if (type==Mesh.TRIANGLES || type==Mesh.LINES || type==Mesh.POINTS)
			{	// glBindBuffer was called above, no other action necessary
			}
			else
			{	// TODO: Pass to shader as vertex attribute
			}
		} else // unbind
		{	if (useVbo)
				glBindBuffer(vbo_type, 0);


			if (type==Geometry.VERTICES)
				glDisableClientState(GL_VERTEX_ARRAY);
			else if (type==Geometry.NORMALS)
				glDisableClientState(GL_NORMAL_ARRAY);
			else if (type[0..$-1]=="gl_MultiTexCoord")
			{	int i = type[$-1] - 48; // convert ascii to ints
				int maxTextures = Probe.feature(Probe.Feature.MAX_TEXTURE_UNITS);
				if (i > maxTextures)
					return false;
				glClientActiveTexture(cast(int)(GL_TEXTURE0 + i));
				glDisable(GL_TEXTURE_COORD_ARRAY);
				glClientActiveTexture(cast(int)GL_TEXTURE0);
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
		foreach (key; textures.byKey())
		{       ResourceInfo info = textures[key];
		        if (info.resource is null || info.time <= time(null)-age)
			{	glDeleteTextures(1, &info.id);
				textures.remove(key);
				delete info; // nothing else references it at this point.
		}	}
		foreach (key; vbos.byKey())
		{	ResourceInfo info = vbos[key];
		        if (info.resource is null || info.time <= time(null)-age)
			{	glDeleteBuffers(1, &info.id);
				vbos.remove(key);
				delete info; // nothing else references it at this point.
		}	}

		foreach (key; shaders.byKey())
		{	ResourceInfo info = shaders[key];
                        if (info.resource is null || info.time <= time(null)-age)
			{	glDeleteBuffers(1, &info.id);
				assert((cast(Shader)info.resource) !is null); // TODO This seems odd to me to be checking
				//(cast(Shader)info.resource.get()).failed = false;
				failedShaders.remove(cast(Shader)info.resource);
				shaders.remove(key);
				delete info; // nothing else references it at this point.
		}	}

		// Reset structure of currently bound objects
		Current newCurrent;
		current = newCurrent;
	}

	/**
	 * Draw the contents of a vertex buffer, such as a buffer of triangle indices.
	 * @param triangles If not null, this array of triangle indices will be used for drawing the mesh*/
	void drawPolygons(VertexBuffer polygons, string type, bool indexed=true)
	{
		// Draw the polygons
		int useVbo = Probe.feature(Probe.Feature.VBO) && polygons.cache;
		if (indexed)
		{	bindVertexBuffer(polygons, type); // type is an indexed type
			if (type==Mesh.TRIANGLES)
				glDrawElements(GL_TRIANGLES, cast(int) (polygons.length()*3), GL_UNSIGNED_INT, useVbo ? null : polygons.ptr);
			else
				throw new GraphicsException("Unsupported polygon type %s", type);
		}
		else
		{	bindVertexBuffer(polygons, Geometry.VERTICES);
			switch (type) // TODO MAKE THIS MORE UNDERSTANDABLE?
			{	case "GL_TRIANGLES": //Mesh.TRIANGLES:
					glDrawArrays(GL_TRIANGLES, 0, cast(int) (polygons.length()*3));
					break;
				case "GL_LINES": //Mesh.LINES:
					glDrawArrays(GL_LINES, 0, cast(int)(polygons.length()));
					break;
				case "GL_POINTS"://Mesh.POINTS:
					glDrawArrays(GL_POINTS, 0, cast(int)(polygons.length()));
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
				glDeleteShader(vertexObj); // so they'll be deleted when the shader program is deleted.
			if (fragmentObj)
				glDeleteShader(fragmentObj);
		}
		scope(failure)
			if (result)
				glDeleteProgram(result);

		// Get OpenGL's log for a shader object.
		string getLog(uint id)
		{	int len;  char *log;
			glGetShaderiv(id, GL_INFO_LOG_LENGTH, &len);
			if (len > 0)
			{	log = (new char[len]).ptr;
				glGetShaderInfoLog(id, len, &len, log);
			}
			return cast(string)(log[0..len]);
		}

		// Compile a shader into object code.
		uint compile(string source, uint type)
		{
			// Compile this shader into a binary object
			char* sourceZ = cast(char *)source.ptr;
			uint shaderObj = glCreateShader(type);
			glShaderSource(shaderObj, 1, &sourceZ, null);
			glCompileShader(shaderObj);

			// Get the compile log and check for errors
			string compileLog = getLog(shaderObj);
			shader.compileLog ~= compileLog;
			int status;
			glGetShaderiv(shaderObj, GL_COMPILE_STATUS, &status);
			if (!status)
				throw new GraphicsException("Could not compile %s shader.\nReason:  %s",
					type==GL_VERTEX_SHADER ? "vertex" : "fragment", compileLog);

			return shaderObj;
		}

		// Compile
		vertexObj = compile(shader.getVertexSource(true), GL_VERTEX_SHADER);
		fragmentObj = compile(shader.getFragmentSource(true), GL_FRAGMENT_SHADER);
		assert(vertexObj);
		assert(fragmentObj);

		// Link
		result = glCreateProgram();
		glAttachShader(result, vertexObj);
		glAttachShader(result, fragmentObj);
		glLinkProgram(result); // common failure point

		// Check for errors
		string linkLog = getLog(result); // TODO THIS WILL FAIL!
		shader.compileLog ~= "\n"~linkLog;
		int status;
		glGetProgramiv(result, GL_LINK_STATUS, &status);
		if (!status)
			throw new GraphicsException("Could not link the shaders.\nReason:  %s", linkLog);

		// Validate
		glValidateProgram(result);
		string validateLog = getLog(result); // TODO THIS WILL FAIL!
		shader.compileLog ~= validateLog;
		int isValid;
		glGetProgramiv(result, GL_VALIDATE_STATUS, &isValid);
		if (!isValid)
			throw new GraphicsException("Shader failed validation.\nReason:  %s", validateLog);

		failed = false;

		// Temporary?
		Log.info(shader.compileLog);

		return result;
	}
}
