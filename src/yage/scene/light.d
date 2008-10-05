/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.light;

import std.math;
import std.stdio;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.all;
import yage.resource.material;
import yage.scene.node;
import yage.scene.movable;
import yage.scene.scene;
import yage.system.constant;
import yage.system.probe;
import yage.system.render;
import yage.scene.camera: CameraNode;

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
	protected float	quad_attenuation	= 1.52e-5;	// (1/256)^2, radius of 256, arbitrary
 	protected int type 			= LIGHT_POINT;

	protected Color	ambient;			// The RGBA ambient color of the light, defaults to black.
	protected Color	diffuse;			// The RGBA diffuse color of the light, defaults to 100% white.
	protected Color	specular;			// The RGBA specular color of the light, defaults to 100% white.
	protected float	spot_angle = 45.0;	// If the light type is SPOT, this sets the angle of the cone of light emitted.
	protected float	spot_exponent = 0;	// If the light type is SPOT, this sets the fadeoff of the light.

	package float intensity;			// Used internally and temporarily to sort lights by intensity for each node.

	this()
	{	diffuse = Color("white");
		specular= Color("white");		
	}
	
	/**
	 * Construct this Node as the child of parent.*/
	this(Node parent)
	{	super(parent);
		diffuse = Color("white");
		specular= Color("white");
	}

	/**
	 * Construct this Node as a copy of another Node and recursively copy all children.
	 * Params:
	 * parent = This Node will be a child of parent.
	 * original = This Node will be an exact copy of original.*/
	this (Node parent, LightNode original)
	{	super(parent, original);
		ambient = original.ambient;
		diffuse = original.diffuse;
		specular = original.specular;
		spot_angle = original.spot_angle;
		spot_exponent = original.spot_exponent;
		quad_attenuation = original.quad_attenuation;
		type = original.type;
	}

	/// Get / set the ambient color of the light.
	Color getAmbient()
	{	return ambient;
	}
	void setAmbient(Color ambient) /// Ditto
	{	this.ambient = ambient;
	}

	/// Get /set the diffuse color of the light.
	Color getDiffuse()
	{	return diffuse;
	}
	void setDiffuse(Color diffuse) /// Ditto
	{	this.diffuse = diffuse;
	}


	/// Get / set the specular color of the light.
	Color getSpecular()
	{	return specular;
	}
	void setSpecular(Color specular) /// Ditto
	{	this.specular = specular;
	}


	/**
	 * Get/ set the spotlight angle of the light, in radians.  If the light type is a
	 * spotlight, this is the angle of the light cone. */
	float getSpotAngle()
	{	return spot_angle*PI/180;
	}
	void setSpotAngle(float radians) /// Ditto
	{	spot_angle = radians*_180_PI;
	}

	/**
	 * Set the spotlight exponent of the light.  If the light type is a
	 * spotlight, this is how focussed the light is.  Higher exponents are more focussed.*/
	float getSpotExponent()
	{	return spot_exponent;
	}
	void setSpotExponent(float exponent) /// Ditto
	{	spot_exponent = exponent;
	}


	/** Get / set the type of the light.
	 *  0 for directional, 1 for point, or 2 for spot. */
	ubyte getLightType()
	{	return type;
	}
	void setLightType(int type) /// Ditto
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
	 * of that radius, instead of the default of a single point.  
	 * This is used internally for nodes that have a spotlight shine on one corner of them 
	 * but not at all at their center.
	 * Returns: Color.*/
	Color getBrightness(Vec3f point, float margin=0.0)
	{
		// Directional lights are easy, since they don't depend on which way the light points
		// or how far away the light is.
		if (type==LIGHT_DIRECTIONAL)
			return Color(ambient.r+diffuse.r, ambient.g+diffuse.g, ambient.b+diffuse.b);

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
		color.set(diffuse.r/255.0f*intensity, diffuse.g/255.0f*intensity, diffuse.b/255.0f*intensity);
		if (add_ambient)
			color.add(ambient.vec3f);	// diffuse scaled by intensity plus ambient.

		if (color.x>=1) color.x=1;
		if (color.y>=1) color.y=1;
		if (color.z>=1) color.z=1;

		return Color(color);
	}

	/*
	 * Enable this light as the given light number and apply its properties.
	 * This function is used internally by the engine and should not be called manually or exported. */
	void apply(int num)
	in{	assert (num<=Probe.openGL(Probe.OpenGL.MAX_LIGHTS));
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
		glLightfv(GL_LIGHT0+num, GL_AMBIENT, ambient.vec4f.ptr);
		glLightfv(GL_LIGHT0+num, GL_DIFFUSE, diffuse.vec4f.ptr);
		glLightfv(GL_LIGHT0+num, GL_SPECULAR, specular.vec4f.ptr);

		// Attenuation properties
		glLightf(GL_LIGHT0+num, GL_CONSTANT_ATTENUATION, 0); // requires a 1 but should be zero?
		glLightf(GL_LIGHT0+num, GL_LINEAR_ATTENUATION, 0);
		glLightf(GL_LIGHT0+num, GL_QUADRATIC_ATTENUATION, quad_attenuation);

		glPopMatrix();
	}

	/// Overridden to remove the light from the Scene's arary of lights
	override void remove()
	{	if (scene)
			scene.removeLight(this);
		super.remove();
	}

}
