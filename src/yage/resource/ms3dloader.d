/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:	Eric Poggel
 * License:	<a href="lgpl.txt">LGPL</a>
 */

module yage.resource.ms3dloader;

import std.string;
import std.file;
import std.path;
import std.stdio;
import yage.core.all;
import yage.core.types;
import yage.core.color;
import yage.resource.all;
import yage.resource.exception;
import yage.system.log;

import std.c.string : memcpy;

/**
 * An in-memory representation of a Milkshape3D model.
 * This is used as an intermediate step in loading such a model into
 * Yage's own internal Model format. */
private struct MS3D
{
	// Ms3d Data structures.  See the Ms3D SDK for details.
	// Ms3d Vertices
	
	// Warning, see: http://www.digitalmars.com/d/1.0/garbage.html
	// Do not misalign pointers if those pointers may point into the gc heap
	
	struct Vertex
	{	align(1) byte		flags;			// SELECTED | SELECTED2 | HIDDEN
		align(1) float[3]	vertex;
		align(1) byte		boneId;			// -1 = no bone
		align(1) byte		referenceCount;
	}
	// Ms3d Triangles
	struct Triangle
	{	align(1) ushort		flags;			// SELECTED | SELECTED2 | HIDDEN
		align(1) ushort[3]	vertexIndices;
		align(1) float[9]	vertexNormals;
		align(1) float[3]	s;
		align(1) float[3]	t;
		align(1) byte		smoothingGroup;	// 1 - 32
		align(1) ubyte		groupIndex;
	}
	// Ms3d Groups
	struct Group
	{	align(1) ubyte		flags;			// SELECTED | HIDDEN
		align(1) char[32]	name;
		align(1) ushort		numtriangles;
		align(1) byte		materialIndex;	// -1 = no material (moved here for proper alignment)
		align(1) ushort[]	triangleIndices;// the groups group the triangles
	}
	//Ms3d Material
	struct Material
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
	
	struct KeyframeRotation
	{	align(1) float				time;			// time in seconds
		align(1) float[3]			rotation;		// x, y, z angles
	}

	struct KeyframePosition
	{	align(1) float				time;			// time in seconds
		align(1) float[3]			position;		// local position
	}

	struct Joint
	{	align(1) byte				flags;			// SELECTED | DIRTY
		align(1) char[32]			name;
		align(1) char[32]			parentName;
		align(1) float[3]			rotation;		// local reference matrix
		align(1) float[3]			position;
		align(1) short				numKeyFramesRot;
		align(1) short				numKeyFramesTrans;
		KeyframeRotation[] keyFramesRot;	// local animation matrices
		KeyframePosition[] keyFramesTrans;	// local animation matrices
		Joint* parent;	// not part of the original data, but useful for rebuilding relationships. 
	}

	Vertex[]	vertices;
	Triangle[]	triangles;
	Group[]		groups;
	Material[]	materials;
	Joint[]		joints;
	
	float fps;

