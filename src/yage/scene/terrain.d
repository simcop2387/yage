/**
 * Copyright:  (c) 2010 Brandon Lyons
 * Authors:    Brandon Lyons, Eric Poggel
 * License:    Boost 1.0
 */

module yage.scene.terrain;

import yage.core.math.vector;
import yage.resource.geometry;
import yage.resource.image;
import yage.resource.material;
import yage.resource.texture;
import yage.scene.camera;
import yage.scene.node;
import yage.scene.visible;


/**
 * This class isn't implemented yet. */
class TerrainNode : VisibleNode
{
	
	protected Geometry[][] mipmaps;

	/**
	 * Provide a class that sets the shape and textures of the terrain.
	 * Params:
	 *     generator = Instance of TerrainGenerator.
	 *     textures = Textures to use on the terrain.  The texture's transformation matrix can be scaled to allow
	 *         textures to repeat.  For example, a scale of (1/16, 1/16, 1) will repeat the texture 16 times
	 *         in the x and y directions.
	 *     min = The minimum x and y value of the range of coordinates passed to generator's getPoint() function.
	 *     max = The maximum x and y value of the range of coordinates passed to generator's getPoint() function. 
	 *     resolution = The number of points (grid resolution) in the x and y directions passed 
	 *         to generator's getPoint() function. */
	this(TerrainGenerator generator, Texture[] textures, Vec2f min=Vec2f(-128), Vec2f max=Vec2f(127), Vec2f resolution=Vec2f(256))
	{
		/// TODO
		// Mipmaps could be laid out something like this.
		mipmaps.length = 3; // I wonder how many levels we should generate?
		mipmaps[0].length = 1; // A single 64x64 block.  Is 64x64 an optimal block size?
		mipmaps[1].length = 4; // Four 64x64 blocks, etc.
		mipmaps[2].length = 16;
	}
	
	/**
	 * The terrain geometry is divided into blocks, each at multiple levels of detail.
	 * This function is used by the renderer to get a set of Geometry visible by the specified camera.
	 * Params:
	 *     camera = Only blocks inside the Camera's view frustum will be returned.         
	 *     pixelsPerPolygon = Blocks closer to the camera will provide higher resolution Geometry.
	 *         Every block returned will have its polygons smaller than pixelsPerPolygon.
	 *         Smaller values for pixelsPerPolygon will yield blocks with more polygons and a better rendering.
	 */
	Geometry[] getVisibleGeometry(CameraNode camera, float pixelsPerPolygon=32)
	{
		/// TODO
		// This Geometry can be passed directly to the render system.
		// We should probably generate geometry lazily--this will allow for ginormous terrains too big to fit in memory.
		// And also free mipmaps that haven't been used in a while--a complete paging system.
		
		return null;
	}
}

/**
 * Defines functions a class must provide in order for TerrainNode to use it to generate Terrain. */
interface TerrainGenerator
{
	/// Data structure for a single vertex in the Terrain Geometry.
	struct TerrainPoint
	{	Vec3f position;				/// xyz position of the terrain point
		Vec3f normal;				/// Normal vector for this point on the terrain, used for lighting
		Vec2f textureCoordinate;	/// Texture coordinates for this point on the terrain
		float[] textureBlend;		/// Normalized vector of arbitrary length specifying the amount of each texture to
									/// use at this point.  TerrainNode.setTextures() specifies the textures themselves.
	}
	
	/**
	 * Get the values needed for a single vertex in the Terrain Geometry. */
	TerrainPoint getPoint(Vec2f coordinate);	
	
	/**
	 * Get a lightmap Texture to use across the range of coordinates.
	 * If no lightmap is desired, this function can return a Texture without a GPUTexture.
	 * The same GPU Texture can be reused across multiple calls with different values, 
	 * if the Textures' texture matrix adjusted as needed.
	 * Params:
	 *     min = Minumum xy coordinate of the rectangle needing a lightmap.
	 *     max = Maximum xy coordinate of the rectangle needing a lightmap.
	 * Returns: An RGB texture to use as a baked light-map.  It's color values will be modulated with the terrain. */
	Texture getLightmap(Vec2f min, Vec2f max);	
}

/**
 * A sample TerrainGenerator that uses a heightmap image to specify elevation and a color texture
 * to specify which textures to use at a given point. */
class HeightmapGenerator : TerrainGenerator
{
	Image2!(ubyte, 1) heightMap;
	Image2!(ubyte, 4)[] textures;
	
	/**
	 * 
	 * Params:
	 *     heightMap = 
	 *     textures = The red component of the first textureBlend specifies how much of the first texture to use at this 
	 *         point, The green for the second texture, blue for the third, and alpha for the fourth.
	 *         If more than four textures are used, the red component of the second textureBlend is used for the fifth,
	 *         and so on. */
	this(Image2!(ubyte, 1) heightMap, Image2!(ubyte, 4)[] textureBlend)
	{	this.heightMap = heightMap;
		this.textures = textures;
	}
	
	/**
	 * Load heightmap and textureBlends from Earth Sculptor, available at http://earthsculptor.com	 */
	this(char[] filename)
	{
	}
		
	TerrainPoint getPoint(Vec2f coordinate)
	{	TerrainPoint result;
	
		result.position.x = coordinate.x;
		result.position.y = coordinate.y;  /// TODO: [below] It would be better to interpolate values.
		result.position.z = 0; // heightMap[coordinate.x*heightMap.width, coordinate.y*heightMap.height];
		
		// TODO texture coordinates, normals, and textureBlend
		
		return result;
	}

	Texture getLightmap(Vec2f min, Vec2f max)
	{	Texture texture;
		return texture; // return no lightmap for now.
	}
}


/+
// Old version, no longer compiles since Yage's Geometry format has changed.:
// Also see yage.scene.graph.

/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel, Joe Pusderis (deformative0@gmail.com)
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

import yage.resource.manager;
import yage.resource.material;
import yage.resource.model;
import yage.resource.mesh;

import yage.core.math.matrix;
import yage.system.system;
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

	/**
	 * Constructor */
	this()
	{	super();
		model = new Model();
		model.setMeshes([new Mesh()]);		
	}

	/*
	 * Construct this TerrainNode as a copy of another TerrainNode and recursively copy all children.
	 * Params:
	 * parent = This TerrainNode will be a child of parent.
	 * original = This TerrainNode will be an exact copy of original.
	this (Node parent, TerrainNode original)
	{	super(parent, original);

		model = new Model(original.model);
		radius = original.radius;
		width = original.width;
	}*/

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
	 * Set the Material used by this TerrainNode, using the ResourceManager Manager
	 * to ensure that no Material is loaded twice.
	 * Equivalent of setMaterial(ResourceManager.material(filename)); */
	void setMaterial(Material material)
	{	model.getMeshes()[0].setMaterial(material);
	}

	/// Set the Material of the GraphNode.
	void setMaterial(char[] material_file)
	{	setMaterial(ResourceManager.material(material_file));
	}

	
	/// Overridden to cache the radius if changed by the scale.
	void scale(Vec3f scale)
	{	this.scale = scale;
		if (width != 0) // if heightmap loaded
			radius = model.getRadius()*scale.max();
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
		
		radius = model.getRadius()*size.max();
	}
}
+/