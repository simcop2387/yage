/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.camera;

import std.math;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;
import derelict.openal.al;
import derelict.sdl.sdl;
import yage.core.all;
import yage.resource.all;
import yage.resource.texture;
import yage.node.all;
import yage.node.node;
import yage.node.basenode;
import yage.system.constant;
import yage.system.device;
import yage.system.render;


/**
 * A CameraNode renders everything it sees to a Texture.
 * Currently, several constraints are used that allow for render-to-texture
 * on hardware that only supports power-of-two sized textures.  In the future,
 * this will be dropped for a more robust but less backward-compatible solution.
 * Node that two Cameras cannot render concurrently since OpenGL itself
 * isn't threadsafe.*/
class CameraNode : Node
{
	protected:
	uint  xres		= 0;		// special values of 0 to stretch to current display size.
	uint  yres		= 0;
	float near		= 1;		// the distance of the camera's near plane.
	float far		= 100000;	// camera's far plane
	float fov		= 45;		// field of view angle of the camera.
	float aspect	= 0;		// aspect ratio of the view
	float threshold = 2.25;		// minimum size of node in pixels before it's rendered. Stored as 1/(size^2)

	CameraTexture capture;		// The camera renders to this Texture
	Plane[6] frustum;
	uint node_count=0;			// The number of nodes that were rendered.

	Matrix inverse_absolute;	// Inverse of the camera's absolute matrix.

	public:
	/**
	 * Construct as the child of another node and initialize
	 * the capture Texture for rendering.*/
	this(BaseNode _parent)
	{	super(_parent);
		capture = new CameraTexture();
		capture.bind(true, TEXTURE_FILTER_BILINEAR);
		setResolution(xres, yres);
		setVisible(false);
	}

	/**
	 * Construct this Node as a copy of another Node and recursively copy all children.
	 * Params:
	 * parent = This Node will be a child of parent.
	 * original = This Node will be an exact copy of original.*/
	this (BaseNode parent, CameraNode original)
	{	super(parent, original);
		xres = original.xres;
		yres = original.yres;
		near = original.near;
		far  = original.far;
		fov  = original.fov;
		aspect = original.aspect;
		threshold = original.threshold;
	}

	/// Get the Texture that the camera renders to.
	CameraTexture getTexture()
	{	return capture;
	}

	/// Get the inverse of the camera's absolute matrix.  This is pre-calculated per call to .toTexture().
	Matrix getInverseAbsoluteMatrix()
	{	return inverse_absolute;
	}

	/// Get the number of Nodes on-screen after the last call to .toTexture().
	uint getNodeCount()
	{	return node_count;
	}

	/// x and y in screen coordinates, z is distance from camera. Unfinished
	void getWorldCoordinate(int x, int y, float z, Vec3f result)
	{	Matrix clip;
		Matrix modl;

		glGetFloatv(GL_PROJECTION_MATRIX, clip.v.ptr);
		glGetFloatv(GL_MODELVIEW_MATRIX, modl.v.ptr);
	}

	/**
	 * Return the closest Node to the Camera in the Camera's Scene at the x, y
	 * coordinates in the Camera's Texture.  This will not return any Nodes from
	 * the Scene's skybox.  Returns null if no Node is at the position.*/
	Node getNodeAtCoordinate(int x, int y)
	{
		return null;
	}

	/**
	 * Set multiple variables that affect the camera's view when .toTexture() is called.
	 * \param near Nothing closer than this will be rendered.  The default is 1.
	 * \param far Nothing further away than this will be rendered.  The default is 100,000.
	 * \param fov The field of view of the camera, in degrees.  The default is 45.
	 * \param apsect The aspect ratio of the camera.  A special value of zero allows for
	 * it to be set automatically by the size of the window (Device.getWidth() /
	 * Device.getHeight()).  Zero is also the default value.
	 * \param threshold Minimum size of a node in pixels before it's rendered.  The default
	 * is 0.667 (2/3rds of a pixel).*/
	void setView(float near=1, float far=100000, float fov=45, float aspect=0, float threshold=0.667)
	{	this.near = near;
		this.far = far;
		this.fov = fov;
		this.aspect = aspect;
		this.threshold = 1/(threshold*threshold);
	}

	/**
	 * Set the resolution of the texture that the camera renders to.
	 * Special values of zero set the resolution to the current window size.*/
	void setResolution(uint width, uint height)
	{	xres = width;
		yres = height;

		// Ensure our new resolution is below the maximum texture size
		uint max = Device.getLimit(DEVICE_MAX_TEXTURE_SIZE);
		if (xres > max)	xres = max;
		if (yres > max)	yres = max;
	}

	/**
	 * Build a 6-plane view frutum based on the orientation of the camera and
	 * the parameters passed to setView(). */
	protected void buildFrustum()
	{	// Create the clipping matrix from the modelview and projection matrices
		Matrix clip;
		Matrix modl;
		glGetFloatv(GL_PROJECTION_MATRIX, clip.v.ptr);
		glGetFloatv(GL_MODELVIEW_MATRIX, modl.v.ptr);
		clip = modl*clip;

		// Convert the clipping matrix to our six frustum planes.
		frustum[0].set(clip[3]-clip[0], clip[7]-clip[4], clip[11]-clip[ 8], clip[15]-clip[12]);
		frustum[1].set(clip[3]+clip[0], clip[7]+clip[4], clip[11]+clip[ 8], clip[15]+clip[12]);
		frustum[2].set(clip[3]+clip[1], clip[7]+clip[5], clip[11]+clip[ 9], clip[15]+clip[13]);
		frustum[3].set(clip[3]-clip[1], clip[7]-clip[5], clip[11]-clip[ 9], clip[15]-clip[13]);
		frustum[4].set(clip[3]-clip[2], clip[7]-clip[6], clip[11]-clip[10], clip[15]-clip[14]);
		frustum[5].set(clip[3]+clip[2], clip[7]+clip[6], clip[11]+clip[10], clip[15]+clip[14]);

		foreach (inout Plane p; frustum)
			p = p.normalize();
	}

