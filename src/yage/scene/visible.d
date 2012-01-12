/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.visible;

import tango.math.Math;
import yage.core.all;
import yage.resource.geometry;
import yage.resource.material;
import yage.scene.camera;
import yage.scene.scene;
import yage.scene.light;
import yage.scene.node;
import yage.system.log;

/**
 * VisibleNode is the parent of all Nodes that are visible and can be rendered.
 * See_Also:
 * yage.scene.MovableNode
 * yage.scene.Node */
abstract class VisibleNode : Node
{	
	protected bool visible = true;
	protected Vec3f	size = Vec3f.ONE; // TODO: Deprecate this to make things more light-weight
	protected ArrayBuilder!(LightNode) lights;	// Lights that affect this VisibleNode
	Material[] materialOverrides;	/// Use thes materials instead of the model's meshes' or sprite's materials.

	this()
	{
	}
	this (Node parent)
	{	super(parent);
	}
	
	/**
	 * Make a duplicate of this node, unattached to any parent Node.
	 * Params:
	 *     children = recursively clone children (and descendants) and add them as children to the new Node.
	 * Returns: The cloned Node. */
	override Node clone(bool children=true, Node destination=null) // override should work, it's covariant!
	{	assert (!destination || cast(VisibleNode)destination);
		auto result = cast(VisibleNode)super.clone(children, destination);
		result.visible = visible;
		result.size = size;
		result.materialOverrides = materialOverrides;
		return result;
	}

	/**
	 * This is used to calculate intersectons of light spheres with this Node. */ 
	float getRadius()
	{	return 0;
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
	
	/**
	 * Get the geometry, materials, and affecting lights necessary to render this node.
	 * Params:
	 *     camera = 
	 *     lights = 
	 *     result = Results are appended to this ArrayBuilder to minimize allocation (or eliminiate it result has a reserve set--the typical case). */
	void getRenderCommands(CameraNode camera, LightNode[] lights, ref ArrayBuilder!(RenderCommand) result)
	{	// intenionally blank.  subclasses will override this method.
	}
	
	/*
	 * Find the lights that most affect the brightness of this Node.
	 * Params:
	 *     all_lights = array of lights to check.  No synchronization is performed 
	 *     so this array must remain unmodified for the duration of this function.
	 *     number = maximum number of lights to return.
	 *
	 * Also perhaps use axis sorting for faster calculations. 
	LightNode[] getLights(LightNode[] allLights, ubyte number=8)
	{	
		// Calculate the intensity of all lights on this node
		lights.length = number;
		lights.data[0..$] = null;
		Vec3f position;
		position.v[0..3] = (getWorldTransform()).v[12..15];
		float radius = getRadius();
		
		foreach (light; allLights)
		{	
			// First pass, discard lights that are too far away.  
			float lr = light.getLightRadius(); // [below] distance is greater than 8*radius.  At 8*radius, we have 1/256th brightness.
			if (light.getWorldPosition().distance2(position) < 256 * lr*lr)
			{	Color brightness = light.getBrightness(position, radius);
				light.intensity = (brightness.r + cast(int)brightness.g + brightness.b); // average of three-color brightness.
				
				// Second pass, discard lights that aren't bright enough.
				if (light.intensity > 3) // > 1/256ths of a color value
				{	replaceSmallestIfBigger(lights.data, light, (LightNode a, LightNode b) {
						if (!b)
							return true;
						return a.intensity > b.intensity;
					});
		}	}	}
		
		int i=0;
		for (; i<lights.data.length; i++)
			if (!lights.data[i])
				break;
		return lights.data[0..i]; // fail, replaced is called
	}*/

	LightNode[] getLights(LightNode[] allLights, ubyte number=8, ArrayBuilder!(LightNode) lookAside=ArrayBuilder!(LightNode)())
	{	
		// Calculate the intensity of all lights on this node
		
		lights.length = 0;
		Vec3f position;
		position.v[0..3] = getWorldTransform().v[12..15];

		foreach (l; allLights)
		{	
			float lr = l.getLightRadius(); // [below] distance is greater than 8*radius.  At 8*radius, we have 1/256th brightness.
			if (l.getWorldPosition().distance2(position) < 256 * lr*lr)
			{
				Color br = l.getBrightness(position, getRadius());
			
				l.intensity = br.r + cast(int)br.g + cast(int)br.b;
				if (l.intensity >= 3) // smallest noticeable brightness for 8-bit per channel color (1/256f).
					addSorted!(LightNode, int)(lights, l, false, (LightNode a){return a.intensity;}, number ); // not very efficient
			}
		}

		lights.reserve = lights.length; // prevent growing smaller to reduce allocations
		return lights.data;
	}
}
