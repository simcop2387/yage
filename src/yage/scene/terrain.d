/**
 * Copyright:  (c) 2010 Brandon Lyons
 * Authors:    Brandon Lyons, Eric Poggel
 * License:    Boost 1.0
 */
 
module yage.scene.terrain;

import yage.core.array;
import yage.core.math.vector;

import yage.resource.geometry;
import yage.resource.image;

import yage.scene.light;
import yage.scene.camera;
import yage.scene.node;
import yage.scene.visible;

import yage.resource.material;
import yage.resource.texture;
import yage.resource.manager;

import yage.system.log;


/*
 * THOUGHTS
 * naming: terrainNode, planetNode
 */


/*
 * Data structure for a single vertex in the Terrain Grid.
 */
struct TerrainPoint
{	float height;		/// z position of the terrain point
	Vec3f normal;		/// Normal vector for this point on the terrain, used for lighting
	Vec2f textureCoordinate;/// Texture coordinates for this point on the terrain
	float[] texturesBlend;	/// Normalized vector of arbitrary length specifying the amount of each texture to use at this point.
}

/**
 * Construct a terrain Geometry based on the data produced by a terrainGenerator.
 * FIXME: should be called mipmapTerrainNode
 * this class provides a terrain mesh to the renderer out of heights values:
 * - build a terrain geometry
 * - optimize the geometry according to both camera position and fulcrum
 * - texturing
 */
class TerrainNode : VisibleNode
{
	struct Patch {
		static const int SIZE = 16;
		static const float RADIUS = SIZE*1.5;

		short lod;
		Vec3f center;
		Geometry geometry;
	}

	private IHeightGenerator generator;
	private Patch patches[][]; //terrain is an array of patches
	private Vec2i halfRes;

	Material material;

	this(IHeightGenerator generator, TextureInstance[] textures=null)
	{
		this.generator=generator;
		Vec2i resolution = generator.getResolution();
		//we will need to use the resolution divided / 2
		halfRes = Vec2i(resolution.x / 2, resolution.y / 2);

		//create the array of patches
		patches.length = resolution.x / Patch.SIZE;
		foreach (ref p; patches)
		{
			p.length = resolution.y / Patch.SIZE;
		}

		for (int i=0; i < patches.length; ++i)
			for (int j=0; j < patches[0].length; ++j)
			{
				patches[i][j].geometry = createPatchGeometry(i, j);
				patches[i][j].center = Vec3f(i*Patch.SIZE + Patch.SIZE/2 - halfRes.x,
							j*Patch.SIZE + Patch.SIZE/2 - halfRes.y,
							0);
				patches[i][j].center /= Vec3f(cast(float)(halfRes.x), cast(float)(halfRes.y), 1);
			}

		material = new Material();
		material.setPass(new MaterialPass());

		//terrainGeometry.drawNormals=true;
	}

	/**
	 * public function expected by the renderer
	 */
	override void getRenderCommands(CameraNode camera, LightNode[] lights, ref ArrayBuilder!(RenderCommand) result)
	{
		RenderCommand rc;
		Vec3f patchCenter;
		Geometry[] renderGeometry;
		static int counter = 0;
		counter++;
		//Log.info(counter);

		/* Look if each patch is visible by the camera (fustrum culling) */
		for (int i=0; i < patches.length; ++i)
			for (int j=0; j < patches[0].length; ++j)
			{
  				if (camera.isVisible(patches[i][j].center, Patch.RADIUS/(2*halfRes.x)))
  				{
  					//renderGeometry ~= patches[i][j].geometry;
  					if (counter == 100){
  						Log.info("patch [", i, "][", j,"] is visible");
  						counter = 0;
					}
					
				}
			}

		rc.transform = getWorldTransform().scale(getSize());
		rc.geometry = Geometry.merge( renderGeometry );
		rc.materialOverrides = materialOverrides;
		auto l = getLights(lights, 8);
		rc.setLights(l);
		result.append(rc);
	}