	protected void renderScene(BaseNode node)
	{	// Recurse through and render children.
		foreach (Node c; node.getChildren())
			renderScene(c);
	}

	/// Render node and recursively every child Node to the framebuffer.
	protected void renderScene(Node node)
	{	node.setOnscreen(true);

		if (node.getVisible())
		{	float r = -node.getRadius();
			Matrix node_abs = node.getAbsoluteTransform();
			// Cull nodes that are not inside the frustum
			for (int i=0; i<frustum.length; i++)
			{	// formula for the plane distance-to-point function, expanded in-line.
				if (frustum[i].x*node_abs.v[12] + frustum[i].y*node_abs.v[13] + frustum[i].z*node_abs.v[14] + frustum[i].d < r)
				{	node.setOnscreen(false);
					break;
				}
			}

			// cull nodes that are too small to see.
			if (node.getOnscreen())
			{	float x = transform_abs.v[12]-node_abs.v[12];
				float y = transform_abs.v[13]-node_abs.v[13];
				float z = transform_abs.v[14]-node_abs.v[14];

				float height = yres;
				if (height==0)
					height = Device.getHeight();
				if (r*r*height*height*threshold < x*x + y*y + z*z) // equivalent to r/dist < pixel threshold
					node.setOnscreen(false);
				else // Onscreen and big enough to draw
				{	glPushMatrix();
					glMultMatrixf(node_abs.v.ptr);
					node.render();
					glPopMatrix();
					node_count++;
				}
			}
		}
		// Recurse through and render children.
		foreach (Node c; node.getChildren())
			renderScene(c);
	}

	/**
	 * Render everything seen by the camera to its own Texture.  The Texture can then be
	 * added to a material or used for any other purpose by using getTexture(). */
	void toTexture()
	{
		Device.setCurrentCamera(this);

		// Precalculate the inverse of the Camera's absolute transformation Matrix.
		calcTransform();
		inverse_absolute = transform_abs.inverse();

		// Resize viewport
		Device.resizeViewport(xres, yres, near, far, fov, aspect);

		// Rotate in reverse
		Quatrn rot = transform_abs.toQuatrn();
		Vec3f axis = rot.toAxis();
		float angle = axis.length();
		axis = axis.normalize();
		glRotatef(angle*57.295779513, -axis.x, -axis.y, -axis.z);

		// Draw the skybox
		if (scene.getSkybox() !is null)
		{	glClear(GL_DEPTH_BUFFER_BIT);
			// Reset the position to the origin for skybox rendering.
			float[3] push = transform_abs.v[12..15];
			transform_abs.v[12..15] = 0;
			buildFrustum(); // temporary frustum exclusively for skybox rendering.
			scene.getSkybox().apply();
			renderScene(scene.getSkybox());
			glClear(GL_DEPTH_BUFFER_BIT);
			transform_abs.v[12..15] = push[0..3]; // restore position
		}
		else
			glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		// Translate in reverse
		glTranslatef(-transform_abs.v[12], -transform_abs.v[13], -transform_abs.v[14]);

		// Build view frustum, cull, and render
		node_count=0;
		buildFrustum();
		scene.apply();
		renderScene(scene);

		Render.flush();

		// Copy framebuffer to our texture.
		//int modified_xres=xres, modified_yres=yres;
		//if (modified_xres ==0) modified_xres=Device.getWidth();
		//if (modified_yres ==0) modified_yres=Device.getHeight();
		//capture.loadFrameBuffer(mini(xres, Device.getWidth()), mini(xres, Device.getHeight()));

		// Copy framebuffer to our texture.
		int modified_xres=xres, modified_yres=yres;
		if (modified_xres > Device.getWidth()) modified_xres=Device.getWidth();
		if (modified_yres > Device.getHeight()) modified_yres=Device.getHeight();
		if (modified_xres ==0) modified_xres=Device.getWidth();
		if (modified_yres ==0) modified_yres=Device.getHeight();

		capture.loadFrameBuffer(modified_xres, modified_yres);
	}

	/// Give the new position and velocity of the camera to OpenAL
	/// Should setTransformDirty() be overridden instead?
	/// TODO--Allow only one camera to play sound.
	void update(float delta)
	{
		super.update(delta);

		// Give the camera's position, orientation, and velocity to OpenAL
		// Look is looking into the monitor
		// The positive y direction is up.
		Vec3f look = Vec3f(0, 0, -1).rotate(getAbsoluteTransform());
		Vec3f up = Vec3f(0, 1, 0).rotate(transform_abs);
		float[6] concat;
		concat[0..3] = look.v;
		concat[3..6] = up.v;

		alListenerfv(AL_POSITION, &transform_abs.v[12]);
		alListenerfv(AL_ORIENTATION, concat.ptr);
		alListenerfv(AL_VELOCITY, &linear_velocity_abs.v[0]);
	}
}
