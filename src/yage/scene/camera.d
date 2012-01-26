/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.camera;

import tango.math.Math;
import tango.core.Thread;
import tango.core.WeakRef;
import yage.core.array;
import yage.core.color;
import yage.core.math.matrix;
import yage.core.math.plane;
import yage.core.math.vector;
import yage.scene.light;
import yage.scene.node;
import yage.scene.scene;
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

import yage.scene.sound;
import yage.resource.sound;


import yage.scene.model; // temporary

// TODO: Move these to Render?
struct RenderCommand
{	
	Matrix transform;
	Geometry geometry;
	Material[] materialOverrides;
	
	private ubyte lightsLength;
	private LightNode[8] lights; // indices in the RenderScene's array of RenderLights
	
	LightNode[] getLights()
	{	return lights[0..lightsLength];		 	              
	}
	
	void setLights(LightNode[] lights)
	{	lightsLength = lights.length;
		for (int i=0; i<lights.length; i++)
			this.lights[i] = lights[i];
	}
}

// Everything in a scene seen by the Camera.
struct RenderScene
{	Scene scene; // Is this used?
	ArrayBuilder!(RenderCommand) commands;
	ArrayBuilder!(LightNode) lights;
}

struct RenderList
{	RenderScene[] scenes; // one ArrayBuilder of commands for each scene to render.
	long timestamp;
	Matrix cameraInverse;
}

// Copies of SoundNode properties to provide lock-free access.
struct SoundCommand
{	Sound sound;
	Vec3f worldPosition;
	Vec3f worldVelocity;
	float pitch;
	float volume;
	float radius;
	float intensity; // used internally for sorting
	float position; // playback position
	size_t id;
	SoundNode soundNode; // original SoundNode.  Must be used behind lock!
	bool looping;
	bool reseek;
}

struct SoundList
{	ArrayBuilder!(SoundCommand) commands;
	long timestamp;
	Vec3f cameraPosition;
	Vec3f cameraRotation;
	Vec3f cameraVelocity;
}

/**
 * Without any rotation, the Camera looks in the direction of the -z axis.
 * TODO: More documentation. */
class CameraNode : Node
{
	float near = 1;			/// The camera's near plane.  Nothing closer than this will be rendered.  The default is 1.
	float far = 100000;		/// The camera's far plane.  Nothing further away than this will be rendered.  The default is 100,000.
	float fov = 45;			/// The field of view of the camera, in degrees.  The default is 45.
	float threshold = 1;	/// Nodes must be at least this diameter in pixels or they won't be rendered.
	float aspectRatio = 1.25;  /// The aspect ratio of the camera.  This is normally set automatically in Render.scene() based on the size of the Render Target.

	package int currentXres;	// Used internally for determining visibility
	package int currentYres;
	
	protected Plane[6] frustum;
	protected Vec3f frustumSphereCenter;
	protected float frustumSphereRadiusSquared;
	
	protected Plane[6] skyboxFrustum; // a special frustum with the camera centered at the origin of worldspace.	
	protected static CameraNode listener; // Camera that plays audio.

	struct TripleBuffer(T)
	{	T[3] lists;
		Object mutex;
		ubyte read=1;
		ubyte write=0;
		
		// Get a buffer for reading that is guaranteed to not currently being written.
		T getNextRead()
		{	synchronized (mutex)
			{	int next = 3-(read+write);
				if (lists[next].timestamp > lists[read].timestamp)
					read = next; // advance the read list only if what's available is newer.
				assert(read < 3);
				assert(read != write);
				
				return lists[read];
			}
		}
		
		// Get the next write buffer that is guaranteed to not currently being read
		private T* getNextWrite()
		{	synchronized (mutex)
			{	write = 3 - (read+write);
				assert(read < 3);
				assert(read != write);
				return &lists[write];
			}
		}
			
	}
	
	TripleBuffer!(SoundList) soundLists;
	TripleBuffer!(RenderList) renderLists;
	
	
	/**
	 * Get a render list for the scene and each of the skyboxes this camera sees. */
	RenderList getRenderList()
	{	return renderLists.getNextRead();
	}
	
	/**
	 * List of SoundCommands that this camera can hear, in order from loudest to most quiet. */
	SoundList getSoundList()
	{	return soundLists.getNextRead();
	}
	