	private Geometry createPatchGeometry(int i, int j)
	{	Log.info("creating ", i, j, " geos.");
		Geometry patchGeometry = new Geometry();
		Vec3f[] vertices;
		Vec3f[] normals;
		Vec2f[] texCoords;

		/*
		 * Set attributes retrieved with getTerrainPoint.
		 * The use of halfRes comes to center the terrain in the scene world
		 */
		TerrainPoint terrainPoint;
		for (int y = j * Patch.SIZE; y < (j+1) * Patch.SIZE; ++y)
			for (int x = i * Patch.SIZE; x < (i+1) * Patch.SIZE; ++x)
			{
				terrainPoint = generator.getTerrainPoint(Vec2i(x,y));
				/* 
				 * At this point x is between 0 and 'resolution'.
				 * So a "- halfRes" is necessary to center the terrain.
				 */
				vertices  ~= Vec3f((x-halfRes.x)/cast(float)(halfRes.x),
						(y-halfRes.y)/cast(float)(halfRes.y),
						 terrainPoint.height);
				normals   ~= terrainPoint.normal;
				texCoords ~= terrainPoint.textureCoordinate;
			}

		patchGeometry.setAttribute(Geometry.VERTICES, vertices);
		patchGeometry.setAttribute(Geometry.NORMALS, normals);
		patchGeometry.setAttribute(Geometry.TEXCOORDS0, texCoords);

		/* Construct the array of triangles */
		Vec3i[] triangles;
		int cornerCurrent, cornerUp;
		for (int y=0; y < Patch.SIZE-1; ++y)
		// -1 because the last vertices are included in the previous last triangles.
			for (int x=0; x < Patch.SIZE-1; ++x)
			{	cornerCurrent = y*(Patch.SIZE)+x;
				cornerUp = (y+1)*(Patch.SIZE)+x;
				triangles ~= Vec3i(cornerCurrent, cornerCurrent+1, cornerUp);
				triangles ~= Vec3i(cornerUp, cornerCurrent+1, cornerUp+1);
			}

		patchGeometry.setMeshes([new Mesh(material, triangles)]);
		patchGeometry.setAttribute(Geometry.TEXCOORDS1, patchGeometry.createTangentVectors());
		
		return patchGeometry;
	}


/+
	/**
	 * The terrain geometry is divided into blocks, each at multiple levels of detail.
	 * This function is used by the renderer to get a set of Geometry visible by the specified camera.
	 * Params:
	 *     camera = Only blocks inside the Camera's view frustum will be returned.
	 *     pixelsPerPolygon = Blocks closer to the camera will provide higher resolution Geometry.
	 *         Every block returned will have its polygons smaller than pixelsPerPolygon.
	 *         Smaller values for pixelsPerPolygon will yield blocks with more polygons and a better rendering.
	 */
	Geometry getVisibleGeometry(CameraNode camera)
	{
		/// TODO
		// This Geometry can be passed directly to the render system.
		// We should probably generate geometry lazily--this will allow for ginormous terrains too big to fit in memory.
		// And also free mipmaps that haven't been used in a while--a complete paging system.
		
		struct TerrainPatch {
			const int SIZE = 16;
			const int MAXHEIGHT = 255;

			int index;
			short lod;
		}

		/* culling of patches using the Radar algorithm
		 * http://www.lighthouse3d.com/opengl/viewfrustum/index.php?camspace3
		 */
		//origin point of the terrain
		Vec3f originTerrain = this.getWorldPosition();

		// For each patch and its bounding cube

			// 1. find the coordinates of the 8 vertices of the bounding cube in the camera coordinates
			Vec3f cameraPosition = camera.getWorldPosition();
			Vec3f bc0 = cameraPosition - originTerrain;
			Vec3f bc1 = cameraPosition - originTerrain + Vec3f(TerrainPatch.SIZE, 0, 0);
			Vec3f bc2 = cameraPosition - originTerrain + Vec3f(TerrainPatch.SIZE, TerrainPatch.SIZE, 0);
			Vec3f bc3 = cameraPosition - originTerrain + Vec3f(0, TerrainPatch.SIZE, 0);
	
			Vec3f bc4 = cameraPosition - originTerrain + Vec3f(0, 0, TerrainPatch.MAXHEIGHT);
			Vec3f bc5 = cameraPosition - originTerrain + Vec3f(TerrainPatch.SIZE, 0, TerrainPatch.MAXHEIGHT);
			Vec3f bc6 = cameraPosition - originTerrain + Vec3f(TerrainPatch.SIZE, TerrainPatch.SIZE, TerrainPatch.MAXHEIGHT);
			Vec3f bc7 = cameraPosition - originTerrain + Vec3f(0, TerrainPatch.SIZE, TerrainPatch.MAXHEIGHT);
			// 2. verify that at least one z coordinates is inside the frustum
		
		
		//1 locate if the camera is close enough in absolute coordinates, otherwise minimize LOD everywhere
		
		//2 If close enough, project its coordinates in the plane of the terrain, then transform this coordinate in the system of coordinates where the center of the terrain is 0. It means:
		//applying backward the setposition of the Terrain to the camera, then using the rotation vector of the terrain as a basis.
		
		//3 determine the range impacted around the camera projection xmin xmax, ymin ymax
		
		//4 for the entire terrain, calculate vertices, normals and texcoords in minimum LOD. Store in a linear array.
		//The resolution of this grid is maybe 4 times smaller.
		
		//5 In range xmin xmax ymin ymax, calculate extra vertices
		// take border cases separately (where cracking can happen)
		
		//triangle problem...
		
		return null;
	}
+/


/+ test area ################################### */
	protected Geometry testGeom;
	protected float radius;

