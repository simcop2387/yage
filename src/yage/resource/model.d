/**
 * Copyright:  (c) 2006 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.model;

import std.string;
import std.file;
import std.math;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.vector;

import yage.resource.material;
import yage.resource.resource;
import yage.node.node;
import yage.system.constant;
import yage.system.device;
import yage.system.log;

extern (C) void *memcpy(void *, void *, uint);

/// Texture coordinates for each vertex

/** A Model is divided into one or more meshes.
 *  Each mesh has its own material and an array of triangle indices. */
class Mesh
{	/*protected*/ Vec3i[]	triangles;
	protected uint		vbo_triangles;
	protected Material	material;

	///
	this()
	{	if (Device.getSupport(DEVICE_VBO))
			glGenBuffersARB(1, &vbo_triangles);
	}

	///
	~this()
	{	if (Device.getSupport(DEVICE_VBO))
			glDeleteBuffersARB(triangles.length*Vec3i.sizeof, &vbo_triangles);
	}

	/// Get the mesh material.
	Material getMaterial()
	{	return material;
	}

	///
	void setMaterial(Material matl)
	{	this.material = matl;
	}

	///
	void setMaterial(char[] filename)
	{	this.material = Resource.material(filename);
	}

	///
	Vec3i[] getTriangles()
	{	return triangles;
	}

	/// Get the OpenGL Vertex Buffer Object index for the triangles indices.
	uint getTrianglesVBO()
	{	return vbo_triangles;
	}

	///
	void addTriangle(Vec3i t)
	{	triangles ~= t;
	}
}

/** A Model is a 3D object, typically loaded from a file.
 *  A model contains an array of vertices, texture coordinates, and normals.
 *  Each model is divided into one or more Meshes; each Mesh has its own material
 *  and an array of triangle indices that correspond to vertices in the Model's
 *  vertex array.  ModelNodes can be used to create 3D models in a scene.*/
class Model
{	/*protected:*/
	char[]	source;
	bool	cached = false;
	float	radius=0;			// the distance of the furthest vertex from the origin.

	Mesh[]	meshes;
	Vec3f[] vertices;
	Vec3f[] normals;
	Vec2f[]	texcoords;

	protected:
	uint 	vbo_vertices;	// OpenGL index of hardware vertex array
	uint 	vbo_texcoords;	// OpenGL index of hardware texture coordinate array
	uint 	vbo_normals;	// OpenGL index of hardware normal array

	public:
	/// Generate buffers in video memory for the vertex data.
	this()
	{	if (Device.getSupport(DEVICE_VBO))
		{	glGenBuffersARB(1, &vbo_vertices);
			glGenBuffersARB(1, &vbo_texcoords);
			glGenBuffersARB(1, &vbo_normals);
		}
	}

	/// Generate buffers and load and upload the given model file.
	this (char[] filename)
	{	this();
		loadMs3d(filename);
		upload();
	}

	/// Remove the model's vertex data from video memory.
	~this()
	{	if (source.length)
			Log.write("Removing model '" ~ source ~ "'.");
		if (Device.getSupport(DEVICE_VBO))
		{	glDeleteBuffersARB(1, &vbo_vertices);
			glDeleteBuffersARB(1, &vbo_normals);
			glDeleteBuffersARB(1, &vbo_texcoords);
		}
	}

	///
	int addVertex(Vec3f vert, Vec3f norm, Vec2f tex)
	{	vertices ~= vert;
		normals ~= norm;
		texcoords ~= tex;
		return vertices.length-1;
	}

	///
	int addMesh(Material matl=null, Vec3i[] triangles=null)
	{	Mesh a = new Mesh();
		a.setMaterial(matl);
		a.triangles = triangles;
		meshes ~= a;
		return meshes.length-1;
	}

	/// Get the path to the file where the model was loaded.
	char[] getSource()
	{	return source;
	}

	Mesh getMesh(int index)
	{	return meshes[index];
	}

	/// Get the array of meshes that compose this model.
	Mesh[] getMeshes()
	{	return meshes;
	}

