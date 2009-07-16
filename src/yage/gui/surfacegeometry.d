/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:	   Eric Poggel
 * License:	   <a href="lgpl.txt">LGPL</a> 
 */

module yage.gui.surfacegeometry;

import yage.core.all;

import yage.resource.texture;
import yage.resource.geometry;
import yage.resource.material;
/**
 * SurfaceGeometry defines vertices and meshes for drawing a surface, including borders/border textures.
 * The vertices and triangles are laid out in a 4x4 grid in column-major order, just like the 4x4 matrices.
 * Nine 11 are defined, one for each border region and 3 for the center.
 * 0__4__8__12      BR
 * |\ |\ |\ |       BR
 * 1_\5_\9_\13      BR
 * |\ |\ |\ |       BR
 * 2_\6_\10\14      BR
 * |\ |\ |\ |       BR
 * 3_\7_\11\15      BR
 * 
 * Vertices used for center2 Mesh, which is used for background-color and the border-image center.
 * 16_18
 * |\ |
 * 17\19
 * 
 * Vertices used for text Mesh, which renders any text
 * 20_22
 * |\ |
 * 21\23
 * 
 * Rendering occurs in up to 4 passes.
 * First, render the borders and center1 with colors enabled and texturing disabled, for the borders and background-color
 * Second, render center2 with texturing enabled, for the background-image
 * Third, render the borders and center3 with colors disabled and texturing enabled for the border-image.
 * Finally, the text itself is rendered
 *  
 * See: http://www.w3.org/TR/css3-background/#the-border-image
 */
