/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.node.graph;

import std.stdio;
import std.math;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.vector;
import yage.core.misc;
import yage.resource.resource;
import yage.resource.material;
import yage.resource.model;
import yage.node.basenode;
import yage.node.node;
import yage.node.scene;
import yage.node.basenode;

/**
 * A GraphNode can be set to an arboolrary parametric equation of two variables
 * and rendered as a triangle mesh (a 3D graph), complete with a material and lighting.
 * Example:
 * --------------------------------
 * GraphNode p1 = new GraphNode(scene);
 * p1.setWindow(-2, 2, -2, 2, step, step);
 * p1.setFunction((float s, float t){ return Vec3f(s, 1-(s*s+t*t), t); });
 * p1.setTextureFunction((float s, float t){ return Vec2f(s/4-.5, t/4-.5); } );
 * p1.setMaterial(Resource.material("blue.xml"));
 * p1.regenerate(); // required to generate the graph.
 * --------------------------------
 */
class GraphNode : Node
{
	protected float	smin, smax, tmin, tmax, step_s, step_t;
	protected bool  swrap, twrap;
	protected Vec3f delegate(float x, float y) func;
	protected Vec2f delegate(float r, float s) texfunc;
	protected Model model;
	protected float radius = 0;	// Store the distance of the furthest point

	/// Construct this Node as a child of parent.
	this(BaseNode parent)
	{	super(parent);
		setVisible(true);
		scale = Vec3f(1, 1, 1);
		setWindow(-10, 10, -10, 10);

		model = new Model();
		model.meshes.length =1;
		model.meshes[0] = new Mesh();
	}

	/**
	 * Construct this Node as a copy of another Node and recursively copy all children.
	 * Params:
	 * parent = This Node will be a child of parent.
	 * original = This Node will be an exact copy of original.*/
	this (BaseNode parent, GraphNode original)
	{	super(parent, original);

		model = new Model();
		model.meshes.length =1;
		model.meshes[0] = new Mesh();
		model.meshes[0].setMaterial(original.model.meshes[0].getMaterial());

		setWindow(original.smin, original.smax, original.tmin, original.tmax, original.step_s, original.step_t);
		setFunction(original.func);
		setTextureFunction(original.texfunc);
		setWrap(original.swrap, original.twrap);
		regenerate();
	}

	/// Get the distance to the furthest point, afer scaling.
	float getRadius()
	{	return radius*scale.max();
	}

	/// Set a parametric graph
	void setFunction(Vec3f delegate(float r, float s) func)
	{	this.func = func;
	}

	/// Set a function of two variables to generate texture coordinates.
	void setTextureFunction(Vec2f delegate(float r, float s) texfunc)
	{	this.texfunc = texfunc;
	}

	/// Set the Material of the GraphNode.
	void setMaterial(Material material)
	{	model.meshes[0].setMaterial(material);
	}

	/** Set the Material of the GraphNode, using the Resource Manager
	 *  to ensure that no Material is loaded twice.
	 *  Equivalent of setMaterial(Resource.material(filename)); */
	void setMaterial(char[] filename)
	{	model.meshes[0].setMaterial(Resource.material(filename));
	}

	/// Set the range of values for the GraphNode.
	void setWindow(float smin, float smax, float tmin, float tmax, float step_s=1, float step_t=1)
	{	this.smin = smin;
		this.tmin = tmin;
		this.smax = smax;
		this.tmax = tmax;
		this.step_s = step_s;
		this.step_t = step_t;
		regenerate();
	}

	/// Set whether the graph wraps around on itself in the s or t directions; useful for a cylinder, for example.
	void setWrap(bool swrap, bool twrap)
	{	this.swrap = swrap;
		this.twrap = twrap;
	}

