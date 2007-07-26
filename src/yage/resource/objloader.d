/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.objloader;

import std.string;
import std.file;
import std.path;
import std.stdio;
import std.string;
import std.conv;

import yage.core.matrix;
import yage.core.misc;
import yage.core.vector;
import yage.resource.model;
import yage.resource.material;
import yage.resource.mesh;
import yage.resource.resource;
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

struct MTL{}

struct group{
	//MTL mtl;
	point[char[]] points;//used to test if point already exists
	//char[] == lazy man's point reference
	face[] faces; //array of char[] is face, array of faces
	//face[] faces;
	
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
	
	Vec3f[] vertices, normals;
	Vec2f[] texcoords;
	
	char[] file;
	
	void load(char[] source){
		file = cast(char[])read(source);
		char[][] lines = splitlines(file);
		//delete file;
		
		group g;
		groups ~= g;
		
		foreach(inout line; lines){
			line = strip(line);
			handleLine(line);
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
					//mesh[$-1].material = 
					break;
				case "mtllib":
					//new Material(words[1]);
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

/**
 * Create Models from files and other sources.
 * This is separated and used as a mixin to reduce the length of model.d.*/
template ObjLoader(){

	/**
	 * Load a model from a Wavefront obj file.
	 * All materials, etc. referenced by this model are loaded through the Resource
	 * manager to avoid duplicates.  Meshes without a material are assigned a default material.*/
	protected void loadObj(char[] filename){
		Vec3f[] vertices, normals;
		Vec2f[] texcoords;
		
		source = Resource.resolvePath(filename);
		char[] path = source[0 .. rfind(source, "/") + 1]; // path stripped of filename
		
		OBJ obj;
		obj.load(source);
		
		foreach(inout g; obj.groups){ //makes new vertices for different normals or tex
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
		}
		
		// Meshes
		foreach(g; obj.groups[1..$]){
			meshes ~= new Mesh();
			int m = meshes.length - 1;
			Vec3i[] triangles = meshes[m].getTriangles();
			
			// Triangles
			foreach(f; g.faces){
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