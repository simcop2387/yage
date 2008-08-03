/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel & Joe (Deformative) Pusdesris
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.scene.terrain;

import std.conv;
import std.file;
import std.stdio;
import std.string;
import std.stream;

import yage.resource.resource;
import yage.resource.material;
import yage.resource.model;
import yage.resource.mesh;
import yage.resource.image;
import yage.scene.node;
import yage.scene.visible;
import yage.core.matrix;
import yage.core.vector;
import yage.system.constant;
import yage.system.device;
import yage.system.log;


/**
 * A TerrainNode generates a landscape for rendering from a heightmap image.
 * This class may change in the future as featurs are added.
 * Example:
 * --------------------------------
 * TerrainNode a = new TerrainNode(scene);  // Child of scene
 * a.setSize(1000, 100, 1000);             // Make it a decent size
 * a.setMaterial("terrain/islands.xml");
 * a.setHeightMap("terrain/islands-height.png");
 * --------------------------------
 */
class TerrainNode : VisibleNode
{
	protected Model model;
	protected float radius;
	protected int width=0;

	/// Construct as a child of parent
	this(Node parent)
	{	super(parent);
		model = new Model();
		model.setMeshes([new Mesh()]);
		visible = true;
	}


	/**
	 * Construct this TerrainNode as a copy of another TerrainNode and recursively copy all children.
	 * Params:
	 * parent = This TerrainNode will be a child of parent.
	 * original = This TerrainNode will be an exact copy of original.*/
	this (Node parent, TerrainNode original)
	{	super(parent, original);

		model = new Model(original.model);
		radius = original.radius;
		width = original.width;
	}

	///
	Material getMaterial()
	{	return model.getMeshes()[0].getMaterial();
	}

	/// Get the model generated from setHeightMap().
	Model getModel()
	{	return model;
	}

	/// Get the radius of this Node's culling sphere.
	float getRadius()
	{	return radius;
	}

	/**
	 * Generate the 3D landscape rendered for this Node, from a heighmap image.
	 * The terrain generated always fits inside a 1x1x1 cube.
	 * Use setSize() to adjust to a comfortable size.
	 * Params:
	 * grayscale = An image to load.  It will be converted to a grayscale image
	 * if necessary.  Whiter regions will be higher altitudes.
	 * repeat = The material texture coordinates will be repeated this many times. */
	void setHeightMap(Image grayscale, float repeat=1)
	{	// just to be sure
		grayscale.setFormat(1);

		// Allocate vertex data
		int w = grayscale.getWidth();
		int h = grayscale.getHeight();
		int size = w*h;
		Vec3f[] vertices = new Vec3f[size];
		Vec3f[] normals  = new Vec3f[size];
		Vec2f[] texcoords= new Vec2f[size];
		Vec3i[] triangles= new Vec3i[size*2];

		// Generate from heightmap
		int i=0;
		for (int z=0; z<h; z++)	// loop through image rows
			for (int x=0; x<w; x++) // through columns
			{
				// Vertices and tex coords
				vertices[z*w+x].set(cast(float)x/(w-1)-.5, (grayscale[z*w+x])[0]/256.0-.5, cast(float)z/(h-1)-.5);
				texcoords[z*w+x].set(cast(float)x/(w-1)*repeat, cast(float)z/(h-1)*repeat);

				// Triangles
				if (x+1<w && z+1<h)
				{	triangles[i  ].set((z+1)*w+x, z*w+x+1, z*w+x);
					triangles[i+1].set((z+1)*w+x, (z+1)*w+x+1, z*w+x+1);
				}
				i+=2;
			}

		//model.setVertices(vertices, normals, texcoords);
		model.setAttribute("gl_Vertex", vertices);
		model.setAttribute("gl_TexCoord", texcoords);
		model.setAttribute("gl_Normal", normals);
		model.getMeshes[0].setTriangles(triangles);

		// Normals and upload
		width = w;
		regenerate();
	}

	/// ditto
	void setHeightMap(char[] image_file, float repeat=1.0)
	{	setHeightMap(new Image(image_file), repeat);
	}

	/**
	 * Set the Material used by this TerrainNode, using the Resource Manager
	 * to ensure that no Material is loaded twice.
	 * Equivalent of setMaterial(Resource.material(filename)); */
	void setMaterial(Material material)
	{	model.getMeshes()[0].setMaterial(material);
	}

	/// Set the Material of the GraphNode.
	void setMaterial(char[] material_file)
	{	setMaterial(Resource.material(material_file));
	}

	
	/// Overridden to cache the radius if changed by the scale.
	void scale(Vec3f scale)
	{	this.scale = scale;
		if (width != 0) // if heightmap loaded
			radius = model.getDimensions().scale(scale).length();
	}
	
	Vec3f scale()
	{	return super.size;		
	}
	
	

	/*
	 * Recalculate the terrain's normals and culling sphere radius.*/
	protected void regenerate()
	{
		Vec3f[] vertices = model.getAttribute("gl_Vertex").vec3f;
		Vec3f[] normals = model.getAttribute("gl_Normal").vec3f;

		int height = vertices.length/width;
		for (int x=0; x<width; x++)
			for (int z=0; z<height; z++)
			{	float dx=0, dz=0;

				// dx (slope in the x direction)
				if (0<x && x<width-1)
					dx = vertices[z*width+x+1].y - vertices[z*width+x-1].y;
				else if (0<x)
					dx = vertices[z*width+x].y - vertices[z*width+x-1].y;
				else
					dx = vertices[z*width+x+1].y - vertices[z*width+x].y;

				// dz (slope in the z direction)
				if (0<z && z<height-1)
					dz = vertices[(z+1)*width+x].y - vertices[(z-1)*width+x].y;
				else if (0<z)
					dz = vertices[z*width+x].y - vertices[(z-1)*width+x].y;
				else
					dz = vertices[(z+1)*width+x].y - vertices[z*width+x].y;

				// Cross product for the win!
				//  Actually, I'm not too sure about this
				Vec3f tx = Vec3f(1.0/width, dx, 0);
				Vec3f tz = Vec3f(0, dz, 1.0/height);
				normals[z*width+x] = -(tx.cross(tz)).normalize();
			}
		//model.setAttribute("gl_Vertex", vertices);
		model.setAttribute("gl_Normal", normals);
		
		radius = model.getDimensions().scale(scale).length();
	}
}