	/**
	 * Load a Milkshape 3D model into this struct. */
	void load(char[] filename)
	{
		ushort 		size;		// used repeatedly as temporary size variable.
		uint 		idx=16; 	// current index in the file array.  The first loop starts at 16.
		ubyte[]		file = cast(ubyte[])read(filename);

		// Check for Ms3d header
		if (icmp("MS3D000000", cast(char[])file[0..10])!=0)
			throw new Exception("This file does not have a valid MS3D header.");

		// Check Ms3d version (3 or 4 only)
		if (file[10] <3 || file[10] > 4)
			throw new Exception("Milkshape file format version " ~ .toString(file[10]) ~ " not supported.");

		// Vertices
		memcpy(&size, &file[14], 2);
		vertices.length = size;
		for (int v=0; v<size; v++)
		{	memcpy(&vertices[v], &file[idx], 15);
			idx+=15;
		}

		// Triangles and normals
		memcpy(&size, &file[idx], 2);
		triangles.length = size;
		idx+=2;
		for (int t=0; t<size; t++)
		{	memcpy(&triangles[t], &file[idx], 70);
			idx+=70;
		}

		// Groups (aka Meshes)
		memcpy(&size, &file[idx], 2);
		groups.length = size;
		idx+=2;
		for (int g=0; g<size; g++)
		{	// get number of triangles
			memcpy(&groups[g], &file[idx], 35);
			groups[g].triangleIndices.length = groups[g].numtriangles;
			// now copy the triangles into the mesh struct
			memcpy(&groups[g].triangleIndices[0], &file[idx+35], groups[g].numtriangles*2);
			memcpy(&groups[g].materialIndex, &file[idx+35+groups[g].numtriangles*2], 1);
			idx+=(36+groups[g].numtriangles*2);
		}

		// Materials
		memcpy(&size, &file[idx], 2);
		materials.length = size;
		idx+=2;
		for (int m=0; m<size; m++)
		{	memcpy(&materials[m], &file[idx], 361);
			idx+=361;
		}
		
		// Joints
		memcpy(&fps, &file[idx], 4);		
		idx += 12; // skip float fCurrentTime, int iTotalFrames
		memcpy(&size, &file[idx], 2);
		joints.length = size;
		idx += 2;
		
		// Loop thorugh joints
		for (int i=0; i<size; i++)
		{	memcpy(&joints[i], &file[idx], 93);
			idx += 93;
			joints[i].keyFramesRot.length = joints[i].numKeyFramesRot;
			joints[i].keyFramesTrans.length = joints[i].numKeyFramesTrans;
			
			// Loop through rotation and position keyframes for this joint.
			for (int j=0; j<joints[i].keyFramesRot.length; j++)
			{	memcpy(&joints[i].keyFramesRot[j], &file[idx], 16);
				idx += 16;
			}
			
			for (int j=0; j<joints[i].keyFramesTrans.length; j++)
			{	memcpy(&joints[i].keyFramesTrans[j], &file[idx], 16);
				idx += 16;
			}			
		}
		//delete file;
	}
}



/**
 * Create Models from files and other sources.
 * This is separated and used as a mixin to reduce the length of model.d.*/
