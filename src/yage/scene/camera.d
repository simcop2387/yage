/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.camera;

import tango.math.Math;
import yage.core.array;
import yage.core.math.matrix;
import yage.core.math.plane;
import yage.core.math.vector;
import yage.core.parallel;
import yage.scene.visible;
import yage.scene.node;
import yage.scene.scene;
import yage.scene.movable;
import yage.system.log;
import yage.system.system;
import yage.system.graphics.render;
import yage.system.window;


/**
 * TODO: Document me. */
class CameraNode : MovableNode
{
	float near = 1;			/// The camera's near plane.  Nothing closer than this will be rendered.  The default is 1.
	float far = 100000;		/// The camera's far plane.  Nothing further away than this will be rendered.  The default is 100,000.
	float fov = 45;			/// The field of view of the camera, in degrees.  The default is 45.
	float threshold = 1;	/// Nodes must be at least this diameter in pixels or they won't be rendered.
	float aspectRatio = 1.25;  /// The aspect ratio of the camera.  This is normally set automatically in Render.scene() based on the size of the Render Target.

	Matrix inverse_absolute;	// Inverse of the camera's absolute matrix.
	
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
	
	/*
	 * Unfinished!
	 * This function casts a ray from the Camera's view into the scene
	 * and returns all Nodes that it collides with.
	 * This will not return any Nodes from the Scene's skybox.
	 * Params:
	 *     position = Coordinates between 0 and 1 in the camera's near view frustum.
	 *     includeBoundingSphere = If true, collision tests will only be performed against Object's bounding
	 *     sphere and not on a per-polygon basis.  The bounding sphere is determined by VisibleNode.getRadius().
	 * Returns:  An unsorted array of matching Nodes. */
	VisibleNode[] getNodesAtCoordinate(Vec2f position, bool includeBoundingSphere=false)
	{	return null;
	}

	/*
	 * Unfinished!
	 * Get the 3d coordinate at the 2d screen coordinate at a distance of z from the camera.
	 * Params:
	 *     x = screen coordinate between 0 and 1, where 0 is the left side of the camrea's view, and 1 is the right.
	 *     x = screen coordinate between 0 and 1, where 0 is the left side of the camrea's view, and 1 is the right.  */ 
	Vec3f getWorldCoordinate(Vec2f screenCoordinate, float z)
	{	Matrix clip;
		Matrix modl;

		//glGetFloatv(GL_PROJECTION_MATRIX, clip.v.ptr);
		//glGetFloatv(GL_MODELVIEW_MATRIX, modl.v.ptr);
		
		return Vec3f();
	}


	/*
	 * Calculate a 6-plane view frutum based on the orientation of the camera and
	 * the parameters passed to setView().*/
	Plane[] getFrustum(Scene scene=null, Plane[] lookAside=null)
	{	
		if (!scene)
			scene = this.scene;
		
		// Create the clipping matrix from the modelview and projection matrices
		Matrix projection = Matrix.createProjection(fov*3.1415927f/180f, aspectRatio, near, far);
		Matrix model = scene == this.scene ?
			getAbsoluteTransform(true).inverse() :
			getAbsoluteTransform(true).toAxis().toMatrix().inverse(); // shed all but the rotation values
		Matrix clip = model*projection;
		
		// Convert the clipping matrix to our six frustum planes.
		if (!lookAside.length)
			lookAside.length = 6;
		lookAside[0] = Plane(clip[3]-clip[0], clip[7]-clip[4], clip[11]-clip[ 8], clip[15]-clip[12]).normalize();
		lookAside[1] = Plane(clip[3]+clip[0], clip[7]+clip[4], clip[11]+clip[ 8], clip[15]+clip[12]).normalize();
		lookAside[2] = Plane(clip[3]+clip[1], clip[7]+clip[5], clip[11]+clip[ 9], clip[15]+clip[13]).normalize();
		lookAside[3] = Plane(clip[3]-clip[1], clip[7]-clip[5], clip[11]-clip[ 9], clip[15]-clip[13]).normalize();
		lookAside[4] = Plane(clip[3]-clip[2], clip[7]-clip[6], clip[11]-clip[10], clip[15]-clip[14]).normalize();
		lookAside[5] = Plane(clip[3]+clip[2], clip[7]+clip[6], clip[11]+clip[10], clip[15]+clip[14]).normalize();
		
		return lookAside;
	}
	
	/**
	 * Get an array of all nodes that this camera can see.
	 * Params:
	 *     node = Root of the scenegraph to scan.  Defaults to the camera's scene.
	 *     lookaside = Optional buffer to use for result to avoid memory allocation. */
	ArrayBuilder!(VisibleNode) getVisibleNodes(Scene scene=null, inout ArrayBuilder!(VisibleNode) lookAside=ArrayBuilder!(VisibleNode)())
	{
		ArrayBuilder!(VisibleNode) recurse(Node root, Plane[] frustum,  inout ArrayBuilder!(VisibleNode) lookAside)
		{
			// Test this node for visibility
			VisibleNode vnode = cast(VisibleNode)root;
			if (vnode && root.getVisible())
			{	
				float height = Window.getInstance().getHeight();
				Vec3f* position = cast(Vec3f*)vnode.cache[scene.transform_read].transform_abs.v[12..15].ptr;
				if (isVisible(*position, vnode.getRadius(), height, threshold, frustum))
					lookAside ~= vnode;
			}
			
			// Recurse through and render children.
			auto children = root.getChildren();
				foreach (Node c; children)
					recurse(c, frustum, lookAside);
				
			return lookAside;
		}
		
		// Get variables if we don't have them already
		if (!scene)
			scene=this.scene;
		Plane[6] frustum;
		getFrustum(scene, frustum);		
		
		return recurse(scene, frustum, lookAside);
	}
	