	///
	Vec3f[] getVertices()
	{	return vertices;
	}

	///
	Vec3f[] getNormals()
	{	return normals;
	}

	///
	Vec2f[] getTexCoords()
	{	return texcoords;
	}


	/// Get the OpenGL Vertex Buffer Object index for the vertices.
	uint getVerticesVBO()
	{	return vbo_vertices;
	}

	/// Get the OpenGL Vertex Buffer Object index for the vertex texture coordinates.
	uint getTexCoordsVBO()
	{	return vbo_texcoords;
	}

	/// Get the OpenGL Vertex Buffer Object index for the vertex normals.
	uint getNormalsVBO()
	{	return vbo_normals;
	}

	/// Return true if the model data has been cached in video memory.
	bool getCached()
	{	return cached;
	}

	/** Get the radius of this model in world units.
	 *  This is the distance from the center of the model to the most distant Vertex,
	 *  before any scaling is performed. */
	float getRadius()
	{	return radius;
	}

	/// Calculate the radius of the model, which is the distance of the furthest vertex from the origin.
	void calcRadius()
	{	for (int v=0; v<vertices.length; v++)
		{	float max = vertices[v].length();
			if (max > radius)
				radius = max;
		}
	}

	/** Load a model from a Milkshape3D model file.
	 *  All materials, etc. referenced by this model are loaded through the Resource
	 *  manager to avoid duplicates.  Meshes without a material are assigned a default material.
	 *  Uploading vertex data to video memory must be done manually by calling Upload().
	 *  This function needs to be tested on big-endian systems. */
	void loadMs3d(char[] filename)
	{	source = Resource.resolvePath(filename);
		Log.write("Loading Milkshape 3D model '" ~ source ~ "'.");

		// Ms3d Data structures.  See the Ms3D SDK for details.
		// Ms3d Vertices
		struct mVertex
		{	align(1) byte		flags;			// SELECTED | SELECTED2 | HIDDEN
			align(1) float[3]	vertex;
			align(1) byte    	boneId;			// -1 = no bone
			align(1) byte    	referenceCount;
		}
		// Ms3d Triangles
		struct mTriangle
		{	align(1) ushort    	flags;			// SELECTED | SELECTED2 | HIDDEN
			align(1) ushort[3]	vertexIndices;
			align(1) float[9]	vertexNormals;
			align(1) float[3]	s;
			align(1) float[3]	t;
			align(1) byte		smoothingGroup;	// 1 - 32
			align(1) ubyte		groupIndex;
		}
		// Ms3d Groups
		struct mGroup
		{	align(1) ubyte		flags;			// SELECTED | HIDDEN
			align(1) char[32]	name;
			align(1) ushort		numtriangles;
			align(1) byte		materialIndex;	// -1 = no material (moved here for proper alignment)
			align(1) ushort[]	triangleIndices;// the groups group the triangles
		}
		//Ms3d Material
		struct mMaterial
		{	align(1) char[32]	name;
			align(1) float[4]	ambient;
			align(1) float[4]	diffuse;
			align(1) float[4]	specular;
			align(1) float[4]	emissive;
			align(1) float		shininess;		// 0.0f - 128.0f
			align(1) float		transparency;	// 0.0f - 1.0f
			align(1) char		mode;			// 0, 1, 2 is unused now
			align(1) char[128]	texture;		// texture.bmp
			align(1) char[128]	alphamap;		// alpha.bmp
		}

		// Local variables
		mVertex[]	mvertices;
		mTriangle[] mtriangles;
		mGroup[]	mgroups;
		mMaterial[] mmaterials;
		ushort 		size;		// used repeatedly as temporary size variable.
		uint 		idx=16; 	// current index in the file array.  The first loop starts at 16.
		ubyte[]		file = cast(ubyte[])read(source);
		char[]		path = source[0 .. rfind(source, "/") + 1]; // path stripped of filename

		// Check for Ms3d header
		if (icmp("MS3D000000", cast(char[])file[0..10])!=0)
			throw new Exception("This file does not have a valid MS3D header.");

		// Check Ms3d version (3 or 4 only)
		if (file[10] <3 || file[10] > 4)
			throw new Exception("Milkshape file format version " ~ .toString(file[10]) ~ " not supported.");

		// Vertices
		memcpy(&size, &file[14], 2);
		mvertices.length = size;
		for (int v=0; v<size; v++)
		{	memcpy(&mvertices[v], &file[idx], 15);
			idx+=15;
		}

		// Triangles and normals
		memcpy(&size, &file[idx], 2);
		mtriangles.length = size;
		idx+=2;
		for (int t=0; t<size; t++)
		{	memcpy(&mtriangles[t], &file[idx], 70);
			idx+=70;
		}

		// Groups (aka Meshes)
		memcpy(&size, &file[idx], 2);
		mgroups.length = size;
		idx+=2;
		for (int g=0; g<size; g++)
		{	// get number of triangles
			memcpy(&mgroups[g], &file[idx], 35);
			mgroups[g].triangleIndices.length = mgroups[g].numtriangles;
			// now copy the triangles into the mesh struct
			memcpy(&mgroups[g].triangleIndices[0], &file[idx+35], mgroups[g].numtriangles*2);
			memcpy(&mgroups[g].materialIndex, &file[idx+35+mgroups[g].numtriangles*2], 1);
			idx+=(36+mgroups[g].numtriangles*2);
		}

		// Materials
		memcpy(&size, &file[idx], 2);
		mmaterials.length = size;
		idx+=2;
		for (int m=0; m<size; m++)
		{	memcpy(&mmaterials[m], &file[idx], 361);
			idx+=361;
		}

		// Post processing

		// Vertices
		vertices.length  = mvertices.length;
		texcoords.length = mvertices.length;
		normals.length   = mvertices.length;

		for (int v; v<mvertices.length; v++)
		{	vertices[v].x = mvertices[v].vertex[0];
			vertices[v].y = mvertices[v].vertex[1];
			vertices[v].z = mvertices[v].vertex[2];
		}
		calcRadius();

		// Meshes
		meshes.length = mgroups.length;
		for (int m; m<meshes.length; m++)
		{	meshes[m] = new Mesh();
			meshes[m].triangles.length = mgroups[m].numtriangles;

			// Material
			if (mgroups[m].materialIndex != -1)
			{	// The filename exists in the system?

				char[] name = mmaterials[mgroups[m].materialIndex].name;
				if (exists(path~name))
					meshes[m].material = Resource.material(path~name);
				else // create new material
				{	meshes[m].material = new Material();
					meshes[m].material.addLayer(new Layer());

					mMaterial *cur_material = &mmaterials[mgroups[m].materialIndex];

					memcpy(&meshes[m].material.getLayer(0).ambient, cur_material.ambient.ptr, 16);
					memcpy(&meshes[m].material.getLayer(0).diffuse, cur_material.diffuse.ptr, 16);
					memcpy(&meshes[m].material.getLayer(0).specular, cur_material.specular.ptr, 16);
					memcpy(&meshes[m].material.getLayer(0).emissive, cur_material.emissive.ptr, 16);
					meshes[m].material.getLayer(0).specularity = cur_material.shininess;

					// Load textures
					// Ms3d stores a texture map and an alpha map for every material
					char[] texfile = .toString(cur_material.texture.ptr);
					if (texfile.length)
					{	if (icmp(texfile[0..2], ".\\")==0) // linux fails with .\ in a path.
							texfile = texfile[2..length];
						meshes[m].material.getLayer(0).addTexture(Resource.texture(path ~ texfile));
					}
					if (cur_material.alphamap[0])
						meshes[m].material.getLayer(0).addTexture(Resource.texture(path ~ cur_material.alphamap));
				}
			}

			// Triangles
			for (int t; t<meshes[m].triangles.length; t++)
			{	//printf( "%d\n", mgroups[m].triangleIndices[t]);
				meshes[m].triangles[t].a = mtriangles[mgroups[m].triangleIndices[t]].vertexIndices[0];
				meshes[m].triangles[t].b = mtriangles[mgroups[m].triangleIndices[t]].vertexIndices[1];
				meshes[m].triangles[t].c = mtriangles[mgroups[m].triangleIndices[t]].vertexIndices[2];

				// Tex coords
				texcoords[meshes[m].triangles[t].a].x = mtriangles[mgroups[m].triangleIndices[t]].s[0];
				texcoords[meshes[m].triangles[t].b].x = mtriangles[mgroups[m].triangleIndices[t]].s[1];
				texcoords[meshes[m].triangles[t].c].x = mtriangles[mgroups[m].triangleIndices[t]].s[2];
				texcoords[meshes[m].triangles[t].a].y = mtriangles[mgroups[m].triangleIndices[t]].t[0];
				texcoords[meshes[m].triangles[t].b].y = mtriangles[mgroups[m].triangleIndices[t]].t[1];
				texcoords[meshes[m].triangles[t].c].y = mtriangles[mgroups[m].triangleIndices[t]].t[2];

				// Normals
				normals[meshes[m].triangles[t].a].x = mtriangles[mgroups[m].triangleIndices[t]].vertexNormals[0];
				normals[meshes[m].triangles[t].a].y = mtriangles[mgroups[m].triangleIndices[t]].vertexNormals[1];
				normals[meshes[m].triangles[t].a].z = mtriangles[mgroups[m].triangleIndices[t]].vertexNormals[2];
				normals[meshes[m].triangles[t].b].x = mtriangles[mgroups[m].triangleIndices[t]].vertexNormals[3];
				normals[meshes[m].triangles[t].b].y = mtriangles[mgroups[m].triangleIndices[t]].vertexNormals[4];
				normals[meshes[m].triangles[t].b].z = mtriangles[mgroups[m].triangleIndices[t]].vertexNormals[5];
				normals[meshes[m].triangles[t].c].x = mtriangles[mgroups[m].triangleIndices[t]].vertexNormals[6];
				normals[meshes[m].triangles[t].c].y = mtriangles[mgroups[m].triangleIndices[t]].vertexNormals[7];
				normals[meshes[m].triangles[t].c].z = mtriangles[mgroups[m].triangleIndices[t]].vertexNormals[8];
			}
		}

		// In the MS3D format, texture coordinate and normal data is stored per triangle, while the vertex
		// position is stored per vertex.  This allows two triangles that reference the same vertex to have
		// different texture and normal coordinates.  This finds such instances, and creates
		// new vertices to correct the problem.
		for (int m; m<meshes.length; m++)
		{	for (int t; t<meshes[m].triangles.length; t++)
			{
				// Index of the triangle we're dealing with.
				int tindex = mgroups[m].triangleIndices[t];

				// Triangle index a
				if ((texcoords[meshes[m].triangles[t].a].x != mtriangles[tindex].s[0]) ||
					(texcoords[meshes[m].triangles[t].a].y != mtriangles[tindex].t[0]))
				{
					// Duplicate vertex from original and copy new texutre and normal coordinates into it.
					vertices.length = texcoords.length = normals.length = vertices.length+1;
					memcpy(&vertices[length-1], &vertices[mtriangles[tindex].vertexIndices[0]], 12);
					memcpy(&normals[length-1], &mtriangles[tindex].vertexNormals[0], 12);
					texcoords[length-1].x = mtriangles[tindex].s[0];
					texcoords[length-1].y = mtriangles[tindex].t[0];
					// Assign this new vertex to the triangle
					meshes[m].triangles[t].a = vertices.length-1;
				}

				// Triangle index b
				if ((texcoords[meshes[m].triangles[t].b].x != mtriangles[tindex].s[1]) ||
					(texcoords[meshes[m].triangles[t].b].y != mtriangles[tindex].t[1]))
				{
					// Duplicate vertex from original and copy new texutre and normal coordinates into it.
					vertices.length = texcoords.length = normals.length = vertices.length+1;
					memcpy(&vertices[length-1], &vertices[mtriangles[tindex].vertexIndices[1]], 12);
					memcpy(&normals[length-1], &mtriangles[tindex].vertexNormals[3], 12);
					texcoords[length-1].x = mtriangles[tindex].s[1];
					texcoords[length-1].y = mtriangles[tindex].t[1];
					// Assign this new vertex to the triangle
					meshes[m].triangles[t].b = vertices.length-1;
				}

				// Triangle index b
				if ((texcoords[meshes[m].triangles[t].c].x != mtriangles[tindex].s[2]) ||
					(texcoords[meshes[m].triangles[t].c].y != mtriangles[tindex].t[2]))
				{
					// Duplicate vertex from original and copy new texutre and normal coordinates into it.
					vertices.length = texcoords.length = normals.length = vertices.length+1;
					memcpy(&vertices[length-1], &vertices[mtriangles[tindex].vertexIndices[2]], 12);
					memcpy(&normals[length-1], &mtriangles[tindex].vertexNormals[6], 12);
					texcoords[length-1].x = mtriangles[tindex].s[2];
					texcoords[length-1].y = mtriangles[tindex].t[2];
					// Assign this new vertex to the triangle
					meshes[m].triangles[t].c = vertices.length-1;
				}
			}

			// Find meshes with material of -1 (no material) and assign them the default material
			if (mgroups[m].materialIndex==-1)
			{	meshes[m].material = new Material();
				meshes[m].material.addLayer(new Layer());	// should be init'd to defaults
			}
		}

		delete mvertices;
		delete mtriangles;
		delete mgroups;
		delete mmaterials;
		delete file;
		delete path;
	}


