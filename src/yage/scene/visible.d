/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.visible;

import std.math;
import std.stdio;
import std.traits;
import yage.core.all;
import yage.scene.all;
import yage.scene.scene;
import yage.scene.light;
import yage.scene.node;
import yage.scene.movable;
import yage.system.probe;
import yage.system.input;


/**
 * VisibleNode is the parent of all Nodes that are visible and can be rendered.
 * See_Also:
 * yage.scene.MovableNode
 * yage.scene.Node */
class VisibleNode : MovableNode
{	
	protected bool 	visible = true;
	protected Vec3f	size;
	protected Color color;				// RGBA, used for glColor4f()
	
	protected bool 	onscreen = true;	// used internally by cameras to mark if they can see this node.
	protected LightNode[] lights;		// Lights that affect this VisibleNode

	/**
	 * Construct */
	this()
	{	super();
		size = Vec3f(1);
		color = Color("white");			
	}

	/**
	 * Make a duplicate of this node, unattached to any parent Node.
	 * Params:
	 *     children = recursively clone children (and descendants) and add them as children to the new Node.
	 * Returns: The cloned Node. */
	override VisibleNode clone(bool children=false)
	{	auto result = cast(VisibleNode)super.clone(children);
		result.visible = visible; // atomic
		result.size = size;
		result.color = color; // atomic
		return result;
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
	 * Find the lights that most affect the brightness of this Node.
	 * Params:
	 *     all_lights = array of lights to check.  No synchronization is performed 
	 *     so this array must remain unmodified for the duration of this function.
	 *     number = maximum number of lights to return.
	 *
	 * TODO: Take into account a spotlight inside a VisibleNode that shines outward but doesn't shine
	 * on the Node's center.  Need to test to see if this is even broken.
	 * Also perhaps use axis sorting for faster calculations. */
	LightNode[] getLights(LightNode[] all_lights, ubyte number=8)
	{	
		// Calculate the intensity of all lights on this node
		lights.length = 0;
		Vec3f position;
		position.set(getAbsoluteTransform(true));
		
		/*
		// This i sprobably slower until maxRange can be sped up and no longer do allocations.
		lights = maxRange!(LightNode, float)(all_lights, min(number, all_lights.length), (LightNode l){
			return l.getBrightness(position, getRadius()).vec3f.average(); 
		}, 1/256f);
		lights.radixSort(false);
		return lights;
		*/
		
		foreach (l; all_lights)
		{	l.intensity = l.getBrightness(position, getRadius()).vec3f.average();
			if (l.intensity > 1/256) // smallest noticeable brightness for 8-bit per channel color (1/256).
				addSorted!(LightNode, float)(lights, l, false, (LightNode a){return a.intensity;}, number );
		}
		return lights;
	}
}
