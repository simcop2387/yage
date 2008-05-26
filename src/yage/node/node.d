/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.node;

import std.math;
import std.stdio;
import std.traits;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;
import derelict.sdl.sdl;
import yage.core.all;
import yage.node.all;
import yage.node.scene;
import yage.node.light;
import yage.node.base;
import yage.node.movable;
import yage.system.constant;
import yage.system.device;
import yage.system.input;


/**
 * A Node is an instance of some tpe of object in a Scene.
 * Every node has an array of child nodes as well as a parent node, with
 * the obvious exception of a Scene whose parent is null.  When one node
 * is moved or rotated, all of its child nodes move and rotate as well.
 * Likewise, setting the position or rotation of a node does so relative
 * to its parent.  Rendering is done recursively from the Scene down
 * through every child node.  Likewise, updating of position and rotation
 * occurs recusively from Scene's update() method.  All Node methods that deal
 * with position or velocity are separated into yage.node.movable to keep things
 * tidier.
 *
 * See_Also:
 * yage.node.MovableNode
 * yage.node.BaseNode
 *
 * Example:
 * --------------------------------
 * Scene s = new Scene();
 * Node a = new Node(s);      // a is a child of s, it exists in Scene s.
 * a.setPosition(3, 5, 0);    // Position is set relative to 0, 0, 0 of the entire scene.
 * a.setRotation(0, 3.14, 0); // a is rotated PI radians (180 degrees) around the Y axis.
 *
 * Node b = new Node(a);      // b is a child of a, therefore,
 * b.setPosition(5, 0, 0);    // it's positoin and rotation are relative to a's.
 * b.getAbsolutePosition();   // Returns Vec3f(-2, 5, 0), b's position relative to the origin.
 *
 * b.setParent(s);            // B is now a child of s.
 * b.getAbsolutePosition();   // Returns Vec3f(5, 0, 0), since it's position is relative
 *                            //to 0, 0, 0, instead of a.
 * --------------------------------
 */
class Node : MovableNode
{
	protected bool 	onscreen = true;	// used internally by cameras to mark if they can see this node.
	protected bool 	visible = true;
	protected Vec3f	scale;
	protected Color color;				// RGBA, used for glColor4f()
	protected float lifetime = float.infinity;	// in seconds

	protected LightNode[] lights;		// Lights that affect this Node
	//protected float[]     intensities;	// stores the brightness of each light on this Node.

	/// Construct this Node as a child of parent.
	this(BaseNode parent)
	{	visible = false;
		scale = Vec3f(1);
		color = Color("white");
		setParent(parent);
	}

	/**
	 * Construct this Node as a copy of another Node and recursively copy all children.
	 * Params:
	 * parent = This Node will be a child of parent.
	 * original = This Node will be an exact copy of original.*/
	this(BaseNode parent, Node original)
	{	this(parent);

		visible = original.visible;
		scale = original.scale;
		color = original.color;
		lifetime = original.lifetime;
		on_update = original.on_update;

		// From BaseNode
		transform = original.transform;
		linear_velocity = original.linear_velocity;
		angular_velocity = original.angular_velocity;
		cache[0] = original.cache[0];	// in case of
		cache[1] = original.cache[1];	// a = new Node(scene, a);
		cache[2] = original.cache[2];

		// Also recursively copy every child
		foreach (inout Node c; original.children)
		{	// Scene and BaseNode are never children
			// Is there a better way to do this?
			switch (c.classinfo.name)
			{	case "yage.node.node.Node": new Node(this, cast(Node)c); break;
				case "yage.node.camera.CameraNode": new CameraNode(this, cast(CameraNode)c); break;
				case "yage.node.graph.GraphNode": new typeof(c)(this, cast(GraphNode)c); break;
				case "yage.node.light.LightNode": new LightNode(this, cast(LightNode)c); break;
				case "yage.node.model.ModelNode": new ModelNode(this, cast(ModelNode)c); break;
				case "yage.node.sound.SoundNode": new SoundNode(this, cast(SoundNode)c); break;
				case "yage.node.sprite.SpriteNode": new SpriteNode(this, cast(SpriteNode)c); break;
				case "yage.node.terrain.TerrainNode": new TerrainNode(this, cast(TerrainNode)c); break;				
				default:
			}
			/*
			new Object.factory(c.classinfo.name);
			auto ci = ClassInfo.find(classname);
			if (ci)
			{
			    return ci.create();
			}
			return null;
			*/
		}
	}

	
	/**
	 * Get / Set the color of the Node.
	 * Material colors of the Node are combined (multiplied) with this color.
	 * This provides an easy way to change the color of a Node without having to modify all materials individually.
	 * Default color is white and opaque (all 1's).*/
	Color getColor() 
	{	return color;
	}
	void setColor(Color color) /// Ditto
	{	this.color = color; 
	}	
	
