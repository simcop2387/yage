/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.visible;

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
import yage.node.node;
import yage.node.movable;
import yage.system.constant;
import yage.system.device;
import yage.system.input;


/**
 * VisibleNode is the parent of all Nodes that are visible and can be rendered.
 * See_Also:
 * yage.node.MovableNode
 * yage.node.Node */
abstract class VisibleNode : MovableNode
{	
	protected bool 	visible = true;
	protected Vec3f	scale;
	protected Color color;				// RGBA, used for glColor4f()
	
	protected bool 	onscreen = true;	// used internally by cameras to mark if they can see this node.
	protected LightNode[] lights;		// Lights that affect this VisibleNode

	/// Construct as a child of parent.
	this(Node parent)
	{	visible = false;
		scale = Vec3f(1);
		color = Color("white");
		super(parent);
	}

	/// Construct as a child of parent, a copy of original and recursivly copy all children.
	this(Node parent, VisibleNode original)
	{	super(parent, original);
		visible = original.visible;
		scale = original.scale;
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
	{	return 1.732050807*scale.max();	// a value of zero would not be rendered since it's always smaller than the pixel threshold.
	}									// This is the radius of a 1x1x1 cube

	/**
	 * Get / set the scale of this VisibleNode in the x, y, and z directions.
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
