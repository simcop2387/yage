/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.camera;

import derelict.opengl.gl;
import tango.math.Math;
import yage.core.array;
import yage.core.math.matrix;
import yage.core.math.plane;
import yage.core.math.vector;
import yage.scene.visible;
import yage.scene.node;
import yage.scene.scene;
import yage.scene.movable;
import yage.system.log;
import yage.system.system;
import yage.system.graphics.render;
import yage.system.window;


/**
 * A CameraNode renders everything it sees to a Texture.
 * Currently, several constraints are used that allow for render-to-texture
 * on hardware that only supports power-of-two sized textures.  In the future,
 * this will be dropped for a more robust but less backward-compatible solution.
 * Node that two Cameras cannot render concurrently since OpenGL itself
 * isn't threadsafe.*/
class CameraNode : MovableNode
{
	public float near = 1;			// the distance of the camera's near plane.
	public float far = 100000;		// camera's far plane
	public float fov = 45;			// field of view angle of the camera.
	public float aspect	= 0;		// aspect ratio of the view
	public float threshold = 2.25;	// minimum size of node in pixels before it's rendered. Stored as 1/(size^2)

	protected Plane[6] frustum;
	public Matrix inverse_absolute;	// Inverse of the camera's absolute matrix.
	
	protected static CameraNode listener; // Camera that plays audio.

	/**
	 * Construct */
	this()
	{	super();		
		if (!listener)
			listener = this;
	}

	/**
	 * Set the current listener to null if the listener is this CameraNode. */
	override void dispose()
	{	if (listener && listener == this)
			listener = null;
	}	

	/**
	 * Get six planes that make up the CameraNode's view frustum. */
	Plane[] getFrustum()
	{	return frustum;
	}

	/// Get the inverse of the camera's absolute matrix.
	public Matrix getInverseAbsoluteMatrix() {
		return inverse_absolute; 
	}
	
	/**
	 * Sound playback can occur from only one camera at a time.
	 * setListener() can be used to make this CameraNode the listener.
	 * getListener() will return, from all CameraNodes, the CameraNode that is the current listener.
	 * When there is no listener (listener is null), the first camera 
	 * added to a scene becomes the listener (not the first CameraNode created).
	 * The listener is set to null when the current listener is removed from its scene. */
	static CameraNode getListener()
	{	return listener;		
	}
	void setListener() /// ditto
	{	listener = this;		
	}
	
	/**
	 * Unfinished!
	 * Return the closest Node to the Camera in the Camera's Scene at the x, y
	 * coordinates in the Camera's Texture.  This will not return any Nodes from
	 * the Scene's skybox.  Returns null if no Node is at the position.*/
	VisibleNode getNodeAtCoordinate(int x, int y)
	{	return null;
	}

	/**
	 * Unfinished!
	 * Get the 3d coordinate at the 2d screen coordinate at a distance of z from the camera.
	 * Params:
	 *     x = screen coordinate between 0 and 1, where 0 is the left side of the camrea's view, and 1 is the right.
	 *     x = screen coordinate between 0 and 1, where 0 is the left side of the camrea's view, and 1 is the right.  */ 
	Vec3f getWorldCoordinate(Vec2f screenCoordinate, float z)
	{	Matrix clip;
		Matrix modl;

		glGetFloatv(GL_PROJECTION_MATRIX, clip.v.ptr);
		glGetFloatv(GL_MODELVIEW_MATRIX, modl.v.ptr);
		
		return Vec3f();
	}

	/**
	 * Set multiple variables that affect the camera's view.
	 * Params:
	 *     near = Nothing closer than this will be rendered.  The default is 1.
	 *     far = Nothing further away than this will be rendered.  The default is 100,000.
	 *     fov = The field of view of the camera, in degrees.  The default is 45.
	 *     apsect = The aspect ratio of the camera.  A special value of zero allows for
	 *         it to be set automatically by the Camera resolution.  Zero is also the default value.
	 *         threshold = Minimum size of a node in pixels before it's rendered.  The default
	 *         is 0.667 (2/3rds of a pixel).*/
	void setView(float near=1, float far=100000, float fov=45, float aspect=0, float threshold=0.667)
	{	this.near = near;
		this.far = far;
		this.fov = fov;
		this.aspect = aspect;
		this.threshold = 1/(threshold*threshold);
	}

