/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.scene.graph;
/+
This module needs to be brought up to date with the rest of the Yage API before it
will work.

import tango.math.Math;
import yage.core.math.vector;
import yage.core.misc;
import yage.resource.manager;
import yage.resource.material;
import yage.resource.mesh;
import yage.resource.model;
import yage.scene.node;
import yage.scene.visible;
import yage.scene.scene;

/**
 * A GraphNode can be set to an arboolrary parametric equation of two variables
 * and rendered as a triangle mesh (a 3D graph), complete with a material and
 * normals for lighting.
 * Example:
 * --------------------------------
 * GraphNode plot = new GraphNode(scene);
 * plot.setWindow(-2, 2, -2, 2, .1, .1);
 * plot.setFunction((float s, float t){ return Vec3f(s, 1-(s*s+t*t), t); });
 * plot.setTextureFunction((float s, float t){ return Vec2f(s/4-.5, t/4-.5); } );
 * plot.setMaterial(ResourceManager.material("blue.xml"));
 * plot.regenerate(); // required to generate the graph.
 * --------------------------------
 */
class GraphNode : VisibleNode
{
	protected float	smin, smax, tmin, tmax, step_s, step_t;
	protected bool  swrap, twrap;
	protected Vec3f delegate(float x, float y) func;
	protected Vec2f delegate(float r, float s) texfunc;
	protected Model model;
	protected float radius = 0;	// Store the distance of the furthest point

	/**
	 * Constructor */
	this()
	{	super();
		setWindow(-1, 1, -1, 1);
		model = new Model();
		model.setMeshes([new Mesh()]);	
	}
	
	/*
	 * Construct this GraphNode as a copy of another GraphNode and recursively copy all children.
	 * Params:
	 * parent = This GraphNode will be a child of parent.
	 * original = This GraphNode will be an exact copy of original.
	this (Node parent, GraphNode original)
	{	super(parent, original);

		model = new Model();
		model.setMeshes([new Mesh()]);
		model.getMeshes()[0].setMaterial(original.model.getMeshes()[0].getMaterial());

		setWindow(original.smin, original.smax, original.tmin, original.tmax, original.step_s, original.step_t);
		setFunction(original.func);
		setTextureFunction(original.texfunc);
		setWrap(original.swrap, original.twrap);
		regenerate();
	}*/

	/// Return the Model generated from setFunction() and setMaterial().
	Model getModel()
	{	return model;
	}

	/// Return the distance to the furthest point, afer scaling.
	float getRadius()
	{	return radius;
	}

	/// Set a parametric graph
	void setFunction(Vec3f delegate(float r, float s) func)
	{	this.func = func;
	}

	/// Set the Material of the GraphNode.
	void setMaterial(Material material)
	{	model.getMeshes()[0].setMaterial(material);
	}

	/**
	 * Set the Material of the GraphNode, using the ResourceManager Manager
	 * to ensure that no Material is loaded twice.
	 * Equivalent of setMaterial(ResourceManager.material(filename)); */
	void setMaterial(string material_file)
	{	model.getMeshes()[0].setMaterial(ResourceManager.material(material_file));
	}


	/// Overridden to cache the radius if changed by the scale.
	void setSize(Vec3f size)
	{	this.size = size;
		radius = model.getRadius() * size.max();
	}	
	Vec3f getSize() /// Ditto
	{	return super.size;		
	}

	/// Set a function of two variables to generate texture coordinates.
	void setTextureFunction(Vec2f delegate(float r, float s) texfunc)
	{	this.texfunc = texfunc;
	}

	/// Set the range of values for the GraphNode.
	void setWindow(float smin, float smax, float tmin, float tmax, float step_s=.5, float step_t=.5)
	{	this.smin = smin;
		this.tmin = tmin;
		this.smax = smax;
		this.tmax = tmax;
		this.step_s = step_s;
		this.step_t = step_t;
		regenerate();
	}