	package void updateSoundCommands()
	{	
		assert(Thread.getThis() == scene.getUpdateThread());
		assert(getListener() is this);
	
		SoundList* list = soundLists.getNextWrite();
		list.commands.reserveAndClear(); // reset content
		
		Vec3f wp = getWorldPosition();
		scope allSounds = scene.getAllSounds();
		int i;
		foreach (soundNode; allSounds) // Make a deep copy of the scene's sounds 
		{	
			if (!soundNode.paused() && soundNode.getSound())
			{	//Log.write(2);
				SoundCommand command;
				command.intensity = soundNode.getVolumeAtPosition(wp);			
				if (command.intensity > 0.002) // A very quiet sound, arbitrary number	
				{	
					command.sound = soundNode.getSound();
					command.worldPosition = soundNode.getWorldPosition();
					command.worldVelocity = soundNode.getWorldVelocity();
					command.pitch = soundNode.pitch;
					command.volume = soundNode.volume;
					command.radius = soundNode.radius;
					command.looping = soundNode.looping;
					command.position = soundNode.tell();
					command.soundNode = soundNode;
					command.reseek = soundNode.reseek;
					soundNode.reseek = false; // the value has been consumed
					addSorted!(SoundCommand, float)(list.commands, command, false, (SoundCommand s) { return s.intensity; }); // fails!!!
				}
			}
			i++;
		}
		//Log.write("camera ", list.commands.length, " ", allSounds.length);
		list.timestamp = Clock.now().ticks(); // 100-nanosecond precision
		list.cameraPosition = getWorldPosition();
		list.cameraRotation = getWorldRotation();
		list.cameraVelocity = getWorldVelocity();
	}
	
	/*
	 * Cameras update a list of RenderCommands for every Scene they see.
	 * This is typically one Scene and its Skybox. */
	package void updateRenderCommands()
	{
		assert(Thread.getThis() == scene.getUpdateThread());
		
		currentXres = Window.getInstance().getHeight(); // TODO Break dependance on Window.
		currentYres = Window.getInstance().getHeight();
		
		void writeCommands(Node root, Plane[] frustum, LightNode[] lights, ref ArrayBuilder!(RenderCommand) result)
		{
			// Test this node for visibility
			VisibleNode vnode = cast(VisibleNode)root;
			if (vnode && vnode.getVisible()) 
			{
				/* // inlining doesn't help performance any.
				ModelNode m = cast(ModelNode)vnode;
				if (m)
				{	Vec3f wp = m.getWorldPosition();
					if (scene !is scene)
						wp += getWorldPosition();		
					
					if (isVisible(wp, m.getRadius()))	
					{	
						RenderCommand rc;			
						rc.transform = m.getWorldTransform().scale(m.getSize());
						rc.geometry = m.getModel();
						rc.materialOverrides = m.materialOverrides;
						rc.setLights(m.getLights(lights, 8));
						result.append(rc);
					}
				} else */
					vnode.getRenderCommands(this, lights, result);
			}
			
			// Recurse through and render children.
			foreach (Node c;  root.getChildren())
				writeCommands(c, frustum, lights, result);
		}
		
		// TODO: If this takes 1ms, it's still 15ms longer until this is called a second time that the renderer
		// can use this info!  Maybe we need a way to say we're done writing?
		// e.g. renderlists.performWrite(void (ref RenderList list) { ... });
		auto list = renderLists.getNextWrite();
		
		// Iterate through skyboxes, clearing out the RenderList commands and refilling them
		Scene currentScene = scene;
		int i=0;
		list.cameraInverse = getWorldTransform().inverse(); // must occur before the loop below
		list.timestamp = Clock.now().ticks(); // 100-nanosecond precision
		do {
			// Ensure we have a command set for this scene
			if (list.scenes.length <= i)
				list.scenes.length = i+1;
			else // clear out previous commands
				list.scenes[i].commands.reserveAndClear(); // reset content
			RenderScene* rs = &list.scenes[i];
			rs.scene = currentScene;

			// Add lights that affect what this camera can see.			
			int j;
			scope allLights = currentScene.getAllLights();
			rs.lights.length = allLights.length;
			foreach (ref light; allLights) // Make a deep copy of the scene's lights 
			{	rs.lights.data[j] = light.clone(false, rs.lights.data[j]); // to prevent locking when the render thread uses them.
				rs.lights.data[j].setPosition(light.getWorldPosition());
				rs.lights.data[j].cameraSpacePosition = light.getWorldPosition().transform(list.cameraInverse); 
				if (light.type == LightNode.Type.SPOT)
					rs.lights.data[j].setRotation(light.getWorldRotation());
				rs.lights.data[j].transform.worldPosition = rs.lights.data[j].position;
				rs.lights.data[j].transform.worldDirty = false; // hack to prevent it from being recalculated.
				j++;
			}
			
			writeCommands(currentScene, frustum, rs.lights.data, list.scenes[i].commands);
			i++;
		} while ((currentScene = currentScene.skyBox) !is null); // iterate through skyboxes
	}

