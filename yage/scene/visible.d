/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.visible;

import std.math;
import std.stdio;
import std.traits;
import derelict.opengl.gl;
import derelict.opengl.glu;
import derelict.opengl.glext;
import derelict.sdl.sdl;
import yage.core.all;
import yage.scene.all;
import yage.scene.scene;
import yage.scene.light;
import yage.scene.node;
import yage.scene.movable;
import yage.system.constant;
import yage.system.device;
import yage.system.input;


/**
 * VisibleNode is the parent of all Nodes that are visible and can be rendered.
 * See_Also:
 * yage.scene.MovableNode
 * yage.scene.Node */
abstract class VisibleNode : MovableNode
{	
	protected bool 	visible = true;
	protected Vec3f	size;
	protected Color color;				// RGBA, used for glColor4f()
	
	protected bool 	onscreen = true;	// used internally by cameras to mark if they can see this node.
	protected LightNode[] lights;		// Lights that affect this VisibleNode

	
	/// Construct as a child of parent.
	this(Node parent)
	{	size = Vec3f(1);
		color = Color("white");
		super(parent);
	}

	/// Construct as a child of parent, a copy of original and recursivly copy all children.
	this(Node parent, VisibleNode original)
	{	super(parent, original);
		visible = original.visible;
		size = original.size;
		color = original.color;
	}

	
	/**
	 * Get / Set the color of the VisibleNode.
	 * Material colors of the VisibleNode are combined (multiplied) with this color.
	 * This provides an easy way to change the color of a VisibleNode without having to modify all materials individually.
	 * Default color is white and opaque (all 1's).*/
	Color getColor() 
	{	return color;
	}
	void setColor(Color color) /// Ditto
	{	this.color = color; 
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
	/*
	 * Set whether this node is inside the current camera's view frustum.
	 * This function is used internally by the engine and doesn't normally need to be called manually. */
	void setOnscreen(bool onscreen)
	{	this.onscreen = onscreen;
	}

	/// Get the radius of this VisibleNode's culling sphere.
	float getRadius()
	{	return 1.732050807*size.max();	// a value of zero would not be rendered since it's always smaller than the pixel threshold.
	}									// This is the radius of a 1x1x1 cube

	/**
	 * Get / set the scale of this VisibleNode in the x, y, and z directions.
	 * The default is (1, 1, 1).  Unlike position and rotation, scale is not inherited. */	
	void setSize(float x, float y, float z) 
	{	size.set(x, y, z); 
	}
	void setSize(Vec3f size) /// ditto
	{	setSize(size.x, size.y, size.z); 
	}
	void setSize(float size) /// ditto
	{	setSize(size, size, size); 
	} 
	Vec3f getSize() /// ditto
	{	return size; 
	}

	/** 
	 * Gt /set whether this Node will be rendered.  This has nothing to do with frustum culling.
	 * Setting a VisibleNode as invisible will not make its children invisible also. */
	void setVisible(bool visible) 
	{	this.visible = visible;
	}
	bool getVisible()  /// ditto
	{	return visible;
	}

	/*
	 * Enable the lights that most affect this Node.
	 * This should only be called from the rendering thread.
	 * All lights that affect this Node can't always be enabled, due to hardware and performance
	 * reasons, so only the lights that affect the node the most are enabled.
	 * This function is used internally by the engine and should not be called manually or exported.
	 *
	 * TODO: Take into account a spotlight inside a VisibleNode that shines outward but doesn't shine
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

}