	/** Print out the vertex, texture, normal, etc. coordinates of a model
	 *  This is useful for debugging purposes. */
	void print()
	{	printf("Model:  '%.*s'\n", source);
		printf("\n%d vertices\n", vertices.length);
		foreach (Vec3f v; vertices)
			printf ("%f, %f, %f\n", v.x, v.y, v.z);
		printf("\n%d texcoords\n", texcoords.length);
		foreach (Vec2f t; texcoords)
			printf ("%f, %f, %f\n", t.x, t.y);
		printf("\n%d normals\n", normals.length);
		foreach (Vec3f n; normals)
			printf ("%f, %f, %f\n", n.x, n.y, n.z);
		foreach (Mesh m; meshes)
		{	printf("\n%d triangles\n", m.triangles.length);
			for (int t=0; t<m.triangles.length; t++)
				printf ("%d, %d, %d\n", m.triangles[t].a, m.triangles[t].b, m.triangles[t].c);
		}
	}


	/** Upload the triangle and vertex data of this model to video memory.
	 *  Vertex buffer objects are used.  I still need to figure out the best
	 *  method to handle bone data */
	void upload()
	{
		if (Device.getSupport(DEVICE_VBO))
		{
			// bind and upload vertices
			glBindBufferARB(GL_ARRAY_BUFFER, vbo_vertices);
			glBufferDataARB(GL_ARRAY_BUFFER, vertices.length*Vec3f.sizeof, vertices.ptr, GL_STATIC_DRAW);

			// bind and upload texture coordinates
			glBindBufferARB(GL_ARRAY_BUFFER, vbo_texcoords);
			glBufferDataARB(GL_ARRAY_BUFFER, texcoords.length*Vec2i.sizeof, texcoords.ptr, GL_STATIC_DRAW);

			// bind and upload normals
			glBindBufferARB(GL_ARRAY_BUFFER, vbo_normals);
			glBufferDataARB(GL_ARRAY_BUFFER, normals.length*Vec3f.sizeof, normals.ptr, GL_STATIC_DRAW);
			glBindBufferARB(GL_ARRAY_BUFFER, 0);	// and set back to default buffer

			// bind and upload the triangle indices
			foreach (Mesh m; meshes)
			{	glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, m.vbo_triangles);
				glBufferDataARB(GL_ELEMENT_ARRAY_BUFFER, m.triangles.length*Vec3i.sizeof, m.triangles.ptr, GL_STATIC_DRAW);
				glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, 0);
			}
			cached = true;
		}
	}
}
