/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Joe Pusderis (deformative0@gmail.com)
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.objloader;

import std.string;
import std.file;
import std.path;
import std.stdio;
import std.string;
import std.conv;

import yage.core.types;
import yage.core.matrix;
import yage.core.misc;
import yage.core.vector;
import yage.system.constant;
import yage.resource.model;
import yage.resource.material;
import yage.resource.mesh;
import yage.resource.manager;
import yage.resource.texture;
import yage.system.log;

union point{
	int[3] array;
	struct{
		int vertex;
		int texcoord;
		int normal;
	}
	Vec3i vec;
}

alias char[][] face;

struct MTL{
	char[] name;
	//Ka
	float[4] ambient = [.2,.2,.2,1.0]; //color
	//Kd and d
	float[4] diffuse = [.8,.8,.8,1.0]; //color
	//Ks
	float[4] specular = [1.0,1.0,1.0,1.0]; //color
	//Ns
	float shininess = 0.0;
	//map_Ka
	char[] texture;
}

MTL[] handleMTL(char[] source){
	char[] file = cast(char[])read(source);
	char[][] lines = splitlines(file);
	
	MTL[] mats;
	
	void handleLine(char[] line){
		char[][] words = split(line, " ");
		if(words.length != 0){
			switch(words[0]){
				case "newmtl":
					MTL m;
					m.name = line[7..$];
					mats ~= m;
					break;
				case "Ka":
					Vec3f rgb = fromWords3(words);
					mats[$-1].ambient[0] = rgb.x;
					mats[$-1].ambient[1] = rgb.y;
					mats[$-1].ambient[2] = rgb.z;
					break;
				case "Kd":
					Vec3f rgb = fromWords3(words);
					mats[$-1].diffuse[0] = rgb.x;
					mats[$-1].diffuse[1] = rgb.y;
					mats[$-1].diffuse[2] = rgb.z;
					break;
				case "Ks":
					Vec3f rgb = fromWords3(words);
					mats[$-1].specular[0] = rgb.x;
					mats[$-1].specular[1] = rgb.y;
					mats[$-1].specular[2] = rgb.z;
					break;
				case "Tr":
				case "d":
					//mats[$-1].diffuse[3] = toFloat(words[1]);  //FIX!
					break;
				case "Ns":
					mats[$-1].shininess = toFloat(words[1]);
					break;
				case "map_Ka":
					mats[$-1].texture = words[1];
					break;
				case "illum":
					break;
				default:
					break;
			}
		}
	}
	
	foreach(inout line; lines){
		line = strip(line);
		handleLine(line);
	}
	
	return mats;
}

struct group{
	MTL mtl;
	point[char[]] points;//used to test if point already exists
	//char[] == lazy man's point reference
	face[] faces; //array of char[] is face, array of faces
	
	void addPoint(char[] word){
		if(!(word in points)){
			point p;
			foreach(int index, inout part; split(word, "/")){
				if(part.length != 0)
					p.array[index] = std.conv.toInt(part);
			}
			
			points[word] = p;
		}
	}
	
	void addFace(char[][] words){
		for(int i = 1; i < words.length; i++){
			addPoint(words[i]);
		}
		faces ~= words[1..$];
	}
}

struct OBJ{
	group[] groups;
	
	MTL[char[]] materials;
	
	Vec3f[] vertices, normals;
	Vec2f[] texcoords;
	
	char[] file;
	
	char[] path;//path without filename, move out of struct
	
	void load(char[] source){
		path = source[0 .. rfind(source, "/") + 1]; // path stripped of filename
		
		file = cast(char[])read(source);
		char[][] lines = splitlines(file);
		
		groups.length = 1;
		
		foreach(inout line; lines){
			line = strip(line);
			handleLine(line);
		}
	}
	