	/**
	 * Is this point/sphere within the view area of the camera and large enough to be drawn?
	 * Params:
	 *     point = Point in 3d space, in world coordinates
	 *     radius = Radius of this point (sphere).
	 *     totalHeight = Pixel height of the screen.
	 *     minHeight = Minimum pixel height of this object in order for it to be seen. 
	 *     frustum = Use this array of 6 planes as the view frustum instead of recalculating it.*/
	bool isVisible(Vec3f point, float radius, float totalHeight, float minHeight=1, Plane[] frustum=null)
	{
		if (frustum.length<6)
		{	Plane[6] temp;
			frustum = getFrustum(scene, frustum);
		}
		
		// See if it's inside the frustum
		float nr = -radius;
		foreach (f; frustum)
			if (f.x*point.x +f.y*point.y + f.z*point.z + f.d < nr) // plane distance-to-point function, expanded in-line.
				return false;
		
		// See if it's large enough to be drawn
		Vec3f* cameraPosition = cast(Vec3f*)cache[scene.transform_read].transform_abs.v[12..15].ptr;
		float distance2 = (*cameraPosition - point).length2();
		return radius*radius*totalHeight*totalHeight > distance2*minHeight*minHeight;
	}

	/*
	 * Update the scene's list of cameras and add/remove listener reference to this CameraNode
	 * This should be protected, but making it anything but public causes it not to be called.
	 * Most likely a D bug. */
	override public void ancestorChange(Node old_ancestor)
	{	super.ancestorChange(old_ancestor); // must be called first so scene is set.
		
		Scene old_scene = old_ancestor ? old_ancestor.scene : null;	
		if (scene !is old_scene)
		{	if (old_scene)
				old_scene.removeCamera(this);		
			if (scene) // if scene changed.
			{	scene.addCamera(this);
				if (!listener)
					listener = this;
			}
		}
	
		// no scene or scene didn't change			
		if (!scene && listener == this)
				listener = null;			
		
	}
	
	//  new:
	import tango.time.Clock;
	import yage.resource.geometry;
	import yage.resource.material;
	import yage.scene.light;
	import yage.system.graphics.probe;
	
	struct RenderNode
	{	Matrix transform;
		Geometry geometry;
		LightNode[] lights;
		Material[] materialOverrides;
	}
	
	// All of the information for rendering a scene
	struct RenderScene
	{	ArrayBuilder!(RenderNode)[3] buffers; // triple buffered for read, write, and swap
		long[3] timestamp;
		ubyte readBuffer=1;
		ubyte writebuffer;
		
		Object transformMutex;
		
		static RenderScene opCall()
		{	RenderScene result;
			result.transformMutex = new Object();
			return result;
		}
		
		/*
		 * Get the most up-to-date unused  buffer to read from. */
		ArrayBuilder!(RenderNode) getReadBuffer()
		{	synchronized (transformMutex)
			{	int next = 3-(readBuffer+writebuffer);
				if (timestamp[next] > timestamp[readBuffer])
					readBuffer = 3 - (readBuffer+writebuffer);
				assert(readBuffer < 3);
				assert(readBuffer != writebuffer);
				return buffers[readBuffer];
			}
		}

		/*
		 * Get an unused buffer for writing RenderNodes. */
		ArrayBuilder!(RenderNode) getWriteBuffer()
		{	synchronized (transformMutex)
			{	timestamp[writebuffer] = Clock.now().ticks();
				writebuffer = 3 - (readBuffer+writebuffer);
				assert(readBuffer < 3);
				assert(readBuffer != writebuffer);
				buffers[writebuffer].length = 0; // reset content
				return buffers[writebuffer];
			}
		}
	}
	
	RenderScene[Scene] renderScenes; // TODO: Scenes never get removed from here--scenes can reference a lot of other stuff!!!	
	
	void buildVisibleList(Scene scene=null)
	{
		// Get variables if we don't have them already
		if (!scene)
			scene=this.scene;
		Plane[6] frustum;
		getFrustum(scene, frustum);		
		int maxLights = Probe.feature(Probe.Feature.MAX_LIGHTS);
		scope LightNode[] allLights = scene.getAllLights(); // TODO: Cull lights against view frustum
		
		ArrayBuilder!(RenderNode) recurse(Node root, Plane[] frustum, LightNode[] lights, inout ArrayBuilder!(RenderNode) lookAside)
		{
			// Test this node for visibility
			VisibleNode vnode = cast(VisibleNode)root;
			if (vnode && vnode.getVisible())  // TODO: visibility should be inherited
			{	
				float height = Window.getInstance().getHeight();
				Matrix* transform = &vnode.cache[scene.transform_read].transform_abs;
				Vec3f* position = cast(Vec3f*)transform.v[12..15].ptr;
				if (isVisible(*position, vnode.getRadius(), height, threshold, frustum))
				{	// TODO: Move isVisible into vnode.getVisibleGeometry ?
					
					foreach (geometry; vnode.getVisibleGeometry(this))
					{	RenderNode rn;
						rn.transform = *transform;
						rn.geometry = geometry;
						//rn.lights = vnode.getLights(lights, 8, vnode.lights2);
						lookAside ~= rn;
					}
				}
			}
			
			// Recurse through and render children.
			auto children = root.getChildren();
				foreach (Node c; children)
					recurse(c, frustum, lights, lookAside);
				
			return lookAside;
		}
		
		// Get or create the RenderScene
		auto renderScene = scene in renderScenes;
		if (!renderScene)
		{	renderScenes[scene] = RenderScene();
			renderScene = scene in renderScenes;
		}
		//Log.trace("build");		
		recurse(scene, frustum, allLights, renderScene.getWriteBuffer());
	}
}


































