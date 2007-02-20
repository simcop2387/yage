/**
 * Copyright:  (c) 2006-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.light;

import std.math;
import std.stdio;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.vector;
import yage.core.misc;
import yage.resource.material;
import yage.node.base;
import yage.node.node;
import yage.node.scene;
import yage.system.device;
import yage.system.constant;
import yage.system.render;


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
class LightNode : Node
{
	protected float	quad_attenuation	= 1.52e-5;	// (1/256)^2, radius of 256.
 	protected int type 			= LIGHT_POINT;
	protected int light_index	= -1;

	protected Vec4f	ambient;			// The RGBA ambient color of the light, defaults to black.
	protected Vec4f	diffuse;			// The RGBA diffuse color of the light, defaults to 100% white.
	protected Vec4f	specular;			// The RGBA specular color of the light, defaults to 100% white.
	protected float	spot_angle = 45.0;	// If the light type is SPOT, this sets the angle of the cone of light emitted.
	protected float	spot_exponent = 0;	// If the light type is SPOT, this sets the fadeoff of the light.


	/**
	 * Construct this Node as the child of parent.*/
	this(BaseNode parent)
	{	super(parent); // calls setParent, which adds it to the Scene's light list.
		diffuse = Vec4f(1, 1, 1, 1);
		specular= Vec4f(1, 1, 1, 1);
	}

	/**
	 * Construct this Node as a copy of another Node and recursively copy all children.
	 * Params:
	 * parent = This Node will be a child of parent.
	 * original = This Node will be an exact copy of original.*/
	this (BaseNode parent, LightNode original)
	{	super(parent, original);
		ambient = original.ambient;
		diffuse = original.diffuse;
		specular = original.specular;
		spot_angle = original.spot_angle;
		spot_exponent = original.spot_exponent;
		quad_attenuation = original.quad_attenuation;
		type = original.type;
	}

	/**
	 * Overridden from Node's setParent() to ensure that the Scene's list of lights
	 * is updated if the Light is moved from one scene to another. */
	Node setParent(BaseNode parent)
	{	Scene old = scene;
		super.setParent(parent);
		if (old !is scene)
		{	if ((old !is null) && (index != -1))
				old.removeLight(light_index);
			scene.addLight(this);
		}
		return this;
	}

	/// Overridden to remove the light from the Scene's arary of lights
	void remove()
	{	debug scope( failure ) writef("Backtrace xx "__FILE__"(",__LINE__,")\n");
		scene.removeLight(light_index);
		super.remove();
	}

	/// Get the ambient color of the light.
	Vec4f getAmbient()
	{	return ambient;
	}
	/// Set the ambient color of the light.
	void setAmbient(float r, float g, float b)
	{	ambient.set(r, g, b, 0);
	}
	/// Set the ambient color of the light.
	void setAmbient(Vec4f ambient)
	{	this.ambient = ambient;
	}


	/// Get the diffuse color of the light.
	Vec4f getDiffuse()
	{	return diffuse;
	}
	/// Set the diffuse color of the light.
	void setDiffuse(float r, float g, float b)
	{	diffuse.set(r, g, b, 0);
	}
	/// Set the diffuse color of the light.
	void setDiffuse(Vec4f diffuse)
	{	this.diffuse = diffuse;
	}


	/// Get the specular color of the light.
	Vec4f getSpecular()
	{	return specular;
	}
	/// Set the specular color of the light.
	void setSpecular(float r, float g, float b)
	{	specular.set(r, g, b, 0);
	}
	/// Set the specular color of the light.
	void setSpecular(Vec4f specular)
	{	this.specular = specular;
	}


	/// Get the spotlight angle of the light, in radians.
	float getSpotAngle()
	{	return spot_angle*PI/180;
	}
	/**
	 * Set the spotlight angle of the light, in radians.  If the light type is a
	 * spotlight, this is the angle of the light cone. */
	void setSpotAngle(float radians)
	{	spot_angle = radians*_180_PI;
	}


	/// Get the spotlight exponent of the light.
	float getSpotExponent()
	{	return spot_exponent;
	}
	/**
	 * Set the spotlight exponent of the light.  If the light type is a
	 * spotlight, this is how focussed the light is.  Higher exponents are
	 * more focussed.*/
	void setSpotExponent(float exponent)
	{	spot_exponent = exponent;
	}


	/** Get the type of the light.
	 *  0 for directional, 1 for point, or 2 for spot. */
	ubyte getLightType()
	{	return type;
	}
	/** Set the type of the light.
	 *  0 for directional, 1 for point, or 2 for spot. */
	void setLightType(int type)
	{	this.type = type;
	}


	/// Get the radius of the light.  This is not the same as the Node's radius, see below.
	float getLightRadius()
	{	return std.math.sqrt(1/quad_attenuation);
	}
	/** Set the radius of the light.  Default value is 256.
	 *  Quadratic attenuation is used, so the brightness of an object is Radius^2/distance^2,
	 *  Using this formula, a brightness of 1.0 or higher is 100% bright.*/
	void setLightRadius(float radius)
	{	quad_attenuation = 1.0/(radius*radius);
	}

	///
	float getQuadraticAttenuation()
	{	return quad_attenuation;
	}


	/**
	 * Return the RGB brightness of the given point, as influenced only by this light, using
	 * OpenGl's fixed-function, traditional lighting calculations.  The diffuse and ambient values
	 * of the light are taken into effect, while the specular is not, since it depends on the
	 * viewing angle of the camera.
	 * Also note that this does not take into account shadows or anything of that nature.
	 * Params:
	 * point = 3D coordinates of the point to be evaluated.
	 * margin = For spotlights, setting a margin cause this function to return brightest point inside
	 * of that radius.  This is used internally for nodes that have a spotlight shine on
	 * one corner of them but not at all at their center.
	 * Returns: RGB color value in a Vec3f of floats from 0 to 1.*/
	Vec3f getBrightness(Vec3f point, float margin=0.0)
	{
		// Directional lights are easy, since they don't depend on which way the light points
		// or how far away the light is.
		if (type==LIGHT_DIRECTIONAL)
			return Vec3f(ambient.a+diffuse.a, ambient.b+diffuse.b, ambient.c+diffuse.c);

		// light_direction is vector from light to point
		Vec3f light_direction = point - Vec3f(getAbsoluteTransform().v[12..15]);
		// distance squared to light
		float d2 = light_direction.x*light_direction.x + light_direction.y*light_direction.y + light_direction.z*light_direction.z;
		float intensity = 1/(quad_attenuation*d2);	// quadratic attenuation.

		bool add_ambient = true;	// Only if this node is in the spotlight
		if (type==LIGHT_SPOT)
		{
			float d = sqrt(d2);	// distance
			if (d==0) d=1;
			// dot product of vector from spotlight pointing to node and node pointing to spotlight.
			float spotDot = Vec3f(transform_abs.v[8..11]).normalize().dot(light_direction/d); // point/d is normalized point

			// Extra spotlight angle (in radians) to satisfy margin distance
			float m2 = margin>0 ? atan2(margin, d) : 0;

			if (spotDot > cos(spot_angle*0.017453292 + m2)) // 0.017453292 = pi/180
				intensity *= pow(spotDot, spot_exponent);
			else
			{	intensity = 0;	// if the spotlight isn't shining on this point.
				add_ambient = false;
		}	}

		// color will store the RGB color values of the intensity.
		Vec3f color;
		color.set(diffuse.a*intensity, diffuse.b*intensity, diffuse.c*intensity);
		if (add_ambient)
			color.add(Vec3f(ambient.v));	// diffuse scaled by intensity plus ambient.

		if (color.x>=1) color.x=1;
		if (color.y>=1) color.y=1;
		if (color.z>=1) color.z=1;

		return color;
	}

	/*
	 * Enable this light as the given light number and apply its properties.
	 * This function is used internally by the engine and should not be called manually or exported. */
	void apply(int num)
	in{	assert (num<=Device.getLimit(DEVICE_MAX_LIGHTS));
	}body
	{
		glPushMatrix();
		glLoadMatrixf(Render.getCurrentCamera().getInverseAbsoluteMatrix().v.ptr); // required for spotlights.

		// Set position and direction
		glEnable(GL_LIGHT0+num);
		getAbsoluteTransform();
		Vec4f pos;
		pos.v[0..3] = transform_abs.v[12..15];
		pos.v[3] = type==LIGHT_DIRECTIONAL ? 0 : 1;
		glLightfv(GL_LIGHT0+num, GL_POSITION, pos.v.ptr);

		// Spotlight settings
		float angle = type == LIGHT_SPOT ? spot_angle : 180;
		glLightf(GL_LIGHT0+num, GL_SPOT_CUTOFF, angle);
		if (type==LIGHT_SPOT)
		{	glLightf(GL_LIGHT0+num, GL_SPOT_EXPONENT, spot_exponent);
			// transform_abs.v[8..11] is the opengl default spotlight direction (0, 0, 1),
			// rotated by the node's rotation.  This is opposite the default direction of cameras
			glLightfv(GL_LIGHT0+num, GL_SPOT_DIRECTION, transform_abs.v[8..11].ptr);
		}

		// Light material properties
		glLightfv(GL_LIGHT0+num, GL_AMBIENT, ambient.v.ptr);
		glLightfv(GL_LIGHT0+num, GL_DIFFUSE, diffuse.v.ptr);
		glLightfv(GL_LIGHT0+num, GL_SPECULAR, specular.v.ptr);

		// Attenuation properties
		glLightf(GL_LIGHT0+num, GL_CONSTANT_ATTENUATION, 0); // requires a 1 but should be zero?
		glLightf(GL_LIGHT0+num, GL_LINEAR_ATTENUATION, 0);
		glLightf(GL_LIGHT0+num, GL_QUADRATIC_ATTENUATION, quad_attenuation);

		glPopMatrix();
	}

	/*
	 * Set the index of this light in its Scene's lights array.
	 * This function is used internally by the engine and should not be called manually or exported. */
	void setLightIndex(int index)
	{	light_index = index;
	}
}
