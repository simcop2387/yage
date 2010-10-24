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
import yage.scene.light;
import yage.scene.node;
import yage.scene.scene;
import yage.scene.movable;
import yage.scene.visible;
import yage.system.log;
import yage.system.system;
import yage.system.window;

//  new:
import tango.time.Clock;
import yage.resource.geometry;
import yage.resource.material;
import yage.scene.light;
import yage.system.graphics.probe;


/**
 * TODO: Document me. */
class CameraNode : MovableNode
{
	float near = 1;			/// The camera's near plane.  Nothing closer than this will be rendered.  The default is 1.
	float far = 100000;		/// The camera's far plane.  Nothing further away than this will be rendered.  The default is 100,000.
	float fov = 45;			/// The field of view of the camera, in degrees.  The default is 45.
	float threshold = 1;	/// Nodes must be at least this diameter in pixels or they won't be rendered.
	float aspectRatio = 1.25;  /// The aspect ratio of the camera.  This is normally set automatically in Render.scene() based on the size of the Render Target.

	package int currentXres;		// Used internally for determining visibility
	package int currentYres;
	
	protected Plane[6] frustum;
	protected Plane[6] skyboxFrustum; // a special frustum with the camera centered at the origin of worldspace.	
	protected static CameraNode listener; // Camera that plays audio.
	
	struct RenderBuffer
	{	ArrayBuilder!(RenderCommand) commands;
		long timestamp;
		Matrix cameraInverse;
	}
	
	// All of the information for rendering a scene
	protected struct RenderScene
	{	
		RenderBuffer[3] buffers;
		ubyte readBuffer=1; // current read buffer
		ubyte writebuffer; // current write buffer		
		Object transformMutex;
		
		static RenderScene opCall()
		{	RenderScene result;
			result.transformMutex = new Object();
			return result;
		}
		
		/*
		 * Get the most up-to-date unused  buffer to read from. */
		RenderBuffer* getReadBuffer()
		{	synchronized (transformMutex)
			{	int next = 3-(readBuffer+writebuffer);
				if (buffers[next].timestamp > buffers[readBuffer].timestamp)
					readBuffer = next; // advance the read buffer only if what's available is newer.
				assert(readBuffer < 3);
				assert(readBuffer != writebuffer);
				return &buffers[readBuffer];
			}
		}

		/*
		 * Get an unused buffer for writing RenderNodes. */
		RenderBuffer* getWriteBuffer()
		{	synchronized (transformMutex)
			{	buffers[writebuffer].timestamp = Clock.now().ticks();
				writebuffer = 3 - (readBuffer+writebuffer);
				assert(readBuffer < 3);
				assert(readBuffer != writebuffer);
				auto result = &buffers[writebuffer];
				if(result.commands.reserve < result.commands.length)  // prevent allocated size from shrinking
					result.commands.reserve = result.commands.length;
				result.commands.length = 0; // reset content
				return result;
			}
		}
	}

	protected RenderScene[Scene] renderScenes; // TODO: Scenes never get removed from here--scenes can reference a lot of other stuff!!!	


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
	 * Calculate a 6-plane view frutum based on the orientation of the camera.*/
	Plane[] getFrustum(bool skybox=false)
	{	return skybox ? skyboxFrustum : frustum;
	}
	
	/**
	 * Is this point/sphere within the view area of the camera and large enough to be drawn?
	 * Params:
	 *     point = Point in 3d space, in world coordinates
	 *     radius = Radius of this point (sphere).
	 *     frustum = Use this array of 6 planes as the view frustum instead of recalculating it.*/
	bool isVisible(Vec3f point, float radius, bool skybox=false)
	{	
		Plane[] frustum = skybox ? skyboxFrustum : this.frustum;
		
		// See if it's inside the frustum
		float nr = -radius;
		foreach (f; frustum)
			if (f.x*point.x +f.y*point.y + f.z*point.z + f.d < nr) // plane distance-to-point function, expanded in-line.
				return false;
		
		// See if it's large enough to be drawn
		Vec3f* cameraPosition = cast(Vec3f*)transform_abs.v[12..15].ptr;
		float distance2 = (*cameraPosition - point).length2();
		return radius*radius*currentYres*currentYres > distance2*threshold*threshold;
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
	
	
	package void updateRenderCommands(Scene scene=null)
	{
		currentXres = Window.getInstance().getHeight(); // TODO Break dependance on Window.
		currentYres = Window.getInstance().getHeight();
		
		// Get variables if we don't have them already
		if (!scene)
			scene=this.scene;
		
		int maxLights = Probe.feature(Probe.Feature.MAX_LIGHTS);
		scope LightNode[] allLights = scene.getAllLights(); // TODO: Cull lights against view frustum
		
		void recurse(Node root, Plane[] frustum, LightNode[] lights, ref ArrayBuilder!(RenderCommand) result)
		{
			// Test this node for visibility
			VisibleNode vnode = cast(VisibleNode)root;
			if (vnode && vnode.getVisible()) 
				vnode.getRenderCommands(this, lights, result);
			
			// Recurse through and render children.
			foreach (Node c;  root.getChildren())
				recurse(c, frustum, lights, result);
		}
		
		// Get or create the RenderScene
		auto renderScene = scene in renderScenes;
		if (!renderScene)
		{	renderScenes[scene] = RenderScene();
			renderScene = scene in renderScenes;
		}
		
		auto buffer = renderScene.getWriteBuffer();
		buffer.cameraInverse = getAbsoluteTransform().inverse();
		recurse(scene, frustum, allLights, buffer.commands);
	}
	
	RenderBuffer getRenderBuffer(Scene scene)
	{	auto renderScene = scene in renderScenes;
		if (renderScene)
			return *renderScene.getReadBuffer();
		
		// Small hack.  Make up a render buffer.
		// Sometimes this is called before the first update loop finishes.
		RenderBuffer result;
		result.cameraInverse = getAbsoluteTransform().inverse();
		result.timestamp = Clock.now().ticks();
		return result;
	}
	
	/*
	 * Update the frustums when the camera moves. */
	protected void calcTransform()
	{	super.calcTransform();
		
		// Create the clipping matrix from the modelview and projection matrices
		Matrix projection = Matrix.createProjection(fov*3.1415927f/180f, aspectRatio, near, far);
		Matrix model = getAbsoluteTransform(true).inverse();
		(model*projection).getFrustum(frustum);
		
		model = getAbsoluteTransform(true).toAxis().toMatrix().inverse(); // shed all but the rotation values
		(model*projection).getFrustum(skyboxFrustum);
	}
}