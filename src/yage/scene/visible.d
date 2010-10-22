/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.visible;

import tango.math.Math;
import tango.util.container.more.Heap;
import yage.core.all;
import yage.resource.geometry;
import yage.resource.material;
import yage.scene.camera;
import yage.scene.scene;
import yage.scene.light;
import yage.scene.node;
import yage.scene.movable;
import yage.system.log;

struct RenderCommand
{	
	Matrix transform;
	Geometry geometry;
	Material[] materialOverrides;
	
	private ubyte lightsLength;
	private LightNode[8] lights;
	
	LightNode[] getLights()
	{	return lights[0..lightsLength];		 	              
	}
	
	void setLights(LightNode[] lights)
	{	lightsLength = lights.length;
		this.lights[0..lightsLength] = lights[0..$];
		foreach (light; lights[0..lightsLength])
			assert(light);
	}
}



/**
 * VisibleNode is the parent of all Nodes that are visible and can be rendered.
 * See_Also:
 * yage.scene.MovableNode
 * yage.scene.Node */
class VisibleNode : MovableNode
{	
	protected bool visible = true;
	protected Vec3f	size = Vec3f(1);
	
	protected ArrayBuilder!(LightNode) lights;	// Lights that affect this VisibleNode

	Material[] materialOverrides;	/// Use thes materials instead of the model's meshes' or sprite's materials.

	/**
	 * Make a duplicate of this node, unattached to any parent Node.
	 * Params:
	 *     children = recursively clone children (and descendants) and add them as children to the new Node.
	 * Returns: The cloned Node. */
	override VisibleNode clone(bool children=false)
	{	auto result = cast(VisibleNode)super.clone(children);
		result.visible = visible;
		result.size = size;
		return result;
	}

	/**
	 * deprecated.  getRenderCommands(camera) makes this no longer needed.
	 * Get the radius of this VisibleNode's culling sphere.  Includes both size and scale.
	 * Classes that inherit VisibleNode must provide this function to specify their radius, or they will not be rendered. */ 
	float getRadius()
	{	return 0;
	}

	/**
	 * Get / set the scale of this VisibleNode in the x, y, and z directions.
	 * The default is (1, 1, 1).  Unlike position and rotation, scale is not inherited. */	
	void setSize(float x, float y, float z) 
	{	size.x = x;
		size.y = y;
		size.z = z;
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
	
	void getRenderCommands(CameraNode camera, LightNode[] lights, ref ArrayBuilder!(RenderCommand) result)
	{	
	}
	
	
	/*
	 * Find the lights that most affect the brightness of this Node.
	 * Params:
	 *     all_lights = array of lights to check.  No synchronization is performed 
	 *     so this array must remain unmodified for the duration of this function.
	 *     number = maximum number of lights to return.
	 *
	 * Also perhaps use axis sorting for faster calculations. */
	LightNode[] getLights(LightNode[] allLights, ubyte number=8)
	{	
		// Calculate the intensity of all lights on this node
		lights.length = number;
		lights.data[0..$] = null;
		Vec3f position;
		position.v[0..3] = (getAbsoluteTransform(true)).v[12..15];
		float radius = getRadius();
		
		foreach (light; allLights)
		{	
			// First pass, discard lights that are too far away.  
			float lr = light.getLightRadius(); // [below] distance is greater than 8*radius.  At 8*radius, we have 1/256th brightness.
			if (light.getAbsolutePosition().distance2(position) < 256 * lr*lr)
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
	}
}
