/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.texture;


import std.string;
import std.math;
import std.stdio;
import derelict.sdl.sdl;
import derelict.sdl.image;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;
import yage.core.math;
import yage.core.matrix;
import yage.core.timer;
import yage.core.vector;
import yage.resource.exceptions;
import yage.resource.image;
import yage.resource.manager;
import yage.resource.resource;
import yage.system.device;
import yage.system.constant;
import yage.system.probe;
import yage.system.log;

// Used as default values for function params
private const Vec2f one = {v:[1.0f, 1.0f]};
private const Vec2f zero = {v:[0.0f, 0.0f]};


/**
 * An instance of a GPUTexture.
 * This allows many options to be set per instance of a GPUTexture instead of
 * creating multiple copies of the GPUTexture (and consuming valuable memory)
 * just to change filtering, clamping, or relative scale. */
struct Texture
{
	protected static int[int] translate;

	/// Set how this texture is blended with others in the same layer.
	/// See_Also: the TEXTURE_FILTER_* constants in yage.system.constant
	int blend = BLEND_NONE;

	/// Property enable or disable clamping of the textures of this layer.
	/// See_Also: <a href="http://en.wikipedia.org/wiki/Texel_%28graphics%29">The Wikipedia entry for texel</a>
	bool clamp = false;

	/// Environment map?
	bool reflective = false;

	/// Property to set the type of filtering used for the textures of this layer.
	/// See_Also: the TEXTURE_FILTER_* constants in yage.system.constant
	int filter = TEXTURE_FILTER_DEFAULT;

	/// Optional, the name of the sampler variable that uses this texture in the shader program.
	char[] name;

	/// TODO: Replace with texture matrix?
	Vec2f position;
	/// ditto
	float rotation=0;
	/// ditto
	Vec2f scale = {v:[1.0f, 1.0f]};
	
	Matrix transform;

	/// 
	GPUTexture texture;

	/// Create a new TextureInstance with the parameters specified.
	static Texture opCall(GPUTexture texture, bool clamp=false, int filter=TEXTURE_FILTER_DEFAULT,
			Vec2f position=zero, float rotation=0, Vec2f scale=one)
	{
		Texture result;
		result.texture = texture;
		result.clamp = clamp;
		result.filter = filter;
		result.position = position;
		result.rotation = rotation;
		result.scale = scale;
		return result;
	}

	/// Bind the Texture as the current OpenGL texture and apply its properties to the OpenGL state machine.
	void bind()
	{
		// Used to translate yage blending constants to opengl
		if (!translate.length)
		{	translate[BLEND_NONE] = GL_MODULATE;
			translate[BLEND_ADD] = GL_ADD;	// should GL_EXT_texture_env_add support be checked?
			translate[BLEND_AVERAGE] = GL_DECAL;
			translate[BLEND_MULTIPLY] = GL_MODULATE;
		}

		glBindTexture(GL_TEXTURE_2D, texture.gl_id);

		// Filtering
		if (filter == TEXTURE_FILTER_DEFAULT)
			filter = TEXTURE_FILTER_TRILINEAR;	// Create option to set this later
		switch(filter)
		{	case TEXTURE_FILTER_NONE:
				if (texture.mipmap)
					 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST);
				else glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
				break;
			case TEXTURE_FILTER_BILINEAR:
				if (texture.mipmap)
					 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_NEAREST);
				else glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
				break;
			default:
			case TEXTURE_FILTER_TRILINEAR:
				if (texture.mipmap)
					 glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
				else glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
				glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
				break;
		}

		// Clamping
		if (clamp)
		{	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
		}else // OpenGL Default
		{	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
			glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
		}


		// Texture Matrix operations
		if (position.length2() || scale.length2() || rotation!=0)
		{	glMatrixMode(GL_TEXTURE);
			glPushMatrix();
			glRotatef(rotation, 0, 0, 1);
			glTranslatef(position.x, position.y, 0);
			glScalef(scale.x, scale.y, 1);
			
			glMultMatrixf(transform.v.ptr);
			
			glMatrixMode(GL_MODELVIEW);
		}

		// Environment Mapping
		if (reflective)
		{	glEnable(GL_TEXTURE_GEN_S);
			glEnable(GL_TEXTURE_GEN_T);
			glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
			glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
		}

		// Blend Mode
		glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, translate[blend]);
	}

	/// Undo state changes caused by binding this TextureInstance.
	void unbind()
	{	// Texture Matrix
		if (position.length2() || scale.length2() || rotation!=0)
		{	glMatrixMode(GL_TEXTURE);
			glPopMatrix();
			glMatrixMode(GL_MODELVIEW);
		}

		// Environment Map
		if (reflective)
		{	glEnable(GL_TEXTURE_GEN_S);
			glEnable(GL_TEXTURE_GEN_T);
			glTexGeni(GL_S, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
			glTexGeni(GL_T, GL_TEXTURE_GEN_MODE, GL_SPHERE_MAP);
		}

		// Blend
		if (blend != BLEND_MULTIPLY)
			glTexEnvi(GL_TEXTURE_ENV, GL_TEXTURE_ENV_MODE, GL_MODULATE);
		
		glBindTexture(GL_TEXTURE_2D, 0);
	}

	///
	char[] toString()
	{	return "Texture";
	}
}


/**
 * A GPUTexture represents image data in video memory.
 *
 * Also, there's no need to be concerned about making
 * texture dimensions a power of two, as they're automatically resized up to
 * the next highest supported size if the non_power_of_two OpenGL extension
 * isn't supported in hardware.*/
