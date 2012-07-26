module yage.resource.graphics.primitives;

import yage.core.all;
import yage.resource.graphics.all;
import yage.scene.scene; // bad!
import yage.scene.light; // bad!

struct RenderCommand
{	
	Matrix transform;
	Geometry geometry;
	Material[] materialOverrides;

	private ubyte lightsLength;
	private LightNode[8] lights; // indices in the RenderList's array of RenderLights

	LightNode[] getLights()
	{	return lights[0..lightsLength];		 	              
	}

	void setLights(LightNode[] lights)
	{	lightsLength = lights.length;
		for (int i=0; i<lights.length; i++)
			this.lights[i] = lights[i];
	}
}

// Everything in a scene seen by the Camera.
struct RenderList
{	Scene scene;
	ArrayBuilder!(RenderCommand) commands;
	ArrayBuilder!(LightNode) lights;
	long timestamp;
	Matrix cameraInverse;
}




/*
* A VertexBuffer wraps around a Geometry attribute, adding a dirty flag and other info. 
* This is only needed inside the engine. */
class VertexBuffer
{
	bool dirty = true;
	void[] data;
	TypeInfo type;
	ubyte components; /// Number of floats for each vertex
	bool cache = true; /// If true the Vertex Buffer will be cached in video memory.  // TODO: Setting this back to false keeps it in video memory but unused.

	/// 
	void setData(T)(T[] data)
	{	dirty = true;
		this.data = data;
		type = typeid(T);
		if (data.length)
			components = data[0].components;
	}

	/// Get the number of vertices for this data.
	int length()
	{	return data.length/type.tsize();		
	}	

	void* ptr()
	{	return data.ptr;
	}
}

