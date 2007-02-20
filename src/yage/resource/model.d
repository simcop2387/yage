/**
 * Copyright:  (c) 2006-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.model;

import std.string;
import std.file;
import std.math;
import std.path;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.vector;

import yage.resource.material;
import yage.resource.mesh;
import yage.resource.resource;
import yage.node.node;
import yage.system.constant;
import yage.system.device;
import yage.system.log;

extern (C) void *memcpy(void *, void *, uint);


/** A Model is a 3D object, typically loaded from a file.
 *  A model contains an array of vertices, texture coordinates, and normals.
 *  Each model is divided into one or more Meshes; each Mesh has its own material
 *  and an array of triangle indices that correspond to vertices in the Model's
 *  vertex array.  ModelNodes can be used to create 3D models in a scene.*/
class Model
{	protected char[]	source;
	protected bool	cached = false;

	public: // for now
	Mesh[]	meshes;
	Vec3f[] vertices;
	Vec3f[] normals;
	Vec2f[]	texcoords;

	protected uint vbo_vertices;	// OpenGL index of hardware vertex array
	protected uint vbo_texcoords;	// OpenGL index of hardware texture coordinate array
	protected uint vbo_normals;		// OpenGL index of hardware normal array

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
		load(filename);
		upload();
	}

	/// Create as an exact duplicate of another Model.
	this (Model model)
	{	this();
		vertices = model.vertices.dup;
		normals = model.normals.dup;
		texcoords = model.texcoords.dup;
		source = model.source.dup;
		foreach (Mesh m; model.getMeshes)
			addMesh(new Mesh(m));
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
	int addMesh(Mesh m)
	{	meshes ~= m;
		return meshes.length-1;
	}

	/// This can only be called before upload()
	int addVertex(Vec3f vert, Vec3f norm, Vec2f tex)
	{	vertices ~= vert;
		normals ~= norm;
		texcoords ~= tex;
		return vertices.length-1;
	}

	/// Bind the Vertex, Texture, and Normal VBO's for use.
	void bind()
	{	// Use the VBO Extension
		if (cached)
		{	glBindBufferARB(GL_ARRAY_BUFFER, getVerticesVBO());
			glVertexPointer(3, GL_FLOAT, 0, null);
			glBindBufferARB(GL_ARRAY_BUFFER, getTexCoordsVBO());
			glTexCoordPointer(2, GL_FLOAT, 0, null);
			glBindBufferARB(GL_ARRAY_BUFFER, getNormalsVBO());
			glNormalPointer(GL_FLOAT, 0, null);
			glBindBufferARB(GL_ARRAY_BUFFER, 0);
		}
		else// Don't cache the model in video memory
		{	glVertexPointer(3, GL_FLOAT, 0, getVertices().ptr);
			glTexCoordPointer(2, GL_FLOAT, 0, getTexCoords().ptr);
			glNormalPointer(GL_FLOAT, 0, getNormals().ptr);
		}
	}

	/// Return true if the model data has been cached in video memory.
	bool getCached()
	{	return cached;
	}

	/// Get the dimensions of a box, centered at the origin, that can contain this Model.
	Vec3f getDimensions()
	{	Vec3f result;
		foreach (Vec3f v; vertices)
		{	if (abs(v.x) > result.x) result.x=v.x;
			if (abs(v.y) > result.y) result.y=v.y;
			if (abs(v.z) > result.z) result.z=v.z;
		}
		return result;
	}

	///
	Mesh getMesh(int index)
	{	return meshes[index];
	}

	/// Get the array of meshes that compose this model.
	Mesh[] getMeshes()
	{	return meshes;
	}

	/// Get the path to the file where the model was loaded.
	char[] getSource()
	{	return source;
	}

	///
	Vec3f[] getNormals()
	{	return normals;
	}

	/// Get the OpenGL Vertex Buffer Object index for the vertex normals.
	uint getNormalsVBO()
	{	return vbo_normals;
	}

	///
	Vec2f[] getTexCoords()
	{	return texcoords;
	}

	/// Get the OpenGL Vertex Buffer Object index for the vertex texture coordinates.
	uint getTexCoordsVBO()
	{	return vbo_texcoords;
	}

	///
	Vec3f[] getVertices()
	{	return vertices;
	}

	/// Get the OpenGL Vertex Buffer Object index for the vertices.
	uint getVerticesVBO()
	{	return vbo_vertices;
	}

	/// Load vertex, mesh, and material data from a 3D model file.
	void load(char[] filename)
	{	char[] ext = getExt(filename);
		switch (tolower(ext))
		{	case "ms3d":
				loadMs3d(filename);
				break;
			default:
				throw new Exception("Unrecognized file format '"~ext~"'.");
		}
	}

	/**
	 * Set the vertices used by this Model.
	 * The triangle arrays of this Model's meshes will index into these arrays.
	 * upload() should be called after this method to update changes in video memory.
	 * Params:
	 * verts = vertex coordinate vectors (xyz).
	 * norms = normal coordinate vectors; need to be of length 1.
	 * texs = texure coordinates for each vertex. */
	void setVertices(Vec3f[] vertices, Vec3f[] normals, Vec2f[] texcoords)
	in
	{	assert(vertices.length==normals.length && vertices.length==texcoords.length); }
	body
	{	this.vertices = vertices;
		this.normals = normals;
		this.texcoords = texcoords;
	}

	/**
	 * Set the Meshes used by this model. */
	void setMeshes(Mesh[] meshes)
	{	this.meshes = meshes;
	}

	/**
	 * Return a string representation of this Model and all of its data. */
	char[] toString()
	{	char[] result;
		result ~= "Model:  '"~source~"'\n";

		result ~= .toString(vertices.length)~" vertices\n";
		foreach (Vec3f v; vertices)
			result ~= v.toString();
/*
		result ~= .toString(texcoords.length)~" texcoords\n";
		foreach (Vec2f t; texcoords)
			result ~= t.toString();

		result ~= .toString(normals.length)~" normals\n";
		foreach (Vec3f n; normals)
			result ~= n.toString();

		result ~= .toString(meshes.length)~" meshes\n";
		foreach (Mesh m; meshes)
			result ~= m.toString();
*/
		return result;
	}



	/*
	 * Upload the triangle and vertex data of this model to video memory.
	 * Vertex buffer objects are used.  I still need to figure out the best
	 * method to handle bone data */
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

			// bind and upload the triangle indices
			foreach (Mesh m; meshes)
			{	glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, m.getTrianglesVBO());
				glBufferDataARB(GL_ELEMENT_ARRAY_BUFFER, m.getTriangles().length*Vec3i.sizeof, m.getTriangles().ptr, GL_STATIC_DRAW);
			}

			// and set back to default buffers
			glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, 0);
			glBindBufferARB(GL_ARRAY_BUFFER, 0);

			cached = true;
		}
	}

	/*
	 * Load a model from a Milkshape3D model file.
	 * All materials, etc. referenced by this model are loaded through the Resource
	 * manager to avoid duplicates.  Meshes without a material are assigned a default material.
	 * Uploading vertex data to video memory must be done manually by calling Upload().
	 * This function needs to be tested on big-endian systems. */
	private void loadMs3d(char[] filename)
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
		//calcRadius();

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
					meshes[m].setMaterial(path~name);
				else // create new material
				{	Material matl = new Material();
					matl.addLayer(new Layer());

					mMaterial *cur_material = &mmaterials[mgroups[m].materialIndex];

					memcpy(&matl.getLayers()[0].ambient, cur_material.ambient.ptr, 16);
					memcpy(&matl.getLayers()[0].diffuse, cur_material.diffuse.ptr, 16);
					memcpy(&matl.getLayers()[0].specular, cur_material.specular.ptr, 16);
					memcpy(&matl.getLayers()[0].emissive, cur_material.emissive.ptr, 16);
					matl.getLayers()[0].specularity = cur_material.shininess;
					meshes[m].setMaterial(matl);

					// Load textures
					// Ms3d stores a texture map and an alpha map for every material
					char[] texfile = .toString(cur_material.texture.ptr);
					if (texfile.length)
					{	if (icmp(texfile[0..2], ".\\")==0) // linux fails with .\ in a path.
							texfile = texfile[2..length];
						meshes[m].getMaterial().getLayers()[0].addTexture(Resource.texture(path ~ texfile));
					}
					if (cur_material.alphamap[0])
						meshes[m].getMaterial().getLayers()[0].addTexture(Resource.texture(path ~ cur_material.alphamap));
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
			{	meshes[m].setMaterial(new Material());
				meshes[m].getMaterial().addLayer(new Layer());	// should be init'd to defaults
			}
		}

		delete mvertices;
		delete mtriangles;
		delete mgroups;
		delete mmaterials;
		delete file;
		delete path;
	}
}