class GPUTexture : Resource
{
	protected bool compress;
	protected bool mipmap;
	protected int format;

	protected uint gl_id  = 0;	// opengl index of this texture
	protected uint width     = 0;
	protected uint height    = 0;
	protected char[] source;
	
	uint requested_width   = 0;  // TODO: rename to padding, implement like Panda3D: 
	uint requested_height  = 0;	 // http://panda3d.org/wiki/index.php/Choosing_a_Texture_Size
	
	bool flipped = false; // TODO: Find a better solution, use texture matrix?
	
	///
	this()
	{	glGenTextures(1, &gl_id);
	
		// For some reason these need to be called or everything runs slowly.
		glBindTexture(GL_TEXTURE_2D, gl_id);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
		glBindTexture(GL_TEXTURE_2D, 0);
	}

	/**
	 * Create a Texture from an image.
	 * This is equivalent to calling the default constructor followed by upload().*/
	this(char[] filename, bool compress=true, bool mipmap=true)
	{	this();
		source = ResourceManager.resolvePath(filename);
		upload(new Image(source), compress, mipmap);
	}

	/// ditto
	this(Image image, bool compress=true, bool mipmap=true, char[] source_name="")
	{	this();
		source = source_name;
		upload(image, compress, mipmap);
	}

	
	~this()
	{	finalize();
	}
	
	/// Release OpenGL texture index.
	void finalize()
	{	if (gl_id)
		{	glDeleteTextures(1, &gl_id); 
			glDeleteTextures(1, &gl_id);
		}
	}

	/// Is texture compression used in video memory?
	bool getCompressed() { return compress; }

	/// Are mipmaps used?
	bool getMipmapped() { return mipmap; }

	/**
	 * Get the format of the Texture.
	 * See_Also: yage.system.constant */
	uint getFormat() { return format; }

	/// What is the OpenGL index of this texture?
	uint getId() { return gl_id; }

	/// Return the height of the Texture in pixels.
	uint getHeight() { return height; }

	/// Return the width of the Texture in pixels.
	uint getWidth() { return width; }

	///
	char[] getSource()
	{	return source;
	}

	/**
	 * Set the Texture from an Image.
	 * The image is uploaded into video memory and resized to a power of two if necessary.
	 * Params:
	 * image = The image to use for the Texture.
	 * compress = Compress the image in video memory.  This causes a slight loss of quality
	 * in exchange for four times less memory used.
	 * mipmap = Generate mipmaps.*/
	void upload(Image image, bool compress=true, bool mipmap=true)
	{
		this.compress = compress;
		this.mipmap = mipmap;
		this.format = image.getChannels();
		this.width = image.getWidth();
		this.height = image.getHeight();		

		glBindTexture(GL_TEXTURE_2D, gl_id);

		// Calculate formats
		uint glformat, glinternalformat;
		switch(format)
		{	case Image.FORMAT_GRAYSCALE:
				glformat = GL_LUMINANCE;
				glinternalformat = compress ? GL_COMPRESSED_LUMINANCE : GL_LUMINANCE;
				break;
			case Image.FORMAT_RGB:
				glformat = GL_RGB;
				glinternalformat = compress ? GL_COMPRESSED_RGB : GL_RGB;
				break;
			case Image.FORMAT_RGBA:
				glformat = GL_RGBA;
				glinternalformat = compress ? GL_COMPRESSED_RGBA : GL_RGBA;
				break;
			default:
				throw new ResourceManagerException("Unknown texture format" ~ .toString(format));
		}

	    // Upload image
		// TODO: Use image's built in resizer instead of glu.
		// glu has resizing issues with non power of two source textures.
	    if (mipmap)
	    	gluBuild2DMipmaps(GL_TEXTURE_2D, glinternalformat, image.getWidth(), image.getHeight(), glformat, GL_UNSIGNED_BYTE, image.getData().ptr);
	    else
		{	uint max = Probe.openGL(Probe.OpenGL.MAX_TEXTURE_SIZE);
			uint newwidth = image.getWidth();
			uint newheight= image.getHeight();

			// Ensure power of two sized if required
			//if (!Device.getSupport(DEVICE_NON_2_TEXTURE))
			if (true)
			{	if (log2(newheight) != floor(log2(newheight)))
					newheight = nextPow2(newheight);
				if (log2(newwidth) != floor(log2(newwidth)))
					newwidth = nextPow2(newwidth);
			}

			// Resize if necessary
			if (newwidth != width || newheight != height)
				image = image.resize(min(newwidth, max), min(newheight, max));

			// Uploading the texture to video memory is by far the slowest part of this function.
			glTexImage2D(GL_TEXTURE_2D, 0, glinternalformat, image.getWidth(), image.getHeight(), 0, glformat, GL_UNSIGNED_BYTE, image.getData().ptr);

		}
	    if(this.requested_width == 0) this.requested_width = this.getWidth();
	    if(this.requested_height == 0) this.requested_height = this.getHeight();
	}

	/// Copy the the contents of the framebuffer into this Texture.
	void loadFrameBuffer(uint width, uint height){
		// A special value of zero to stretch to the window size.
		if (width ==0) width  = Device.getWidth();
		if (height==0) height = Device.getHeight();

		// Needs to be tested.
		//if (!Device.getSupport(DEVICE_NON_2_TEXTURE))
		if (true)
		{	this.width = nextPow2(width);
			this.height =nextPow2(height);
		}

		glBindTexture(GL_TEXTURE_2D, gl_id);
		glCopyTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, 0, 0, this.width, this.height, 0);
		format = 3;
		
		requested_width  = width;
		requested_height = height;
	}
}