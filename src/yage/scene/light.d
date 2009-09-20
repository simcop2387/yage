/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.light;

import tango.math.Math;

import yage.core.all;
import yage.resource.material;
import yage.scene.node;
import yage.scene.movable;
import yage.scene.scene;
import yage.system.graphics.probe;
import yage.system.graphics.probe;
import yage.scene.camera;

/**
 * LightNodes are Nodes that emit light.
 * Opengl hardware lights are used by default, but shaders can be used to go
 * beyond their capabilities.  Each material has an optional max-lights property
 * and this is used to only enable the lights that most affect the polygons
 * when rendering that instance of the material.
 *
 * All color values are floating point in the range from 0 to 1 and in the order
 * of red, green, blue and alpha.  For example,
 * (1, .5, 0, 0) is orange, since it is 100% red and 50% green.*/
class LightNode : MovableNode
{
	/// Values that can be assigned to type.
	enum Type
	{	DIRECTIONAL,	/// A light that shines in one direction through the entire scene
		POINT,			/// A light that shines outward in all directions
		SPOT			/// A light that emits light outward from a point in a single direction
	}
		
 	public Type type = Type.POINT; /// The type of light (directional, point, or spot)

	public Color ambient = {r:0,   g:0,   b:0,   a:255}; /// Ambient color of the light.  Defaults to black
	public Color diffuse = {r:255, g:255, b:255, a:255}; /// Diffuse color of the light.  Defaults to 100% white.
	public Color specular= {r:255, g:255, b:255, a:255}; /// Specular color of the light, defaults to 100% white.
	
	/**
	 * Spotlight angle of the light, in radians.  
	 * If the light type is a spotlight, this is the angle of the light cone. */
	public float spotAngle = 45.0;	/// 
	
	/**
	 * Spotlight exponent of the light.  
	 * If the light type is a spotlight, this is how focussed the light is.  
	 * Larger values produce more focussed spotlights. */
	public float spotExponent = 0;	/// 

	package float intensity; // Used internally as a temp variable to sort lights by intensity for each node.
	protected float	quadAttenuation = 1.52e-5;	// (1/256)^2, radius of 256, arbitrary
	
	/**
	 * Make a duplicate of this node, unattached to any parent Node.
	 * Params:
	 *     children = recursively clone children (and descendants) and add them as children to the new Node.
	 * Returns: The cloned Node. */
	override LightNode clone(bool children=false)
	{	auto result = cast(LightNode)super.clone(children);
		
		// All of these assignments are atomic.
		result.quadAttenuation = quadAttenuation;
		result.type = type;
		result.ambient = ambient;
		result.diffuse = diffuse;
		result.specular = specular;
		result.spotAngle = spotAngle;
		result.spotExponent = spotExponent;
		
		return result;
	}

	
	/** Get / set the radius of the light.  Default value is 256.
	 *  Quadratic attenuation is used, so the brightness of an object is Radius^2/distance^2,
	 *  Using this formula, a brightness of 1.0 or higher is 100% bright.*/
	float getLightRadius()
	{	return tango.math.Math.sqrt(1/quadAttenuation);
	}
	void setLightRadius(float radius) /// ditto
	{	quadAttenuation = 1.0/(radius*radius);
	}

	///
	float getQuadraticAttenuation()
	{	return quadAttenuation;
	}

	/**
	 * Return the RGB brightness this light contributes to a given point in 3D space, relative to this light's scene.
	 * OpenGl's fixed-function, traditional lighting calculations are used.
	 * The diffuse and ambient values of the light are taken into effect, 
	 * while the specular is not, since it depends on the viewing angle of the camera.
	 * Also note that this does not take into account shadows or anything of that nature.
	 * Params:
	 *     point = 3D coordinates of the point to be evaluated.
	 *     margin = For spotlights, setting a margin cause this function to return brightest point inside
	 *         of that radius, instead of the default of a single point.  
	 *         This is used internally for nodes that have a spotlight shine on one corner of them 
	 *         but not at all at their center.*/
	Color getBrightness(Vec3f point, float margin=0.0)
	{
		// Directional lights are easy, since they don't depend on which way the light points
		// or how far away the light is.
		if (type==Type.DIRECTIONAL)
			return Color(ambient.r+diffuse.r, ambient.g+diffuse.g, ambient.b+diffuse.b);

		// light_direction is vector from light to point
		Vec3f light_direction = point - Vec3f(getAbsoluteTransform().v[12..15]);
		// distance squared to light
		float d2 = light_direction.x*light_direction.x + light_direction.y*light_direction.y + light_direction.z*light_direction.z;
		float intensity = 1/(quadAttenuation*d2);	// quadratic attenuation.

		bool add_ambient = true;	// Only if this node is in the spotlight
		if (type==Type.SPOT)
		{
			float d = sqrt(d2);	// distance
			if (d==0) d=1;
			// dot product of vector from spotlight pointing to node and node pointing to spotlight.
			float spotDot = Vec3f(transform_abs.v[8..11]).normalize().dot(light_direction/d); // point/d is normalized point

			// Extra spotlight angle (in radians) to satisfy margin distance
			float m2 = margin>0 ? atan2(margin, d) : 0;

			if (spotDot > cos(spotAngle*0.017453292 + m2)) // 0.017453292 = pi/180
				intensity *= pow(spotDot, spotExponent);
			else
			{	intensity = 0;	// if the spotlight isn't shining on this point.
				add_ambient = false;
		}	}

		// color will store the RGB color values of the intensity.
		Vec3f color;
		color.set(diffuse.r/255.0f*intensity, diffuse.g/255.0f*intensity, diffuse.b/255.0f*intensity);
		if (add_ambient)
			color.add(ambient.vec3f);	// diffuse scaled by intensity plus ambient.

		if (color.x>=1) color.x=1;
		if (color.y>=1) color.y=1;
		if (color.z>=1) color.z=1;

		return Color(color);
	}

	/*
	 * This should be protected, but making it anything but public causes it not to be called.
	 * Most likely a D bug. */
	override public void ancestorChange(Node old_ancestor)
	{	super.ancestorChange(old_ancestor); // must be called first so scene is set.
		
		Scene old_scene = old_ancestor ? old_ancestor.scene : null;	
		if (old_scene)
			old_ancestor.scene.removeLight(this);
		if (scene && scene != old_scene)
			scene.addLight(this);
	}
}