	this(HeightGenerator generator, TextureInstance[] textures=null)
	{
		Vec2i resolution = generator.getResolution();
		//Initialize geometry
		this.testGeom = new Geometry();
		if (resolution.x > resolution.y)
			//0.75 = sqrt(2)/2, because the grid is not a circle!
			this.radius = resolution.x*0.75;
		else
			this.radius = resolution.y*0.75;

		//we will need to use the resolution divided / 2
		Vec2i halfRes = { resolution.x / 2, resolution.y / 2 };
		Vec3f[] vertices;
		Vec3f[] normals;
		Vec2f[] texCoords;

		/* Set attributes retrieved with getTerrainPoint.
		 * The divisions by 2 comes to center the terrain in the scene worlde
		 */
		TerrainPoint terrainPoint;
		for (int y = -halfRes.y; y < halfRes.y; ++y)
			for (int x= -halfRes.x; x < halfRes.x; ++x)
			{
				terrainPoint = generator.getTerrainPoint(Vec2i(x,y));

				vertices  ~= Vec3f(x/cast(float)(halfRes.x), y/cast(float)(halfRes.y), terrainPoint.height);
				normals   ~= terrainPoint.normal;
				texCoords ~= terrainPoint.textureCoordinate;
			}

		testGeom.setAttribute(Geometry.VERTICES, vertices);
		testGeom.setAttribute(Geometry.NORMALS, normals);
		testGeom.setAttribute(Geometry.TEXCOORDS0, texCoords);

		/* Construct the array of triangles */
		Vec3i[] triangles;
		int cornerCurrent, cornerUp;
		for (int y=0; y < resolution.y-1; ++y)// -1 because the last vertices are included in the previous last triangles.
			for (int x=0; x < resolution.x-1; ++x)//ditto
			{	cornerCurrent = y*(resolution.x)+x;
				cornerUp = (y+1)*(resolution.x)+x;
				triangles ~= Vec3i(cornerCurrent, cornerCurrent+1, cornerUp);
				triangles ~= Vec3i(cornerUp, cornerCurrent+1, cornerUp+1);
			}

		Material material = new Material();
		material.setPass(new MaterialPass());
		testGeom.setMeshes([new Mesh(material, triangles)]);

		testGeom.setAttribute(Geometry.TEXCOORDS1, testGeom.createTangentVectors());
		//testGeom.drawNormals=true;
	}
	
	override void getRenderCommands(CameraNode camera, LightNode[] lights, ref ArrayBuilder!(RenderCommand) result)
	{
		Vec3f wp = getWorldPosition();
		if (camera.scene !is scene)
			wp += camera.getWorldPosition();

		if (camera.isVisible(wp, getRadius()))
		{
			RenderCommand rc;
			rc.transform = getWorldTransform().scale(getSize());
			rc.geometry = this.testGeom;
			rc.materialOverrides = materialOverrides;
			auto l = getLights(lights, 8);
			rc.setLights(l);
			result.append(rc);
		}
	}

	public	float getRadius()
	{	//Log.info(radius*getScale().max());
		return radius*getScale().max();
	}
+/
}

/**
 * Generate a grid of height values, used by terrainNode. Methods:
 * heightmap
 * 1 random algorithm TODO
 * erosion algorithm TODO
 * TODO: filtering functions
 * TODO: accessor to update some height values for deformable terrain
 */
interface IHeightGenerator
{
	/**
	 * Get the values needed for a single vertex in the Terrain Geometry. 
	 */
	public TerrainPoint getTerrainPoint(Vec2i gridCoordinate);
	public Vec2i getResolution();
	