	void handleLine(char[] line){
		char[][] words = split(line, " ");
		if(words.length != 0){
			switch(words[0]){
				//Vertex data
				case "v":
					//does not support weight
					vertices ~=  fromWords3(words);
					break;
				case "vt":
					//does not support weight
					texcoords ~=  fromWords2(words);
					break;
				case "vn":
					normals ~=  fromWords3(words);
					break;
				case "vp":
					break;
				case "cstype":
					break;
				case "deg":
					break;
				case "bmat":
					break;
				case "step":
					break;
				//Elements
				case "p":
					break;
				case "l":
					break;
				case "f":
					groups[$-1].addFace(words);
					break;
				case "curv":
					break;
				case "curv2":
					break;
				case "surf":
					break;
				//Free-form curve/surface body statements
				case "parm":
					break;
				case "trim":
					break;
				case "hole":
					break;
				case "scrv":
					break;
				case "sp":
					break;
				case "end":
					break;
				//Connectivity between free-form surfaces
				case "con":
					break;
				//Grouping
				case "g":
					group g;
					groups ~= g;
					break;
				case "s":
					break;
				case "mg":
					break;
				case "o":
					break;
				//Display/render attributes
				case "bevel":
					break;
				case "c_interp":
					break;
				case "d_interp":
					break;
				case "lod":
					break;
				case "usemtl":
					groups[$-1].mtl = materials[line[7..$]];
					break;
				case "mtllib":
					foreach(word; words[1..$]){
						MTL[] mats = handleMTL(path ~ word);
						foreach(m; mats)
							materials[m.name] = m;
					}
					break;
				case "shadow_obj":
					break;
				case "trace_obj":
					break;
				case "ctech":
					break;	
				case "stech":
					break;
				default:
					break;
			}
		}
	}
}

//Do not want to make a template or making 2/3 an arg for only two functions
Vec3f fromWords3(char[][] words){
	Vec3f vertex;
	for(int i; i < 3; i++)
		vertex[i] = std.conv.toFloat(words[i+1]);
	return vertex;
}
	
Vec2f fromWords2(char[][] words){
	Vec2f vertex;
	for(int i; i < 2; i++)
		vertex[i] = std.conv.toFloat(words[i+1]);
	return vertex;
}

/**
 * Create Models from files and other sources.
 * This is separated and used as a mixin to reduce the length of model.d.*/
template ObjLoader(){

	/**
	 * Load a model from a Wavefront obj file.
	 * All materials, etc. referenced by this model are loaded through the ResourceManager
	 * manager to avoid duplicates.  Meshes without a material are assigned a default material.*/
	protected void loadObj(char[] filename){
		Vec3f[] vertices, normals;
		Vec2f[] texcoords;
		
		source = ResourceManager.resolvePath(filename);
		
		OBJ obj;
		obj.load(source);
		
		foreach(inout g; obj.groups[1..$]){ //makes new vertices for different normals or tex
			foreach(inout p; g.points){
				vertices ~= obj.vertices[p.vertex - 1];
				p.vertex = vertices.length - 1;
				
				if(p.normal == 0)
					normals.length = normals.length + 1;
				else{
					normals ~= obj.normals[p.normal - 1];
					p.normal = normals.length - 1;
				}
				
				if(p.texcoord == 0)
					texcoords.length = texcoords.length + 1;
				else{
					texcoords ~= obj.texcoords[p.texcoord -1];
					p.texcoord = texcoords.length - 1;
				}
			}
			
			// Meshes
			meshes ~= new Mesh();
			int m = meshes.length - 1;
				
			Material matl = new Material();
			matl.addLayer(new Layer());
			
			//matl.getLayers[0].blend = BLEND_AVERAGE; //FIX!

			matl.getLayers()[0].ambient = yage.core.color.Color(g.mtl.ambient);
			matl.getLayers()[0].diffuse = yage.core.color.Color(g.mtl.diffuse);
			matl.getLayers()[0].specular = yage.core.color.Color(g.mtl.specular);
			matl.getLayers()[0].specularity = g.mtl.shininess;
			
			meshes[m].setMaterial(matl);

			// Load textures
			// Ms3d stores a texture map and an alpha map for every material
			//char[] texfile = .toString(ms3d.materials[midx].texture.ptr);
			//if (texfile.length){
			//	if (icmp(texfile[0..2], ".\\")==0) // linux fails with .\ in a path.
			//		texfile = texfile[2..length];
			//meshes[m].getMaterial().getLayers()[0].addTexture(ResourceManager.texture(path ~ texfile));
			//}
			//if (ms3d.materials[midx].alphamap[0])
			if(g.mtl.texture.length)
				meshes[m].getMaterial().getLayers()[0].addTexture(ResourceManager.texture(obj.path ~ g.mtl.texture));
			
			
			// Triangles
			Vec3i[] triangles = meshes[m].getTriangles();
			foreach(inout f; g.faces){
				//this will fan polygons
				while(f.length != 2){
					triangles ~= Vec3i(g.points[f[0]].vertex, g.points[f[1]].vertex, g.points[f[2]].vertex);
					
					//change to use yage.core.array
					for (size_t i = 1; i<f.length - 1; i++)
						f[i] = f[i+1];
					f.length = f.length - 1;
				}
			}
			meshes[m].setTriangles(triangles);
		}
		
		setAttribute("gl_Vertex", vertices);
		setAttribute("gl_TexCoord", texcoords);
		setAttribute("gl_Normal", normals);
	}
}