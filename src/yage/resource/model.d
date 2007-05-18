/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.model;

import std.string;
import std.file;
import std.math;
import std.path;
import std.stdio;
import derelict.opengl.gl;
import derelict.opengl.glext;
import yage.core.matrix;
import yage.core.misc;
import yage.core.vector;

import yage.resource.material;
import yage.resource.mesh;
import yage.resource.resource;
import yage.resource.modelloader;
import yage.node.node;
import yage.system.constant;
import yage.system.device;
import yage.system.log;



/**
 * A Model is a 3D object, typically loaded from a file.
 * A model contains an array of vertices, texture coordinates, and normal vectors.
 * Each model is divided into one or more Meshes; each Mesh has its own material
 * and an array of triangle indices that correspond to vertices in the Model's
 * vertex array.  ModelNodes can be used to create 3D models in a scene.*/
class Model
{	protected char[] source;
	protected bool	cached = false;// False if any vertex attributes are not cached in video memory

	public: // for now
	Mesh[]	meshes;
	Vec3f[] vertices;
	Vec3f[] normals;
	Vec2f[]	texcoords;

	struct Attribute
	{	float[] values;
		uint vbo = 0;
		// bool cached = false;
	}
	protected Attribute[char[]] attributes;	// An associative array to store as many attributes as necessary

	protected uint vbo_vertices;	// OpenGL index of hardware vertex array
	protected uint vbo_texcoords;	// OpenGL index of hardware texture coordinate array
	protected uint vbo_normals;		// OpenGL index of hardware normal array
	protected uint vbo_tangents;	//

	mixin ModelLoader;


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
	{	if (!cached)
			finalize();

		// Use the VBO Extension
		if (cached)
		{	glBindBufferARB(GL_ARRAY_BUFFER_ARB, getVerticesVBO());
			glVertexPointer(3, GL_FLOAT, 0, null);
			glBindBufferARB(GL_ARRAY_BUFFER_ARB, getTexCoordsVBO());
			glTexCoordPointer(2, GL_FLOAT, 0, null);
			glBindBufferARB(GL_ARRAY_BUFFER_ARB, getNormalsVBO());
			glNormalPointer(GL_FLOAT, 0, null);
			//glBindBufferARB(GL_ARRAY_BUFFER, 0);

		}
		else// Don't cache the model in video memory
		{	glVertexPointer(3, GL_FLOAT, 0, getVertices().ptr);
			glTexCoordPointer(2, GL_FLOAT, 0, getTexCoords().ptr);
			glNormalPointer(GL_FLOAT, 0, getNormals().ptr);
		}
	}

	/*
	 * Upload the triangle and vertex data of this model to video memory.
	 * Vertex buffer objects are used.  I still need to figure out the best
	 * method to handle bone data */
	void finalize()
	{	//writefln("finalizing %s", source);
		if (Device.getSupport(DEVICE_VBO))
		{
			// bind and upload vertices
			glBindBufferARB(GL_ARRAY_BUFFER_ARB, vbo_vertices);
			glBufferDataARB(GL_ARRAY_BUFFER_ARB, vertices.length*Vec3f.sizeof, vertices.ptr, GL_STATIC_DRAW);

			// bind and upload texture coordinates
			glBindBufferARB(GL_ARRAY_BUFFER_ARB, vbo_texcoords);
			glBufferDataARB(GL_ARRAY_BUFFER_ARB, texcoords.length*Vec2i.sizeof, texcoords.ptr, GL_STATIC_DRAW);

			// bind and upload normals
			glBindBufferARB(GL_ARRAY_BUFFER_ARB, vbo_normals);
			glBufferDataARB(GL_ARRAY_BUFFER_ARB, normals.length*Vec3f.sizeof, normals.ptr, GL_STATIC_DRAW);

			foreach (name, inout attrib; attributes)
			{	if (attrib.vbo == 0)
					glGenBuffers(1, &attrib.vbo); // todo: cleanup!
				glBindBuffer(GL_ARRAY_BUFFER_ARB, attrib.vbo);
				//writefln(attrib.values.length);
				glBufferData(GL_ARRAY_BUFFER_ARB, attrib.values.length, attrib.values.ptr, GL_STATIC_DRAW);
			}

			// bind and upload the triangle indices
			foreach (Mesh m; meshes)
			{	glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, m.getTrianglesVBO());
				glBufferDataARB(GL_ELEMENT_ARRAY_BUFFER, m.getTriangles().length*Vec3i.sizeof, m.getTriangles().ptr, GL_STATIC_DRAW);
			}

			// and set back to default buffers
			glBindBufferARB(GL_ELEMENT_ARRAY_BUFFER, 0);
			glBindBufferARB(GL_ARRAY_BUFFER_ARB, 0);

			cached = true;
		}
	}

	/// Get an associative array of all attributes.  The index is the attribute name.
	Attribute[char[]] getAttributes()
	{	return attributes;
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

	/// Get the array of meshes that compose this model.
	Mesh[] getMeshes()
	{	return meshes;
	}

	///
	Vec3f[] getNormals()
	{	return normals;
	}

	/// Get the OpenGL Vertex Buffer Object index for the vertex normals.
	uint getNormalsVBO()
	{	return vbo_normals;
	}

	/// Get the path to the file where the model was loaded.
	char[] getSource()
	{	return source;
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
	 * Set a per-vertex attribute for this Model.
	 * Attributes can be accessed by OpenGl vertex shaders.
	 * If an attribute is defined for this model, and a mesh of this model has
	 * a material with a shader that has an attribute variable of the same name,
	 * the values of the attribute will be bound automaticallyat runtime and can
	 * then be accessed by the shader.
	 * Params:
	 * name = the name of the attribute, should be the same as the attribute
	 * variable name in the vertex shader.
	 * values = an array of values; should be the same length as the number of
	 * vertices for the model.*/
	void setAttribute(char[] name, float[] values)
	{	setAttribute(name, values, 1);
	}

	/// ditto
	void setAttribute(char[] name, Vec2f[] values)
	{	float[] arg = (cast(float*)&values[0].v)[0..values.length*2];
		setAttribute(name, arg, 2);
	}

	/// ditto
	void setAttribute(char[] name, Vec3f[] values)
	{	float[] arg = (cast(float*)&values[0].v)[0..values.length*3];
		setAttribute(name, arg, 3);
	}

	/// ditto
	void setAttribute(char[] name, Vec4f[] values)
	{	float[] arg = (cast(float*)&values[0].v)[0..values.length*4];
		setAttribute(name, arg, 4);
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
			result ~= m.toString();*/
		return result;
	}

	///
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

	/// Clear an attribute.
	void unsetAttribute(char[] name)
	{	if (name in attributes)
			attributes.remove(name);
	}

	// Used by the other setAttribute functions.
	private void setAttribute(char[] name, float[] values, int size)
	{	if (values.length/size < vertices.length)
			throw new Exception("Cannot set attribute '"~name~"' for model '"~source~
				"'.  Values array must be at least the length of the vertex array.");
		//attributes[name].values.length = size*vertices.length;
		Attribute a;
		attributes[name] = a;
		attributes[name].values = values;
		cached = false;
	}
}