template Ms3dLoader()
{
	/**
	 * Load a model from a Milkshape3D model file.
	 * All materials, etc. referenced by this model are loaded through the Resource
	 * manager to avoid duplicates.  Meshes without a material are assigned a default material.
	 * Uploading vertex data to video memory must be done manually by calling Upload(). */
	protected void loadMs3d(char[] filename)
	{
		source = Resource.resolvePath(filename);
		char[] path = source[0 .. rfind(source, "/") + 1]; // path stripped of filename

		// Load the Ms3d model into the MS3D struct.
		// After that, we translate the MS3D struct to Yage's internal model format.
		MS3D ms3d;
		ms3d.load(source);
		
		Vec3f[] vertices, normals;
		Vec2f[] texcoords;
		
		
		// Vertices
		vertices.length  = ms3d.vertices.length;
		texcoords.length = ms3d.vertices.length;
		normals.length   = ms3d.vertices.length;
		joint_indices.length= ms3d.vertices.length;

		for (int v; v<ms3d.vertices.length; v++)
		{	vertices[v].x = ms3d.vertices[v].vertex[0];
			vertices[v].y = ms3d.vertices[v].vertex[1];
			vertices[v].z = ms3d.vertices[v].vertex[2];
			joint_indices[v] = ms3d.vertices[v].boneId;
		}

		// Meshes
		meshes.length = ms3d.groups.length;
		for (int m; m<meshes.length; m++)
		{	meshes[m] = new Mesh();
			Vec3i[] triangles = meshes[m].getTriangles();
			triangles.length = ms3d.groups[m].numtriangles;
			
			// Material
			if (ms3d.groups[m].materialIndex != -1)
			{	
				// Load xml material file from mesh's name, if it's an xml file.
				char[] name = .toString(ms3d.materials[ms3d.groups[m].materialIndex].name.ptr);
				if (name.length>4 && name[length-4..length]==".xml" && exists(path~name))
					meshes[m].setMaterial(path~name);
				else // load ms3d material
				{	Material matl = new Material();
					matl.addLayer(new Layer());

					int midx = ms3d.groups[m].materialIndex;
					matl.getLayers()[0].ambient = yage.core.color.Color(ms3d.materials[midx].ambient);					
					matl.getLayers()[0].diffuse = yage.core.color.Color(ms3d.materials[midx].diffuse);
					matl.getLayers()[0].specular = yage.core.color.Color(ms3d.materials[midx].specular);
					matl.getLayers()[0].emissive = yage.core.color.Color(ms3d.materials[midx].emissive);
					
					matl.getLayers()[0].specularity = ms3d.materials[midx].shininess;
					meshes[m].setMaterial(matl);

					// Load textures
					// Ms3d stores a texture map and an alpha map for every material
					char[] texfile = .toString(ms3d.materials[midx].texture.ptr);
					if (texfile.length)
					{	if (icmp(texfile[0..2], ".\\")==0) // linux fails with .\ in a path.
							texfile = texfile[2..length];
						meshes[m].getMaterial().getLayers()[0].addTexture(Resource.texture(path ~ texfile));
					}
					if (ms3d.materials[midx].alphamap[0])
						meshes[m].getMaterial().getLayers()[0].addTexture(Resource.texture(path ~ ms3d.materials[midx].alphamap));
				}
			}
			
			// Triangles
			for (int t; t<triangles.length; t++)
			{	//printf( "%d\n", ms3d.groups[m].triangleIndices[t]);
				triangles[t].x = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].vertexIndices[0];
				triangles[t].y = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].vertexIndices[1];
				triangles[t].z = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].vertexIndices[2];

				// Tex coords
				texcoords[triangles[t].x].x = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].s[0];
				texcoords[triangles[t].y].x = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].s[1];
				texcoords[triangles[t].z].x = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].s[2];
				texcoords[triangles[t].x].y = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].t[0];
				texcoords[triangles[t].y].y = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].t[1];
				texcoords[triangles[t].z].y = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].t[2];

				// Normals
				normals[triangles[t].x].x = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].vertexNormals[0];
				normals[triangles[t].x].y = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].vertexNormals[1];
				normals[triangles[t].x].z = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].vertexNormals[2];
				normals[triangles[t].y].x = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].vertexNormals[3];
				normals[triangles[t].y].y = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].vertexNormals[4];
				normals[triangles[t].y].z = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].vertexNormals[5];
				normals[triangles[t].z].x = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].vertexNormals[6];
				normals[triangles[t].z].y = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].vertexNormals[7];
				normals[triangles[t].z].z = ms3d.triangles[ms3d.groups[m].triangleIndices[t]].vertexNormals[8];
			}
			
			// In the MS3D format, texture coordinate and normal data is stored per triangle, while the vertex
			// position is stored per vertex.  This allows two triangles that reference the same vertex to have
			// different texture and normal coordinates, but is incompatible with the OpenGL vertex format.  
			// This loop finds such instances, and creates new vertices to correct the problem.
			for (int t; t<triangles.length; t++)
			{
				// Index of the triangle we're dealing with.
				int tindex = ms3d.groups[m].triangleIndices[t];

				// Triangle index a
				if ((texcoords[triangles[t].x].x != ms3d.triangles[tindex].s[0]) ||
					(texcoords[triangles[t].x].y != ms3d.triangles[tindex].t[0]))
				{
					// Duplicate vertex from original and copy new texutre and normal coordinates into it.
					vertices.length = texcoords.length = normals.length = vertices.length+1;
					vertices[length-1] = vertices[ms3d.triangles[tindex].vertexIndices[0]];
					memcpy(&normals[length-1], &ms3d.triangles[tindex].vertexNormals[0], 12);
					texcoords[length-1].x = ms3d.triangles[tindex].s[0];
					texcoords[length-1].y = ms3d.triangles[tindex].t[0];
					// Assign this new vertex to the triangle
					triangles[t].x = vertices.length-1;
				}

				// Triangle index b
				if ((texcoords[triangles[t].y].x != ms3d.triangles[tindex].s[1]) ||
					(texcoords[triangles[t].y].y != ms3d.triangles[tindex].t[1]))
				{
					// Duplicate vertex from original and copy new texutre and normal coordinates into it.
					vertices.length = texcoords.length = normals.length = vertices.length+1;
					vertices[length-1] = vertices[ms3d.triangles[tindex].vertexIndices[1]];
					memcpy(&normals[length-1], &ms3d.triangles[tindex].vertexNormals[3], 12);
					texcoords[length-1].x = ms3d.triangles[tindex].s[1];
					texcoords[length-1].y = ms3d.triangles[tindex].t[1];
					// Assign this new vertex to the triangle
					triangles[t].y = vertices.length-1;
				}

				// Triangle index b
				if ((texcoords[triangles[t].z].x != ms3d.triangles[tindex].s[2]) ||
					(texcoords[triangles[t].z].y != ms3d.triangles[tindex].t[2]))
				{
					// Duplicate vertex from original and copy new texutre and normal coordinates into it.
					vertices.length = texcoords.length = normals.length = vertices.length+1;
					vertices[length-1] = vertices[ms3d.triangles[tindex].vertexIndices[2]];
					memcpy(&normals[length-1], &ms3d.triangles[tindex].vertexNormals[6], 12);
					texcoords[length-1].x = ms3d.triangles[tindex].s[2];
					texcoords[length-1].y = ms3d.triangles[tindex].t[2];
					// Assign this new vertex to the triangle
					triangles[t].z = vertices.length-1;
				}
			}

			// Find meshes with material of -1 (no material) and assign them the default material
			if (ms3d.groups[m].materialIndex==-1)
			{	meshes[m].setMaterial(new Material());
				meshes[m].getMaterial().addLayer(new Layer());	// should be init'd to defaults
			}
			meshes[m].setTriangles(triangles);
		}
	
		// Joints			
		joints.length = ms3d.joints.length;
		for (int j=0; j<ms3d.joints.length; j++)
		{	joints[j] = new Joint();
			joints[j].name = .toString(ms3d.joints[j].name.ptr);
			joints[j].parentName = .toString(ms3d.joints[j].parentName.ptr);
			joints[j].startPosition.v[0..3] = ms3d.joints[j].position[0..3];
			joints[j].startRotation.v[0..3] = ms3d.joints[j].rotation[0..3];

			joints[j].positions.length = ms3d.joints[j].keyFramesTrans.length;
			joints[j].rotations.length = ms3d.joints[j].keyFramesRot.length;				
			for (int k=0; k<joints[j].positions.length; k++)
			{	joints[j].positions[k].time = ms3d.joints[j].keyFramesTrans[k].time;
				joints[j].positions[k].value.v[0..3] = ms3d.joints[j].keyFramesTrans[k].position[0..3];
				if (joints[j].positions[k].time > max_time)
					max_time = joints[j].positions[k].time;
			}
			for (int k=0; k<joints[j].rotations.length; k++)
			{	joints[j].rotations[k].time = ms3d.joints[j].keyFramesRot[k].time;
				joints[j].rotations[k].value.v[0..3] = ms3d.joints[j].keyFramesRot[k].rotation[0..3];
				if (joints[j].rotations[k].time > max_time)
					max_time = joints[j].rotations[k].time;
			}
		}
		
		// Link joint parent relationships.
		for (int j=0; j<joints.length; j++)
		{	Joint current = joints[j];			
			if (current.parentName.length) // if parent name
			{	for (int t=0; t<joints.length; t++)
				{	if (joints[t].name == current.parentName)
					{	current.parent = joints[t];
						break;
				}	}			
				if (!current.parent)
					throw new ResourceLoadException("Unable to link bone " ~ .toString(j) ~ " of model " ~ filename ~ "!");
		}	}
		
		// Joint children relationshps
		foreach (j; joints)			
			if (j.parent)
				j.parent.children ~= j;			
		
		if (joints.length)
		{	
			// Sets up each joint's transformation matrices
			foreach(joint; joints)
			{	
				// create transformation matrix from position and rotation
				joint.transform = Matrix();
				joint.transform.setEuler(joint.startRotation);
				joint.transform.setPosition(joint.startPosition);

				if (!joint.parent)
					joint.transformAbs = joint.transform;				
				else
					joint.transformAbs = joint.transform * joint.parent.transformAbs;
			}

			// Inverse transform each vertex and inverse rotate each normal by the joint's Matrix.
			for (int i; i<vertices.length; i++)
			{	if ( joint_indices[i] != -1 )
				{	Matrix matrix = joints[joint_indices[i]].transformAbs;
					vertices[i] = vertices[i].inverseTransform(matrix);			
			}	}
		}	
				
		setAttribute("gl_Vertex", vertices);
		setAttribute("gl_TexCoord", texcoords);
		setAttribute("gl_Normal", normals);
		setAttribute("gl_VertexOriginal", vertices.dup); // a copy of these
		setAttribute("gl_NormalOriginal", vertices.dup); // is required for skeletal animation.
	}
}