	/**
	 * Regenerate the vertices of the GraphNode.  This is called automatically
	 * when changing many of the GraphNode's parameters.*/
	void regenerate()
	{	if (func is null)
			return;

		int ssize = cast(int)ceil((smax-smin)/step_s);
		int tsize = cast(int)ceil((tmax-tmin)/step_t);
		int vsize = ssize*tsize;
		model.vertices.length = vsize;
		model.normals.length = vsize;
		model.texcoords.length = vsize;
		model.meshes[0].triangles.length = vsize*2;

		// Aliases
		Vec3i[] triangles = model.meshes[0].triangles;

		// Reset the normals.
		for (int i=0; i<vsize; i++)
			model.normals[i].set(0);


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

				model.vertices[c] = func(rs, rt);
				float m = model.vertices[c].abs().max();
				if (m > radius)
					radius = m;

				// Texture coordinates
				if (texfunc !is null)
					model.texcoords[c] = texfunc(rs, rt);
				else
					model.texcoords[c] = Vec2f(rs, rt);

				// Triangles
				if ((twrap || t+1<tsize) && (swrap || s+1<ssize))
				{	triangles[i].a = (s*tsize+t) % vsize;
					triangles[i].b = (s*tsize+t+1) % vsize;
					triangles[i].c = ((s+1)*tsize+t) % vsize;
					triangles[i+1].a = (s*tsize+t+1) % vsize;
					triangles[i+1].b = ((s+1)*tsize+t+1) % vsize;
					triangles[i+1].c = ((s+1)*tsize+t) % vsize;
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
				{	Vec3f p1 = model.vertices[triangles[i+j].a];
					Vec3f p2 = model.vertices[triangles[i+j].b];
					Vec3f p3 = model.vertices[triangles[i+j].c];

					Vec3f n = ((p1-p2).cross(p1-p3)).normalize();	// plane normal
					model.normals[triangles[i+j].a] += n;
					model.normals[triangles[i+j].b] += n;
					model.normals[triangles[i+j].c] += n;
				}
				i+=2;
		}	}

		// Normalize all normals
		foreach (inout Vec3f n; model.normals)
			n = n.normalize();

		// Cache model in video memory
		model.upload();
	}

	/// Render the GraphNode.  This is called automatically by CameraNodes when needed.
	void render()
	{
		Vec3i[] triangles = model.meshes[0].triangles;
		Vec3f[] vertices = model.vertices;
		Vec3f[] normals = model.normals;
		Vec2f[] texcoords = model.texcoords;

		glScalef(scale.x, scale.y, scale.z);

		// Use the VBO Extension
		if (model.cached)
		{	glBindBufferARB(GL_ARRAY_BUFFER, model.getVerticesVBO());
			glVertexPointer(3, GL_FLOAT, 0, null);
			glBindBufferARB(GL_ARRAY_BUFFER, model.getTexCoordsVBO());
			glTexCoordPointer(2, GL_FLOAT, 0, null);
			glBindBufferARB(GL_ARRAY_BUFFER, model.getNormalsVBO());
			glNormalPointer(GL_FLOAT, 0, null);
			glBindBufferARB(GL_ARRAY_BUFFER, 0);
		}
		else// Don't cache the model in video memory
		{	glVertexPointer(3, GL_FLOAT, 0, model.getVertices().ptr);
			glTexCoordPointer(2, GL_FLOAT, 0, model.getTexCoords().ptr);
			glNormalPointer(GL_FLOAT, 0, model.getNormals().ptr);
		}

		void draw()
		{	if (model.cached)
			{	glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, model.meshes[0].getTrianglesVBO());
				glDrawElements(GL_TRIANGLES, model.meshes[0].getTriangles().length*3, GL_UNSIGNED_INT, null);
				glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, 0);
			}else
				glDrawElements(GL_TRIANGLES, model.meshes[0].getTriangles().length*3, GL_UNSIGNED_INT, model.meshes[0].getTriangles().ptr);
		}

		if (model.meshes[0].getMaterial() !is null)
		{	glEnable(GL_LIGHTING);
			enableLights();
			foreach (Layer l; model.meshes[0].getMaterial().getLayers().array())
			{	l.apply();
				draw();
				l.unApply();
			}
			glDisable(GL_LIGHTING);
		}
		else
			draw();
		glScalef(1/scale.x, 1/scale.y, 1/scale.z);
	}
}