	/**
	 * Get / set the lifeime of a Node (in seconds).
	 * The default value is float.infinity, but a lower number will cause the Node to be removed
	 * from the scene graph after that amount of time, as its lifetime is decreased with every Scene update.*/	
	float getLifetime() 
	{	return lifetime; 
	}
	void setLifetime(float seconds)  /// Ditto
	{	lifetime = seconds; 
	}
	
	/// Get an array of lights that were enabled in the last call to enableLights().	
	LightNode[] getLights()
	{	return lights;
	}

	/**
	 * Get whether this node is inside the view frustum and large enough to be drawn by
	 * the last camera that rendered it. */
	bool getOnscreen()
	{	return onscreen;
	}

	/// Get the radius of this Node's culling sphere.
	float getRadius()
	{	return 1.732050807*scale.max();	// a value of zero would not be rendered since it's always smaller than the pixel threshold.
	}									// This is the radius of a 1x1x1 cube

	/**
	 * Get / set the scale of this Node in the x, y, and z directions.
	 * The default is (1, 1, 1).  Unlike position and rotation, scale is not inherited. */	
	void setScale(float x, float y, float z) 
	{	scale.set(x, y, z); 
	}
	void setScale(Vec3f scale) /// ditto
	{	setScale(scale.x, scale.y, scale.z); 
	}
	void setScale(float scale) /// ditto
	{	setScale(scale, scale, scale); 
	} 
	Vec3f getScale() /// ditto
	{	return scale; 
	}

	/** 
	 * Gt /set whether this Node will be rendered.  This has nothing to do with frustum culling.
	 * Setting a Node as invisible will not make its children invisible also. */
	void setVisible(bool visible) 
	{	this.visible = visible;
	}
	bool getVisible()  /// ditto
	{	return visible;
	}
	
	/// Remove this Node.  This function should be used instead of delete.
	void remove()
	{	
		// this needs to happen because some children (like lights) may need to do more in their remove() function.
		foreach(Node c; children)
			c.remove();
		
		if (parent && this in parent.children)
			parent.children.remove(this);
	}

	/**
	 * Set the parent of this Node (what it's attached to) and remove
	 * it from its previous parent.
	 * Returns: A self reference.*/
	Node setParent(BaseNode _parent)
	in { assert(_parent !is null);
	}body
	{			
		if (parent && this in parent.children)
			parent.children.remove(this);
		
		// Add to new parent
		parent = _parent;
		parent.children[this] = this;
		scene = parent.scene;
		setTransformDirty();
		return this;
	}

	/*
	 * Update the position and rotation of this node based on its velocity and angular velocity.
	 * This function is called automatically as a Scene's update() function recurses through Nodes.
	 * It normally doesn't need to be called manually.*/
	void update(float delta)
	{	
		lifetime-= delta;

		// Move by linear velocity if not zero.
		if (linear_velocity.length2() != 0)
			move(linear_velocity*delta);

		// Rotate if angular velocity is not zero.
		if (angular_velocity.length2() !=0)
			rotate(angular_velocity*delta);

		// Recurse through children
		super.update(delta);

		if (lifetime <= 0)
			remove();
	}

	/*
	 * Enable the lights that most affect this Node.
	 * This should only be called from the rendering thread.
	 * All lights that affect this Node can't always be enabled, due to hardware and performance
	 * reasons, so only the lights that affect the node the most are enabled.
	 * This function is used internally by the engine and should not be called manually or exported.
	 *
	 * TODO: Take into account a spotlight inside a Node that shines outward but doesn't shine
	 * on the Node's center.  Need to test to see if this is even broken.
	 * Also perhaps use axis sorting for faster calculations. */
	void enableLights(ubyte number=8)
	{	
		if (number>Device.getLimit(DEVICE_MAX_LIGHTS))
			number = Device.getLimit(DEVICE_MAX_LIGHTS);
		lights.length = 0;
		
		// Prevent add/remove from array while calculating, since this is typically called from the rendering thread.
		synchronized (scene.lights_mutex)	
		{		
			LightNode[] all_lights = scene.getLights().values;
			
			// Calculate the intensity of all lights on this node
			Vec3f position;
			position.set(getAbsoluteTransform(true));
			for (int i=0; i<all_lights.length; i++)
			{	LightNode l = all_lights[i];
	
				// Add to the array of limited lights if bright enough
				l.intensity = l.getBrightness(position, getRadius()).vec3f.average();
				if (l.intensity > 0.00390625) // smallest noticeable brightness for 8-bit per channel color (1/256).
					lights.addSorted(l, false, (LightNode a) { return a.intensity; } );
		}	}
		
		// Enable the apropriate lights
		for (int i=0; i<number; i++)
			glDisable(GL_LIGHT0+i);
		for (int i=0; i<min(number, lights.length); i++)
			lights[i].apply(i);
	}

	/*
	 * Set whether this node is inside the current camera's view frustum.
	 * This function is used internally by the engine and doesn't normally need to be called manually. */
	void setOnscreen(bool onscreen)
	{	this.onscreen = onscreen;
	}

}