	/**
	 * Get an array of all nodes that this camera can see.
	 * Params:
	 *     node = Root of the scenegraph to scan.  Defaults to the camera's scene.
	 *     lookaside = Optional buffer to use for result to avoid memory allocation. */
	ArrayBuilder!(VisibleNode) getVisibleNodes(Node root=null, inout ArrayBuilder!(VisibleNode) lookaside=ArrayBuilder!(VisibleNode)())
	{
		if (!root)
			root=scene;
		
		VisibleNode vnode = cast(VisibleNode)root;
		if (root.getVisible() && vnode)
		{	
			vnode.onscreen = true;

			float r = -vnode.getRadius() * vnode.getScale().max();			
			Matrix cam_abs  = getAbsoluteTransform(true);
			Matrix node_abs = vnode.getAbsoluteTransform(true);
			// Cull nodes that are not inside the frustum
			for (int i=0; i<frustum.length; i++)
			{	// formula for the plane distance-to-point function, expanded in-line.				
				//float[4] result = frustum[i].v * node_abs.v[12..16];				
				if (frustum[i].x*node_abs.v[12] + frustum[i].y*node_abs.v[13] + frustum[i].z*node_abs.v[14] + frustum[i].d < r)
				{	vnode.onscreen = false;
					break;
				}
			}

			// cull nodes that are too small to see.
			if (vnode.onscreen)
			{	float x = cam_abs.v[12]-node_abs.v[12];
				float y = cam_abs.v[13]-node_abs.v[13];
				float z = cam_abs.v[14]-node_abs.v[14];

				float height = 500; //yres;
				if (height==0)
					height = Window.getInstance().getHeight();
				if (r*r*height*height*threshold < x*x + y*y + z*z) // equivalent to r/dist < pixel threshold
					vnode.onscreen = false;
				else // Onscreen and big enough to draw
					lookaside ~= vnode;
			}
		}
		// Recurse through and render children.
		foreach (Node c; root.getChildren())
			getVisibleNodes(c, lookaside);
		
		return lookaside;
	}

	/*
	 * Calculate a 6-plane view frutum based on the orientation of the camera and
	 * the parameters passed to setView(). 
	 * This needs to be recalculated 
	 * 
	 * This needs to be rewritten to use the camera's transform matrix + fov and
	 * not rely on the current state of OpenGL's view matrix.
	 * It might also be good to put this in calcTransform() instead.*/
	public void buildFrustum(Scene scene)
	{	//assert(!transform_dirty);
		assert(System.isSystemThread()); // this shouldn't be necessary after removing the opengl calls.
		
		// Create the clipping matrix from the modelview and projection matrices
		Matrix clip, model;
		glGetFloatv(GL_PROJECTION_MATRIX, clip.v.ptr);
		glGetFloatv(GL_MODELVIEW_MATRIX, model.v.ptr);
		
		/*// Alternate approach that doesn't require glGetFloatv(GL_MODELVIEW_MATRIX
		  // This sometimes has issues with clipping the near plane.
		if (scene == this.scene)
			clip = getAbsoluteTransform().inverse() * clip;
		else
			clip = getAbsoluteTransform().toAxis().toMatrix().inverse() * clip;
		*/
		clip = model*clip;
		
		// Convert the clipping matrix to our six frustum planes.
		frustum[0] = Plane(clip[3]-clip[0], clip[7]-clip[4], clip[11]-clip[ 8], clip[15]-clip[12]);
		frustum[1] = Plane(clip[3]+clip[0], clip[7]+clip[4], clip[11]+clip[ 8], clip[15]+clip[12]);
		frustum[2] = Plane(clip[3]+clip[1], clip[7]+clip[5], clip[11]+clip[ 9], clip[15]+clip[13]);
		frustum[3] = Plane(clip[3]-clip[1], clip[7]-clip[5], clip[11]-clip[ 9], clip[15]-clip[13]);
		frustum[4] = Plane(clip[3]-clip[2], clip[7]-clip[6], clip[11]-clip[10], clip[15]-clip[14]);
		frustum[5] = Plane(clip[3]+clip[2], clip[7]+clip[6], clip[11]+clip[10], clip[15]+clip[14]);

		foreach (inout Plane p; frustum)
			p = p.normalize();
	}

	/*
	 * Update the scene's list of cameras and add/remove listener reference to this CameraNode
	 * This should be protected, but making it anything but public causes it not to be called.
	 * Most likely a D bug. */
	override public void ancestorChange(Node old_ancestor)
	{	super.ancestorChange(old_ancestor); // must be called first so scene is set.
		
		Scene old_scene = old_ancestor ? old_ancestor.scene : null;	
		if (old_scene)
			old_ancestor.scene.removeCamera(this);		
		if (scene && scene != old_scene) // if scene changed.
		{	scene.addCamera(this);
			if (!listener)
				listener = this;
		} else // no scene or scene didn't change
		{	if (!scene && listener == this)
				listener = null;			
		}
	}
}