	/**
	 * Get a lightmap Texture to use across the range of coordinates.
	 * If no lightmap is desired, this function can return a Texture without a Texture.
	 * The same GPU Texture can be reused across multiple calls with different values, 
	 * if the Textures' texture matrix adjusted as needed.
	 * Params:
	 *     min = Minumum xy coordinate of the rectangle needing a lightmap.
	 *     max = Maximum xy coordinate of the rectangle needing a lightmap.
	 * Returns: An RGB texture to use as a baked light-map.  It's color values will be modulated with the terrain. */
	public TextureInstance getLightmap(Vec2f min, Vec2f max);	
}

/**
 * A sample TerrainGenerator that uses a heightmap image to specify elevation and a color texture
 * to specify which textures to use at a given point. */
class HmapHeightGenerator : IHeightGenerator
{
	enum Scaling { INTERPOLATE, REPEAT };

	Image heightmap;
	Image imageTexturesBlend;
	Vec2i gridResolution;
	TerrainPoint terrainPoints[][];
	Scaling scaling;

	/**
	 * Build a set of TerrainPoint stored in a matrix array, representing a terrain.
	 * @param heightMapPath:	where to find the heightmap image.
	 * @param resolution:		the grid resolution = the number of vertices composing the terrain.
	 * @param scaling:		what to do if the heightmap and grid sizes mismatch.
	 * @param lightmapPath:		where to find the lightmap.
	 * @param texturesBlendPath:	where to find the texturesBlend image. The channels of the texturesBlend Image
	 *				indicate how to blend the textures from a set of 4 textures or less.
	 * TODO: replace Image with Image2
	 * TODO: use an array of texturesBlendPaths to allow blending of more than 4 textures
	 */
	this(char[] heightmapPath, Vec2i gridResolution=Vec2i(256), Scaling scaling=Scaling.REPEAT, char[] lightmapPath=null, char[] texturesBlendPath=null)
	{
		assert(heightmapPath.length != 0);

		this.heightmap = new Image(ResourceManager.resolvePath(heightmapPath));
		this.gridResolution = gridResolution;
		this.scaling = scaling;
		if (texturesBlendPath.length != 0)
			this.imageTexturesBlend = new Image(ResourceManager.resolvePath(texturesBlendPath));

		/* initialize the matrix array of terrain points */
		terrainPoints.length = gridResolution.x;
		foreach (ref e; terrainPoints)
		{
			e.length = gridResolution.y;
		}

		computeTerrainPoints();
	}

	/******* accessors *******/
	/* return a TerrainPoint. Called from a TerrainNode */
	public TerrainPoint getTerrainPoint(Vec2i gridCoordinate)
	{
		with (gridCoordinate)
		{
			/* translate the coordinate to a positive index, for lookup in the TerrainPoints array */
			//x += gridResolution.x / 2;
			//y += gridResolution.y / 2;
			//Log.info("getTerrainPoint looks for [", x,"][", y, "]");
			return terrainPoints[x][y];
		}
	}

	public Vec2i getResolution()
	{	return this.gridResolution;
	}


	/* TODO: implementation (from old interface code) */
	public TextureInstance getLightmap(Vec2f min, Vec2f max)
	{	TextureInstance texture;
		return texture; // return no lightmap for now.
	}
	/*** end accessors *******/


	/**
	 * Fill the array TerrainPoints. It is done in 2 passes since the normals are calculated
	 * from the height value of surrounding vertices.
	 * 1rst pass: calculate height, texture coords, texture blend
	 * 2nd pass: call computeTerrainPointsNormals() which does just that
	 */
	private void computeTerrainPoints()
	{
		int x, y, z;

		for(x = 0; x < gridResolution.x; x++)
		{
			for(y = 0; y < gridResolution.y; y++)
			{
				/* compute height */
				if (scaling == Scaling.INTERPOLATE)
					terrainPoints[x][y].height = getInterpolateHeightValue(Vec2i(x,y));
				else if (scaling == Scaling.REPEAT)
					terrainPoints[x][y].height = getRepeatHeightValue(Vec2i(x,y));

				/* compute texture coordinates */
				terrainPoints[x][y].textureCoordinate = Vec2f(
					cast(float)(x)/gridResolution.x,
					1-cast(float)(y)/gridResolution.y);
					
				/* compute texture Blend */
				if(imageTexturesBlend is null)
				{
					terrainPoints[x][y].texturesBlend[] = -1;
				}
				else
				{
					for(z = 0; z < imageTexturesBlend.getChannels(); ++z)
						terrainPoints[x][y].texturesBlend[z] = imageTexturesBlend[x, y][z];
				}
			}
		}

		/* Now we have the height we can calculate the normals */
		computeTerrainPointsNormals();
	}