	/**
	 * Construct */
	this()
	{	renderLists.mutex = new Object();
		soundLists.mutex = new Object();
		if (!listener)
			listener = this;
	}
	this(Node parent)
	{	this();
		if (parent)
		{	mixin(Sync!("scene"));
			parent.addChild(this);
		}
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
	{	mixin(Sync!("scene"));
		return null;
	}

	/*
	 * Unfinished!
	 * Get the 3d coordinate at the 2d screen coordinate at a distance of z from the camera.
	 * Params:
	 *     x = screen coordinate between 0 and 1, where 0 is the left side of the camrea's view, and 1 is the right.
	 *     x = screen coordinate between 0 and 1, where 0 is the left side of the camrea's view, and 1 is the right.  */ 
	Vec3f getWorldCoordinate(Vec2f screenCoordinate, float z)
	{	mixin(Sync!("scene"));
		Matrix clip;
		Matrix modl;
		
		// TODO!
		
		return Vec3f();
	}


	/*
	 * Calculate a 6-plane view frutum based on the orientation of the camera.*/
	Plane[] getFrustum(bool skybox=false)
	{	mixin(Sync!("scene"));
		return skybox ? skyboxFrustum : frustum;
	}
	
	/**
	 * Is this point/sphere within the view area of the camera and large enough to be drawn?
	 * Params:
	 *     point = Point in 3d space, in world coordinates
	 *     radius = Radius of this point (sphere).
	 *     frustum = Use this array of 6 planes as the view frustum instead of recalculating it.*/
	bool isVisible(Vec3f point, float radius, bool skybox=false)
	{	mixin(Sync!("scene"));
		Plane[] frustum = skybox ? skyboxFrustum : this.frustum;
		/*
		// See if it's inside the sphere.  Doesn't provide any benefit.
		if (!skybox)
			if ((point - frustumSphereCenter).length2() > frustumSphereRadiusSquared)
			{	//Log.write("early escape!");
				return false;
			}
		*/
		
		// See if it's inside the frustum
		float nr = -radius;
		foreach_reverse (f; frustum)
			if (f.x*point.x +f.y*point.y + f.z*point.z + f.d < nr) // plane distance-to-point function, expanded in-line.
				return false;
		
		// See if it's large enough to be drawn
		//Vec3f* cameraPosition = cast(Vec3f*)transform_abs.v[12..15].ptr;
		float distance2 = (getWorldPosition() - point).length2();
		return radius*radius*currentYres*currentYres > distance2*threshold*threshold;
	}
	
	/*
	 * Update the scene's list of cameras and add/remove listener reference to this CameraNode
	 * This should be protected, but making it anything but public causes it not to be called.
	 * Most likely a D bug. */
	override public void ancestorChange(Node old_ancestor)
	{	super.ancestorChange(old_ancestor); // must be called first so scene is set.
		
		Scene old_scene = old_ancestor ? old_ancestor.getScene() : null;	
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
	
	/*
	 * Update the frustums when the camera moves. */
	override protected void calcWorld()
	{	
		super.calcWorld();
		
		// Create the clipping matrix from the modelview and projection matrices
		Matrix projection = Matrix.createProjection(fov*3.1415927/180f, aspectRatio, near, far);
		//Log.write("camera ", worldRotation);
		Matrix model = Matrix.compose(transform.worldPosition, transform.worldRotation, transform.worldScale).inverse();
		(model*projection).getFrustum(frustum);
		
		model = transform.worldRotation.toMatrix().inverse(); // shed all but the rotation values
		(model*projection).getFrustum(skyboxFrustum);
		
		/*
		// TODO: Use frustum optimizations from: http://www.flipcode.com/archives/Frustum_Culling.shtml		
		
		// calculate the radius of the frustum sphere
		float fViewLen = far - near;

		// use some trig to find the height of the frustum at the far plane
		float fHeight = fViewLen * tan(fov*3.1415927/180 * 0.5f);

		// with an aspect ratio of 1, the width will be the same
		float fWidth = fHeight;

		// halfway point between near/far planes starting at the origin and extending along the z axis
		Vec3f P = Vec3f(0.0f, 0.0f, near + fViewLen * 0.5f);

		// the calculate far corner of the frustum
		Vec3f Q = Vec3f(fWidth, fHeight, fViewLen);

		// the vector between P and Q
		Vec3f vDiff = P - Q;

		// the radius becomes the length of this vector
		frustumSphereRadiusSquared = vDiff.length() * .5;
		frustumSphereRadiusSquared *= frustumSphereRadiusSquared;

		// get the look vector of the camera from the view matrix
		Vec3f vLookVector = Vec3f(0, 0, -1);
				
		auto worldTransform = Matrix.compose(worldPosition, worldRotation, worldScale);
		vLookVector = vLookVector.rotate(worldTransform);
		
		//m_mxView.LookVector(&vLookVector);

		// calculate the center of the sphere
		frustumSphereCenter = worldPosition + (vLookVector * (fViewLen * 0.5f) + near);
		//Log.write(frustumSphereCenter, frustumSphereRadiusSquared);
		*/
	}
}