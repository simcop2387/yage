/**
 * Authors:    Ludovic Angot, Eric Poggel
 * License:    Boost 1.0
 */
 
module yage.scene.terrain;

import yage.core.array;
import yage.core.math.vector;
import yage.core.math.matrix;
import tango.math.Math;
import tango.math.IEEE;

import yage.resource.graphics.geometry;
import yage.resource.image;

import yage.scene.light;
import yage.scene.camera;
import yage.scene.node;
import yage.scene.visible;

import yage.resource.graphics.material;
import yage.resource.graphics.texture;
import yage.resource.graphics.primitives;
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
{	float height=0;		/// z position of the terrain point
	Vec3f normal;		/// Normal vector for this point on the terrain, used for lighting
	Vec2f textureCoordinate;/// Texture coordinates for this point on the terrain
	float[] texturesBlend;	/// Normalized vector of arbitrary length specifying the amount of each texture to use at this point.
}


	struct Patch {
		static const int SIZE = 16;
		//static float RADIUS = (cast(float)(SIZE)/256)*1.414*1000; //longueur REELLE d'un demi-cote d'un patch*racineDeDeux*echelle (car transform)=>pb: ok si terrain plat ET carre seulement.
		float radius = 0; //radius value, in the world scale
        float maxHeight;
		float minHeight;
        Vec3f minPoint;
        Vec3f maxPoint;
		short lod;
		Vec3f center;
		Geometry geometry;
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

	private terrain_tree tree;
	private IHeightGenerator generator;
	private Patch patches[][]; //terrain is an array of patches
	private Vec2i halfRes;

	Material material;

	this (IHeightGenerator generator, Node parent=null)
	{	this(generator, null, parent);
	}
	
	this(IHeightGenerator generator, TextureInstance[] textures=null, Node parent=null)
	{	super(parent);
		this.generator=generator;
		Vec2i resolution = generator.getResolution();		
		Log.info("x: ",resolution.x,", y: ",resolution.y);
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
				//TerrainPoint terrainPoint;
				//terrainPoint = generator.getTerrainPoint(Vec2i(i*Patch.SIZE+Patch.SIZE/2,j*Patch.SIZE+Patch.SIZE/2)); //renvoie le point du centre afin de determiner sa hauteur
				patches[i][j].geometry = createPatchGeometry(i, j);
                //
				/*patches[i][j].center = Vec3f(i*Patch.SIZE + Patch.SIZE/2 - halfRes.x,
							j*Patch.SIZE + Patch.SIZE/2 - halfRes.y,
							0);*/
				/*patches[i][j].center = Vec3f(i*Patch.SIZE + Patch.SIZE/2 - halfRes.x,
							j*Patch.SIZE + Patch.SIZE/2 - halfRes.y,
							terrainPoint.height);*/
				/*patches[i][j].center /= Vec3f(cast(float)(halfRes.x), cast(float)(halfRes.y), 1);*/
			}
			
		/**/
			
		tree = new terrain_tree(resolution.x,Patch.SIZE);
		tree.generate_patch(patches);
		tree.getRoot().compute_data();
		tree.getRoot().afficheDescendants();
		
		
		
		/**/
		
		material = new Material();
		material.setPass(new MaterialPass());

		//terrainGeometry.drawNormals=true;

		// TODO: Set this to the proper amount
		transform().cullRadius = 100000;
	}

	/**
	 * public function expected by the renderer
	 */
	override void getRenderCommands(CameraNode camera, LightNode[] lights, ref ArrayBuilder!(RenderCommand) result)
	{
		Vec3f patchCenter;
		Matrix transform = getWorldTransform();
		auto affectingLights = getLights(lights, 8); // TODO: getLights() for each individual patch.
		static int k=0;
		
		void renderNode(QuadTreeNode* node){					
			if(node.sons[0] is null) {
				RenderCommand rc;
  				rc.transform = transform;
  				rc.geometry = node.associatedPatch.geometry;
  				rc.materialOverrides = materialOverrides;
  				rc.setLights(affectingLights);
  				result.append(rc);	
			}			
			else {
				foreach(s;node.sons){
					renderNode(&s);
				}
			}			
		}
        
		void recursiveCull(QuadTreeNode* node){
			int ans = -1;
			ans=camera.isCulled(node.minPoint.transform(transform),node.maxPoint.transform(transform));
			switch (ans){
				case true:
                    //Log.info(node.getNodeName()," visible");
					renderNode(node);                
				break;
				case false:
                    //Log.info(node.getNodeName()," not visible");
					break;                 
				case 2:
                    //Log.info(node.getNodeName()," intersection");
					if(node.sons[0] !is null){
						foreach(s;node.sons){
							recursiveCull(&s);
						}
					}
					else {
						renderNode(node);
					}
					break;
				default:
			}					
		}
		recursiveCull(tree.getRoot());		
		
        /+
		for (int i=0; i < patches.length; ++i)
			for (int j=0; j < patches[0].length; ++j)				
			{    
                //Log.info("avant: ",patches[i][j].minPoint.z," ",patches[i][j].maxPoint.z);
                //Log.info("apres: ",patches[i][j].minPoint.transform(transform).z," ",patches[i][j].maxPoint.transform(transform).z);
            
  				if (!camera.isCulled(patches[i][j].minPoint.transform(transform),patches[i][j].maxPoint.transform(transform)))
  				{
  					RenderCommand rc;
  					rc.transform = transform;
  					rc.geometry = patches[i][j].geometry;
  					rc.materialOverrides = materialOverrides;
  					rc.setLights(affectingLights);
  					result.append(rc);
				}
                
                
                //ancienne methode, corrigee, A optimiser (si possible):
                        
                /+if(k==0){				
                    Vec3f center = patches[i][j].center.transform(transform);
                    float dist1 = (patches[i][j].minPoint.transform(transform)-center).length();
                    float dist2 = (center-patches[i][j].maxPoint.transform(transform)).length();
                    patches[i][j].radius = max(dist1,dist2);
                    //Log.info(patches[i][j].radius);										
                } 
                //Log.info("avant transform ",patches[i][j].center.x," ",patches[i][j].center.y," ",patches[i][j].center.z);
                //Log.info("apres transform ",patches[i][j].center.transform(transform).x," ",patches[i][j].center.transform(transform).y," ",patches[i][j].center.transform(transform).z);
                //if (camera.isVisible(patches[i][j].center.transform(transform),Patch.RADIUS))
				//if (camera.isVisible(patches[i][j].center.transform(transform),patches[i][j].radius))
                if (camera.isVisible(patches[i][j].center.transform(transform),patches[i][j].radius))
  				{
  					RenderCommand rc;
  					rc.transform = transform;
  					rc.geometry = patches[i][j].geometry;
  					rc.materialOverrides = materialOverrides;
  					rc.setLights(affectingLights);
  					result.append(rc);
				}+/
			}+/
		if(k==0){
			tree.generate_radius(patches,transform);
			k++;
		}				
	}

	private Geometry createPatchGeometry(int i, int j)
	{	//Log.info("creating ", i, j, " geos.");
		Geometry patchGeometry = new Geometry();
		Vec3f[] vertices;
		Vec3f[] normals;
		Vec2f[] texCoords;


		/*
		 * Set attributes retrieved with getTerrainPoint.
		 * The use of halfRes comes to center the terrain in the scene world
		 */

		TerrainPoint terrainPoint;
		/*initialisation des hauteurs*/
		patches[i][j].minHeight=patches[i][j].maxHeight=generator.getTerrainPoint(Vec2i(i * Patch.SIZE,j * Patch.SIZE)).height;
		for (int y = j * Patch.SIZE; y <= (j+1) * Patch.SIZE; ++y)
			for (int x = i * Patch.SIZE; x <= (i+1) * Patch.SIZE; ++x)
			{
				terrainPoint = generator.getTerrainPoint(Vec2i(x,y));
				/* 
				 * At this point x is between 0 and 'resolution'.
				 * So a "- halfRes" is necessary to center the terrain.
				 */
				if(terrainPoint.height>patches[i][j].maxHeight){
					patches[i][j].maxHeight=terrainPoint.height;
				}
				if(terrainPoint.height<patches[i][j].minHeight){
					patches[i][j].minHeight=terrainPoint.height;
				}
				vertices  ~= Vec3f((x-halfRes.x)/cast(float)(halfRes.x),
						(y-halfRes.y)/cast(float)(halfRes.y),
						 terrainPoint.height);
				normals   ~= terrainPoint.normal;
				texCoords ~= terrainPoint.textureCoordinate;
			}
        /*the AAB bounding box for each patch varies between xmin,xmax;ymin,ymax;
        zmin,zmax, so we defines minPoint(xmin,ymin,zmin) and maxPoint(xmax,ymax,zmax)*/    
        patches[i][j].minPoint = Vec3f(i*Patch.SIZE - halfRes.x,
							j*Patch.SIZE - halfRes.y,
							patches[i][j].minHeight);
		patches[i][j].maxPoint = Vec3f((i+1)*Patch.SIZE - halfRes.x,
							(j+1)*Patch.SIZE - halfRes.y,
							patches[i][j].maxHeight);
        patches[i][j].center = Vec3f(i*Patch.SIZE + Patch.SIZE/2 - halfRes.x,
                                    j*Patch.SIZE + Patch.SIZE/2 - halfRes.y,
                                    terrainPoint.height);                    
       
		
		patches[i][j].maxPoint /= Vec3f(cast(float)halfRes.x, cast(float)halfRes.y, 1);
		patches[i][j].minPoint /= Vec3f(cast(float)halfRes.x, cast(float)halfRes.y, 1);
		patches[i][j].center /= Vec3f(cast(float)halfRes.x, cast(float)halfRes.y, 1);
		       
		/**/
      
		
	  
        /**/

		assert(vertices.length);

		patchGeometry.setAttribute(Geometry.VERTICES, vertices);
		patchGeometry.setAttribute(Geometry.NORMALS, normals);
		patchGeometry.setAttribute(Geometry.TEXCOORDS0, texCoords);


		/* Construct the array of triangles */
		Vec3i[] triangles;
		int cornerCurrent, cornerUp;
		for (int y=0; y < Patch.SIZE; ++y)
		// -1 because the last vertices are included in the previous last triangles.
			for (int x=0; x < Patch.SIZE; ++x)
			{	cornerCurrent = y*(Patch.SIZE+1)+x;
				cornerUp = (y+1)*(Patch.SIZE+1)+x;
				triangles ~= Vec3i(cornerCurrent, cornerCurrent+1, cornerUp);
				triangles ~= Vec3i(cornerUp, cornerCurrent+1, cornerUp+1);
			}



		patchGeometry.setMeshes([new Mesh(material, triangles)]);
		patchGeometry.setAttribute(Geometry.TEXCOORDS1, patchGeometry.createTangentVectors());
		

		return patchGeometry;
	}


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
		terrainPoints.length = gridResolution.x+1;
		foreach (ref e; terrainPoints)
		{
			e.length = gridResolution.y+1;
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
		for(x = 1; x < gridResolution.x-1; ++x)
		{
			for(y = 1; y < gridResolution.y-1; ++y)
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
		for(x = 0; x <= gridResolution.x; ++x)
			terrainPoints[x][0].normal = Vec3f(0,0,1);
		for(x = 0; x <= gridResolution.x; ++x)
			terrainPoints[x][gridResolution.y-1].normal = Vec3f(0,0,1);
		for(y = 0; y <= gridResolution.y; ++y)
			terrainPoints[0][y].normal = Vec3f(0,0,1);
		for(y = 0; y <= gridResolution.y; ++y)
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

class terrain_tree {
	private QuadTreeNode root;
	//private QuadTreeNode* patches[][]; /*pointers to the leaves representing patches*/
	
	this(int resolution, int patchsize){
		root = new QuadTreeNode;	
		int log2=0;
		int init=resolution/patchsize;
		while (init!=1){
			init/=2;
			log2++;
		}		
		root.patches.length = resolution / patchsize;
		foreach (ref p; root.patches)
		{
			p.length = resolution / patchsize;
		}
		root.expand_tree(log2);	
	}	
	public void generate_patch( Patch p[][] ) {
		for( uint i=0; i < p.length; ++i ) {
			for ( uint j=0 ; j < p[0].length; ++j ) {
				QuadTreeNode.patches[i][j].set_patch(p[i][j]);
			}
		}
	}
	
	public void generate_radius( Patch p[][], Matrix transform) {
		for( uint i=0; i < p.length; ++i ) {
			for ( uint j=0; j < p[0].length; ++j ) {
				root.patches[i][j].set_radius( p[i][j] );
			}
		}
		root.compute_radius(transform);
	}
	
	public QuadTreeNode* getRoot(){
		return &root;
	}
}

class QuadTreeNode {
	public QuadTreeNode sons[4];
	public Patch associatedPatch; /*associated Patch (for leaves)*/
	public float radius = 0; /*radius of the bounding sphere*/
    public float maxHeight; /*maximum height of the AABB*/
	public float minHeight; /*minimum height of the AABB*/
    public Vec3f minPoint; /*minimum point of the AABB*/
    public Vec3f maxPoint; /*maximum point of the AABB*/
	public Vec3f center; /*center point of the AABB*/
	static public QuadTreeNode patches[][]; //leaves
	static private int number=0;
    private char[] nodeName = "[Root]";
	
    /*
    * Displays information about each node, considering the current QuadTreeNode instance as the root of the tree.
    *
    */
    import tango.text.convert.Integer;
    
	public void afficheDescendants(string nodename="[Root]"){
        Log.info("nodename: ",nodename);
		Log.info("max point x y z: ",maxPoint.x," ",maxPoint.y," ",maxPoint.z);
		Log.info("min point x y z: ",minPoint.x," ",minPoint.y," ",minPoint.z);
		if(sons[0] !is null){          
			foreach(i,s;sons){
                Log.info(nodename,"[",toString(i),"]");
				s.afficheDescendants(nodename~"["~toString(i)~"]");
			}
		}
	}	
    
    public char[] getNodeName(){
        return nodeName;
    }
			
	this() {
		foreach(ref s; sons){           
			s = null;
		}
	}
	
	/*
    * Subdivides a node of the tree.
    *
    */
    
	public void QuadTreeNode_subdivide() {
		foreach(i,ref s;sons){
			s = new QuadTreeNode;
            s.nodeName = nodeName~"["~toString(i)~"]";
		}
	}
	
    /*
    * Generates a complete quadtree of the given depth.
    *
    */
    
	public void expand_tree(uint depth) {
		if(depth==0){
			//Log.info(number);
			patches[number/patches.length][number%patches.length]=this;
			Log.info("feuille: adresse:",&this," contenu:",this);
			number++;
			return;
		}	
		QuadTreeNode_subdivide();
		foreach(ref s;sons){
			s.expand_tree(depth-1);
		}
	}
	
    /*
    * Copy Patch information to the node. (used for the leaves of the tree)
    * 
    * patch = Patch containing data to be copied in the node.
    */
    
	public void set_patch( Patch patch ) {
		radius = patch.radius;
        maxHeight = patch.maxHeight;
		minHeight = patch.minHeight;
        minPoint = patch.minPoint;
        maxPoint = patch.maxPoint;
		center = patch.center;
		associatedPatch = patch;
	}
	
    /*
    * Copy a patch radius information (bounding sphere radius) to a node.
    * (used for the leaves of the tree)
    *
    * patch = Patch which radius value is to be copied in the node.
    */
    
	public void set_radius(Patch patch){
		radius = patch.radius;
	}
	
    /*
    * Compute the data to assign data to each node of the tree, assuming that the leaves
    * have been assigned.
    */
    
	public void compute_data(){
		if(sons[0] is null){
			return;
		}
    
    if(sons[0].maxPoint.x == 0){
        foreach(ref s;sons){
			s.compute_data();
		}    
    }
    
	radius = 0;
    maxHeight = sons[0].maxHeight;
	minHeight = sons[0].minHeight;
    float Xmin = sons[0].minPoint.x;
	float Ymin = sons[0].minPoint.y;
	float Zmin = sons[0].minPoint.z;
    float Xmax = sons[0].maxPoint.x;
	float Ymax = sons[0].maxPoint.y;
	float Zmax = sons[0].maxPoint.z;
		for(int i=1; i<4; i++){
			if (sons[i].minPoint.x<=Xmin){
				Xmin= sons[i].minPoint.x;
			}
			if (sons[i].minPoint.y<=Ymin){
				Ymin = sons[i].minPoint.y;
			}
			if (sons[i].minPoint.z<=Zmin){
				Zmin = sons[i].minPoint.z;
			}
			if (sons[i].maxPoint.x>=Xmax){
				Xmax= sons[i].maxPoint.x;
			}
			if (sons[i].maxPoint.y>=Ymax){
				Ymax = sons[i].maxPoint.y;
			}
			if (sons[i].maxPoint.z>=Zmax){
				Zmax = sons[i].maxPoint.z;
			}
		}
		minPoint=Vec3f(Xmin,Ymin,Zmin);
		maxPoint=Vec3f(Xmax,Ymax,Zmax);
		maxHeight = Zmax;
		minHeight = Zmin;
		center = Vec3f((Xmin+Xmax)/2,(Ymin+Ymax)/2,(Zmin+Zmax)/2);
    }

	
	public void compute_radius(Matrix transform){
		if(sons[0] is null){
			return;
		}		
		Vec3f trueCenter = center.transform(transform);
        float dist1 = (minPoint.transform(transform)-trueCenter).length();
        float dist2 = (trueCenter-maxPoint.transform(transform)).length();
        radius = max(dist1,dist2);
		foreach(ref s;sons){
			s.compute_radius(transform);
		}					
	}		
    
	/+quadtree split_terrain(terrain ter, double seuil){
		quadtree tree = create_quadtree();
		int xmin      = 0;
		int ymin      = 0;
		int xmax      = terrain_give_largeur(ter)-1; // recuperer via getter ou sinon plaquer le quadtree directement dans terrain.d
		int ymax      = terrain_give_hauteur(ter)-1; // ditto
		
		recur_split(tree,ter,xmin,xmax,ymin,ymax,seuil);
		
		return tree;
	}
	
	void recur_split(quadtree tree,terrain ter,int x_min,int x_max,int y_min,int y_max,double seuil) {
		int x_avg     = (x_min + x_max)/2;
		int y_avg     = (y_min + y_max)/2;
	    
		if(quadratic(ter,x_min,x_max,y_min,y_max) > seuil){ // Caser la condition sur la visibilite
			quadtree_subdivide(tree);
			recur_split(tree->sons[0],picture,x_min  ,x_avg,y_min  ,y_avg);
			recur_split(tree->sons[1],picture,x_avg+1,x_max,y_min  ,y_avg);
			recur_split(tree->sons[2],picture,x_avg+1,x_max,y_avg+1,y_max);
			recur_split(tree->sons[3],picture,x_min  ,x_avg,y_avg+1,y_max);
		}
	}+/
}