/*///
Vec4f[] calcTangents()
{
	Vec3f[] tan1 = new Vec3f[vertices.length];
	Vec3f[] tan2 = new Vec3f[vertices.length];

	Vec4f[] result = new Vec4f[vertices.length];

	foreach (m; meshes)
	{	foreach (t; m.triangles)
		{
			int i1 = t.x;
			int i2 = t.y;
			int i3 = t.z;

			Vec3f v1 = vertices[i1];
			Vec3f v2 = vertices[i2];
			Vec3f v3 = vertices[i3];

			Vec2f w1 = texcoords[i1];
			Vec2f w2 = texcoords[i2];
			Vec2f w3 = texcoords[i3];

			//Vec2f x = Vec2f(v2.x-v1.x, v3.x-v1.x);
			//Vec2f y = Vec2f(v2.y-v1.y, v3.y-v1.y);
			//Vec2f z = Vec2f(v2.z-v1.z, v3.z-v1.z);

			float x1 = v2.x-v1.x;
			float x2 = v3.x-v1.x;
			float y1 = v2.y-v1.y;
			float y2 = v3.y-v1.y;
			float z1 = v2.z-v1.z;
			float z2 = v3.z-v1.z;

			float s1 = w2.x-w1.x;
			float s2 = w3.x-w1.x;
			float t1 = w2.y-w1.y;
			float t2 = w3.y-w1.y;

			float r = 1.0f / (s1*t2 - s2*t1);
			Vec3f sdir = Vec3f((t2*x1 - t1*x2)*r, (t2*y1 - t1*y2)*r, (t2*z1 - t1*z2)*r);
			Vec3f tdir = Vec3f((s1*x2 - s2*x1)*r, (s1*y2 - s2*y1)*r, (s1*z2 - s2*z1)*r);

			tan1[i1] += sdir;
			tan1[i2] += sdir;
			tan1[i3] += sdir;

			tan2[i1] += tdir;
			tan2[i2] += tdir;
			tan2[i3] += tdir;
		}
	}

	for (int a=0; a<vertices.length; a++)
	{
		Vec3f n = normals[a];
		Vec3f t = tan1[a];

		// Gram-Schmidt orthogonalize
		Vec3f temp = (t-n * n.dot(t)).normalize();
		result[a].v[0..3] = temp.v[0..3];

		// Calculate handedness
		result[a].w = (n.cross(t).dot(tan2[a]) < 0.0f) ? -1.0f : 1.0f;
	}

	delete tan1;
	delete tan2;

	//result[0..length] = Vec4f(1, 0, 1, 1);
	//setAttribute("tangent", result);
	return result;
}
*/