	/// Set whether the graph wraps around on itself in the s or t parametric coordinates; 
	/// useful for a cylinder, for example.
	void setWrap(bool swrap, bool twrap)
	{	this.swrap = swrap;
		this.twrap = twrap;
	}

	/**
	 * Regenerate the gl_Vertex, gl_Normal, and gl_TexCoord attributes of the GraphNode,
	 * as well as triangle mesh data.
	 * This effectively creates the vertex and mesh data necessary for rendering.
	 * This is called automatically when changing many of the GraphNode's parameters.*/
	void regenerate()
	{	if (func is null)
			return;

		int ssize = cast(int)ceil((smax-smin)/step_s);
		int tsize = cast(int)ceil((tmax-tmin)/step_t);
		int vsize = ssize*tsize;

		Vec3f[] vertices;
		Vec3f[] normals;
		Vec2f[] texcoords;
		
		if (model.hasAttribute("gl_Vertex")) vertices = model.getAttribute("gl_Vertex").vec3f;
		if (model.hasAttribute("gl_Normal")) normals = model.getAttribute("gl_Normal").vec3f;
		if (model.hasAttribute("gl_TexCoord")) texcoords = model.getAttribute("gl_TexCoord").vec2f;
		
		vertices.length = vsize;
		normals.length = vsize;
		texcoords.length = vsize;
		Vec3i[] triangles = model.getMeshes()[0].getTriangles();
		triangles.length = vsize*2;

		// Reset the normals.
		for (int i=0; i<vsize; i++)
			normals[i].set(0);

		// Create vertices
		int i=0;
		for (int s=0; s<ssize; s++)
		{	for (int t=0; t<tsize; t++)
			{	int c = s*tsize+t;

				// Vertices (and radius)
				float rs = smin + s*step_s;
				float rt = tmin + t*step_t;
				if (rs>smax-step_s) rs = smax;	// round the last vertices
				if (rt>tmax-step_t) rt = tmax;	// up to the graph max

				vertices[c] = func(rs, rt);

				// Texture coordinates
				if (texfunc !is null)
					texcoords[c] = texfunc(rs, rt);
				else
					texcoords[c] = Vec2f(rs, rt);

				// Triangles
				if ((twrap || t+1<tsize) && (swrap || s+1<ssize))
				{	triangles[i].x = (s*tsize+t) % vsize;
					triangles[i].y = (s*tsize+t+1) % vsize;
					triangles[i].z = ((s+1)*tsize+t) % vsize;
					triangles[i+1].x = (s*tsize+t+1) % vsize;
					triangles[i+1].y = ((s+1)*tsize+t+1) % vsize;
					triangles[i+1].z = ((s+1)*tsize+t) % vsize;
				}
				else // don't use these triangles
				{	triangles[i] = Vec3i(0, 0, 0);
					triangles[i+1] = Vec3i(0, 0, 0);
				}
				i+=2;
			}
		}

		// Calculate average normal vector per vertex
		i=0;
		for (int s=0; s<ssize; s++)
		{	for (int t=0; t<tsize; t++)
			{	int c = s*tsize+t;

				for (int j=0; j<2; j++)
				{	Vec3f p1 = vertices[triangles[i+j].x];
					Vec3f p2 = vertices[triangles[i+j].y];
					Vec3f p3 = vertices[triangles[i+j].z];

					Vec3f n = ((p1-p2).cross(p1-p3)).normalize();	// plane normal
					normals[triangles[i+j].x] += n;
					normals[triangles[i+j].y] += n;
					normals[triangles[i+j].z] += n;
				}
				i+=2;
		}	}

		// Normalize all normals
		foreach (inout Vec3f n; normals)
			n = n.normalize();
		
		model.setAttribute("gl_Vertex", vertices);
		model.setAttribute("gl_TexCoord", texcoords);
		model.setAttribute("gl_Normal", normals);
		model.getMeshes()[0].setTriangles(triangles);

		radius = model.getRadius()*size.max();

		// Cache model in video memory
		//model.upload();
	}
}
+/