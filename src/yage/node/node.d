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
import yage.node.moveable;
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
 * with position or velocity are separated into yage.node.moveable to keep things
 * tidier.
 *
 * See_Also:
 * yage.node.MoveableNode
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
class Node : BaseNode
{
	protected bool 	onscreen = true;	// used internally by cameras to mark if they can see this node.
	protected bool 	visible = true;
	protected Vec3f	scale;
	protected Color color;				// RGBA, used for glColor4f()
	protected float lifetime = float.infinity;	// in seconds

	protected LightNode[] lights;		// Lights that affect this Node
	protected float[]     intensities;	// stores the brightness of each light on this Node.

	/// Construct this Node as a child of parent.
	this(BaseNode parent)
	{	debug scope(failure) writef("Backtrace xx ",__FILE__,"(",__LINE__,")\n");
		visible = false;
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
	{
		debug scope(failure) writef("Backtrace xx ",__FILE__,"(",__LINE__,")\n");
		this(parent);

		visible = original.visible;
		scale = original.scale;
		color = original.color;
		lifetime = original.lifetime;

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
	Color getColor() { return color; }
	void setColor(Color color) { this.color = color; } /// Ditto
	void setColor(float r, float g, float b, float a=1)	{ color = Color(r, g, b, a); }	/// Ditto
	
	/**
	 * Get / set the lifeime of a Node (in seconds).
	 * The default value is float.infinity, but a lower number will cause the Node to be removed
	 * from the scene graph after that amount of time, as its lifetime is decreased with every Scene update.*/	
	float getLifetime() { return lifetime; }
	void setLifetime(float seconds) { lifetime = seconds; } /// Ditto

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
	void setScale(float x, float y, float z) { scale.set(x, y, z); }
	void setScale(Vec3f scale) { setScale(scale.x, scale.y, scale.z); } /// ditto
	void setScale(float scale){	setScale(scale, scale, scale); } /// ditto
	Vec3f getScale() { return scale; } /// ditto

	/** 
	 * Gt /set whether this Node will be rendered.  This has nothing to do with frustum culling.
	 * Setting a Node as invisible will not make its children invisible also. */
	void setVisible(bool visible) {	this.visible = visible;	}
	bool getVisible() { return visible; } /// ditto
	

	/// Remove this Node.  This function should be used instead of delete.
	void remove()
	{	debug scope(failure) writef("Backtrace xx ",__FILE__,"(",__LINE__,")\n");

		if (index != -1)
		{	yage.core.all.remove(parent.children, index, false);
			if (index < parent.children.length)
				parent.children[index].index = index;
			index = -1; // so remove can't be called twice.
		}
		// this needs to happen because some children (like lights) may need to do more in their remove() function.
		foreach(Node c; children)
			c.remove();
	}

	/**
	 * Set the parent of this Node (what it's attached to) and remove
	 * it from its previous parent.
	 * Returns: A self reference.*/
	Node setParent(BaseNode _parent)
	in { assert(_parent !is null);
	}body
	{	debug scope(failure) writef("Backtrace xx ",__FILE__,"(",__LINE__,")\n");

		if (index!=-1)
		{	yage.core.array.remove(children, index, false);
			if (index < parent.children.length) // if not removed from the end.
				parent.children[index].index = index; // update external index.
		}// Add to new parent
		parent = _parent;
		parent.children ~= this;
		index = parent.children.length-1;
		scene = parent.scene;
		setTransformDirty();
		return this;
	}


	/*
	 * Update the position and rotation of this node based on its velocity and angular velocity.
	 * This function is called automatically as a Scene's update() function recurses through Nodes.
	 * It normally doesn't need to be called manually.*/
	void update(float delta)
	{	debug scope( failure ) writef("Backtrace xx ",__FILE__,"(",__LINE__,")\n");

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
	 * All lights that affect this Node can't always be enabled, due to hardware and performance
	 * reasons, so only the lights that affect the node the most are enabled.
	 * This function is used internally by the engine and should not be called manually or exported.
	 *
	 * TODO: Take into account a spotlight inside a Node that shines outward but doesn't shine
	 * on the Node's center.  Need to test to see if this is even broken.
	 * Also perhaps use axis sorting for faster calculations. */
	void enableLights(ubyte number=8)
	{	debug scope(failure) writef("Backtrace xx ",__FILE__,"(",__LINE__,")\n");

		if (number>Device.getLimit(DEVICE_MAX_LIGHTS))
			number = Device.getLimit(DEVICE_MAX_LIGHTS);

		LightNode[] all_lights = scene.getLights();
		lights.length = max(cast(int)number, cast(int)all_lights.length);
		intensities.length = max(cast(int)number, cast(int)all_lights.length);

		// clear out old values
		for (int i=0; i<lights.length; i++)
		{	lights[i] = null;
			intensities[i] = 0;
		}

		// Calculate the intensity of all lights on this node
		Vec3f position;
		position.set(getAbsoluteTransform(true));
		for (int i=0; i<all_lights.length; i++)
		{	LightNode l = all_lights[i];

			// Add to the array of limited lights if bright enough
			float intensity = l.getBrightness(position, getRadius()).vec3f.average();
			intensities[i] = intensity;
			if (intensity > 0.00390625) // smallest noticeable brightness for 8-bit per channel color (1/256).
			{	for (int j=0; j<number; j++)
				{	// If first light
					if (lights[j] is null)
					{	lights[j] = l;
						break;
					}else // add to array of lights and shift others
					{	if (intensities[j] < intensity)
						{	// put this light at this spot in the array and shift the others
							for (int n=number-2; n>=j; n--)
								lights[n+1] = lights[n];
							lights[j] = l;
							break;
		}	}	}	}	}

		// Enable the apropriate lights
		for (int i=0; i<number; i++)
			glDisable(GL_LIGHT0+i);
		for (int i=0; i<number; i++)
		{	if (lights[i] !is null)
				lights[i].apply(i);
			else	// Make lights array just as long as it needs to be and no more.
			{	lights.length = i;
				break;
		}	}
	}

	/*
	 * Set whether this node is inside the current camera's view frustum.
	 * This function is used internally by the engine and doesn't normally need to be called manually. */
	void setOnscreen(bool onscreen)
	{	this.onscreen = onscreen;
	}

}