package class SurfaceGeometry : Geometry
{
	VertexBuffer!(Vec2f) vertices;
	VertexBuffer!(Vec2f) texcoords;
	
	// Meshes for border and background colors.  Meshes are defined in the order that they're rendered.
	union {
		struct {
			Mesh top;
			Mesh right;
			Mesh bottom;
			Mesh left;			
		}
		Mesh[4] borderColor;
	}
	Mesh backgroundColor;
	Mesh backgroundImage; // because different texture coordinates are needed.
	
	// Meshes for border image
	union {
		struct {			
			Mesh topImage;			
			Mesh rightImage;		
			Mesh bottomImage;			
			Mesh leftImage;
		}
		Mesh[4] borderImage;
	}
	union {
		struct {
			Mesh topLeftImage;
			Mesh topRightImage;
			Mesh bottomRightImage;
			Mesh bottomLeftImage;
		}
		Mesh[4] borderCornerImage;
	}
	Mesh centerImage;
	
	Mesh text;
	
	/**
	 * Create the vertices, texture coordinates, meshes, and materials used for rendering a surface. */
	this()
	{	
		// Create Vertex Arrays
		setVertices(new Vec2f[24]);
		setTexCoords0(new Vec2f[24]);
		vertices = cast(VertexBuffer!(Vec2f))getAttribute(Geometry.VERTICES);
		texcoords = cast(VertexBuffer!(Vec2f))getAttribute(Geometry.TEXCOORDS0);
		
		// Make a new material with a single layer with a diffuse color of white.
		Material createMaterial()
		{	auto result = new Material();
			result.addLayer(new Layer());
			return result;
		}
		
		// Create Meshes for Borders and Background Color
		top          = new Mesh(createMaterial(), [Vec3i(0, 5, 4), Vec3i(4, 5, 9), Vec3i(4, 9, 8), Vec3i(8, 9, 12)]);
		right        = new Mesh(createMaterial(), [Vec3i(9, 13, 12), Vec3i(9, 10, 14), Vec3i(14, 13, 9), Vec3i(10, 15, 14)]);
		bottom       = new Mesh(createMaterial(), [Vec3i(3, 7, 6), Vec3i(6, 7, 11), Vec3i(11, 10, 6), Vec3i(10, 11, 15)]);
		left         = new Mesh(createMaterial(), [Vec3i(0, 1, 5), Vec3i(1, 6, 5), Vec3i(1, 2, 6), Vec3i(2, 3, 6)]);		
		backgroundColor      = new Mesh(createMaterial(), [Vec3i(5, 6, 10), Vec3i(5, 10, 9)]);
				
		// Mesh for Background Image
		backgroundImage      = new Mesh(createMaterial(), [Vec3i(16, 17, 19),Vec3i(19, 18, 16)]);
		
		// Create Meshes for Border Image
		topLeftImage     = new Mesh(null, [Vec3i(0, 1, 5), Vec3i(5, 4, 0)]);
		topImage         = new Mesh(null, [Vec3i(4, 5, 9), Vec3i(9, 8, 4)]);
		topRightImage    = new Mesh(null, [Vec3i(8, 9, 13),Vec3i(13, 12, 8)]);
		rightImage       = new Mesh(null, [Vec3i(9, 10,14),Vec3i(14, 13, 9)]);
		bottomRightImage = new Mesh(null, [Vec3i(10, 11, 15), Vec3i(15, 14, 10)]);
		bottomImage= new Mesh(null, [Vec3i(6, 7, 11),Vec3i(11, 10, 6)]);
		bottomLeftImage  = new Mesh(null, [Vec3i(2, 3, 7), Vec3i(7, 6, 2)]);
		leftImage        = new Mesh(null, [Vec3i(1, 2, 6), Vec3i(6, 5, 1)]);
		centerImage      = new Mesh(null, [Vec3i(5, 6, 10), Vec3i(5, 10, 9)]);
		
		text   			 = new Mesh(null, [Vec3i(20, 21, 23),Vec3i(23, 22, 20)]);
		
		setMeshes([
			top, right, bottom, left, backgroundColor, backgroundImage,
			topLeftImage, topImage, topRightImage, rightImage, 
			bottomRightImage, bottomImage, bottomLeftImage, leftImage, centerImage, text]);
	}
	
	/**
	 * Set the colors for the center and the top, right, bottom, and left borders
	 * TODO: */
	void setColors(Color center, Color[4] borderColor)
	{	backgroundColor.getMaterial().getLayers()[0].color = center; // changing the color seems to have no effect.
	
		for (int i=0; i<4; i++) // top, right, bottom, left
			this.borderColor[i].getMaterial().getLayers()[0].color = borderColor[i];
	}
	
	/**
	 * Set the dimensions of the surface's geometry
	 * Params:
	 *     dimensions = Used to set the width and the height in pixels
	 *     borders = Used to set the size of each border in pixels (top, right, bottom, left) 
	 *     padding = Used to se the size of teh padding in pixels (top, right, bottom, left)*/
	void setDimensions(Vec2f dimensions, Vec4f borders, Vec4f padding /*, Vec2f backgroundPosition, ubyte backgroundRepeatX, ubyte backgroundRepeatY*/)
	{	Vec2f[] vertices = cast(Vec2f[])(getVertices().getData());
		
		// Note that some vertices are left at 0
		// This also positions the quad for mesh backgroundColor.
		vertices[ 4].x = vertices[ 5].x = vertices[ 6].x = vertices[ 7].x = borders.left;
		vertices[ 8].x = vertices[ 9].x = vertices[10].x = vertices[11].x = borders.left + padding.left + dimensions.width + padding.right;
		vertices[12].x = vertices[13].x = vertices[14].x = vertices[15].x = borders.left + padding.left + dimensions.width + padding.right + borders.right;
		
		vertices[ 1].y = vertices[ 5].y = vertices[ 9].y = vertices[13].y = borders.top;
		vertices[ 2].y = vertices[ 6].y = vertices[10].y = vertices[14].y = borders.top + padding.top + dimensions.height + padding.bottom;
		vertices[ 3].y = vertices[ 7].y = vertices[11].y = vertices[15].y = borders.top + padding.top + dimensions.height + padding.bottom + borders.bottom;		
		
		// Position quad for mesh backgroundImage.  For now, we just stretch it to fill the entire area.
		vertices[16].x = vertices[17].x = borders.left;
		vertices[18].x = vertices[19].x = borders.left + padding.left + dimensions.width + padding.right;
		vertices[16].y = vertices[18].y = borders.top;
		vertices[17].y = vertices[19].y = borders.top + padding.top + dimensions.height + padding.bottom;
		
		vertices[20].x = vertices[21].x = borders.left + padding.left;
		vertices[22].x = vertices[23].x = borders.left + padding.left + dimensions.width;
		vertices[20].y = vertices[22].y = borders.top + padding.top;
		vertices[21].y = vertices[23].y = borders.top + padding.top + dimensions.height;
		
		setVertices(vertices);
		
		// Set Texture Coordinates for Border Image
		Vec2f[] texcoords = cast(Vec2f[])getTexCoords0().getData();
		texcoords[4].x = texcoords[5].x = texcoords[6].x = texcoords[7].x = 1/3.0f;
		texcoords[8].x = texcoords[9].x = texcoords[10].x= texcoords[11].x= 2/3.0f;
		texcoords[12].x= texcoords[13].x= texcoords[14].x= texcoords[15].x= 1;
		texcoords[1].y = texcoords[5].y = texcoords[9].y = texcoords[13].y= 1/3.0f;
		texcoords[2].y = texcoords[6].y = texcoords[10].y= texcoords[14].y= 2/3.0f;
		texcoords[3].y = texcoords[7].y = texcoords[11].y= texcoords[15].y= 1;
		
		// Texture Coordinates for Background Image and Text
		texcoords[16].x = texcoords[17].x = texcoords[20].x = texcoords[21].x = 0;
		texcoords[18].x = texcoords[19].x = texcoords[22].x = texcoords[23].x = 1;		
		texcoords[16].y = texcoords[18].y = texcoords[20].y = texcoords[22].y = 0;
		texcoords[17].y = texcoords[19].y = texcoords[21].y = texcoords[23].y = 1;
		
		setTexCoords0(texcoords);
	}

	// TODO: Convert this to accept materials as well as textures, 
	// or maybe just allow instantiation of a Material from a GPUTexture, Texture, or Layer
	void setMaterials(GPUTexture backgroundImage, GPUTexture centerImage, GPUTexture[] borderImage, GPUTexture[] borderCornerImage, GPUTexture text)
	{	
		Layer createLayer(GPUTexture texture, bool clamp=false)
		{	auto result = new Layer();
			result.addTexture(Texture(texture, clamp, Texture.Filter.BILINEAR));
			return result;
		}
		Layer createLayer2(Texture texture)
		{	auto result = new Layer();
			result.addTexture(texture);
			return result;
		}
		
		// Background Image
		if (backgroundImage)
		{	this.backgroundImage.setMaterial(new Material());
			this.backgroundImage.getMaterial().addLayer(createLayer(backgroundImage));
		} else
			this.backgroundImage.setMaterial(cast(Material)null);
		
		// Border Images
		foreach(mesh; this.borderImage)
		{	if (borderImage[0])
			{	mesh.setMaterial(new Material());
				mesh.getMaterial().addLayer(createLayer(borderImage[0]));
			} else
				mesh.setMaterial(cast(Material)null);
		}
		foreach(mesh; this.borderCornerImage)
		{	if (borderCornerImage[0])
			{	mesh.setMaterial(new Material());
				mesh.getMaterial().addLayer(createLayer(borderCornerImage[0]));
			} else
				mesh.setMaterial(cast(Material)null);
		}

		if (centerImage)
		{	this.centerImage.setMaterial(new Material());
			this.centerImage.getMaterial().addLayer(createLayer(centerImage));
		} else
			this.centerImage.setMaterial(cast(Material)null);
				
		if (text)
		{	this.text.setMaterial(new Material());
			this.text.getMaterial().addLayer(createLayer(text, true));
			this.text.getMaterial().getLayers()[0].blend = BLEND_AVERAGE;
			this.text.getMaterial().getLayers()[0].getTextures()[0].filter = Texture.Filter.NONE;
			
			// Text bottom vertices depend on text texture size.
			Vec2f[] vertices = cast(Vec2f[])(getVertices().getData());			
			float height = text.getHeight() - text.padding.y;
			vertices[21].y = vertices[23].y = vertices[20].y + height;			
			setVertices(vertices);
			
		} else
			this.text.setMaterial(cast(Material)null);

	}
}