	/*
	 * This function is called from computeTerrainPoints
	 * It only calculate the normals.
	 */
	private void computeTerrainPointsNormals()
	{
		int x, y;
		Vec3f norm1, norm2, norm3, norm4, normXY;
		float heightDiff;
		float diagonalNormalized = 2.828427/225f; //2*sqrt(2)
		float lineNormalized = 2/255f;
		/* 
		 * A	B	C
		 * D	(x,y)	E
		 * F	G	H
		 * Using the heightmap, we calculate the normals of the 4 slopes passing "through" the point (x,y),
		 * ie the normals of AH, BG, CF and DE. We then sum them and normalize them to obtain
		 * the normal of vertex (x,y).
		 */
		for(x = 1; x < gridResolution.x - 1; ++x)
		{
			for(y = 1; y < gridResolution.y - 1; ++y)
			{
				//normal to AH
				//heightDiff = terrainPoints[x-1][y+1].height-terrainPoints[x+1][y-1].height;
				//norm1 = Vec3f(heightDiff, -heightDiff, diagonalNormalized);

				//normal to BG
				heightDiff = terrainPoints[x][y+1].height-terrainPoints[x][y-1].height;
				norm2 = Vec3f(0, -heightDiff, lineNormalized);

				//normal to CF
				//heightDiff = terrainPoints[x+1][y+1].height-terrainPoints[x-1][y-1].height;
				//norm3 = Vec3f(-heightDiff, -heightDiff, diagonalNormalized);

				//normal to DE
				heightDiff = terrainPoints[x-1][y].height-terrainPoints[x+1][y].height;
				norm4 = Vec3f(heightDiff, 0, lineNormalized);

				//normXY = (norm1+norm2+norm3+norm4)/4;
				//normXY.z /= 4;
				normXY = (norm2+norm4)/2;
				normXY.z /= 2;//test
				//Log.info("normXY: ", normXY);
				terrainPoints[x][y].normal = normXY.normalize();
			}
		}
		/* special border cases for the normals, left at (0,0,1) for now */
		for(x = 0; x < gridResolution.x; ++x)
			terrainPoints[x][0].normal = Vec3f(0,0,1);
		for(x = 0; x < gridResolution.x; ++x)
			terrainPoints[x][gridResolution.y-1].normal = Vec3f(0,0,1);
		for(y = 0; y < gridResolution.y; ++y)
			terrainPoints[0][y].normal = Vec3f(0,0,1);
		for(y = 0; y < gridResolution.y; ++y)
			terrainPoints[gridResolution.x-1][y].normal = Vec3f(0,0,1);
	}


	/**
	 * interpolate the altitude corresponding to the grid point defined by 'coordinate'
	 * @return : the height value between 0 and 1
	 */
	private float getInterpolateHeightValue(Vec2i gridCoordinate)
	{	Image.Pixel4 p4;
		Vec2f filterCoordinate;
		with(filterCoordinate)
		{	//the bilinear filter uses values between 0 and 1, so we have to normalize gridCoordinate.
			x = gridCoordinate.x / cast(float)(gridResolution.x);
			y = gridCoordinate.y / cast(float)(gridResolution.y);
			/*
			 * Find the interpolated height.
			 * FIXME: Overkill if the heightmap has the same resolution than the grid
			 */
			p4 = heightmap.bilinearFilter(x, y);
		}
		return cast(float)(p4.v[0]) / 255f;
	}


	/**
	 * find the altitude corresponding to the grid point defined by 'coordinate',
	 * clamping the heightmap is it is bigger than the grid or
	 * repeating the heightmap if it is smaller than the grid (instead of interpolating)
	 * @return : the height value between 0 and 1
	 */
	private float getRepeatHeightValue(Vec2i gridCoordinate)
	{
		float height;
		with(gridCoordinate)
		{	x = x % heightmap.getWidth();
			y = y % heightmap.getHeight();
			return heightmap[x, y][0] / 255f;
		}
	}
}
