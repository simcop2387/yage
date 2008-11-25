/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.manager;

import std.path;
import std.stdio;
import yage.core.array;
import yage.core.misc;
import yage.resource.exceptions;
import yage.resource.font;
import yage.resource.model;
import yage.resource.material;
import yage.resource.texture;
import yage.resource.shader;
import yage.resource.sound;
import yage.core.timer;
import yage.system.log;
import yage.system.constant;
import std.string;


/**
 * The ResourceManager Manager is a static class that keeps track of which filesystem resources are in memory.
 * All functions that load resources insert the source path of what was loaded
 * as a key in the associative array while the value returns the class itself.
 * When a manual request is made to load a resource, such as a Texture or a Material,
 * a check should first be made with the resource manager.*/
abstract class ResourceManager
{
	static char[][] paths = [""];		// paths to look for resources

	private static Font[char[]]		fonts;
	private static GPUTexture[char[]][2][2] textures; // [source][clamped][compressed][mipmapped][filter]
	private static Shader[char[]]	shaders;
	private static Material[char[]] materials;
	private static Model[char[]]	models;
	private static Sound[char[]]	sounds;

	/// Get the array of path strings
	static char[][] getPaths()
	{	return paths;
	}

	/**
	 * Add a path or array of paths to searh when loading resource files.
	 * Paths are relative to the location of the executable.
	 * Returns:
	 * The number of paths defined after adding the path.*/
	static int addPath(char[] path)
	{	version (Windows)
			path = tolower(path);
		if (path[length-1] != std.path.sep[0])
			path ~= std.path.sep;
		paths ~= path;
		return paths.length;
	}
	/// ditto
	static int addPath(char[][] paths)
	{	foreach (p; paths)
			addPath(p);
		return paths.length;		
	}

	/**
	 * /**
	 * Resolve a relative path to a path relative to the working directory.
	 * Any paths defined by ResourceManager.addPath() are taken into account.
	 * Params:
	 *     path = Path to a file, relative to a path defined by addPath().
	 *     current_dir = Optional.  A directory relative to the working directory to search for the file pointed to by path.
	 * Returns: The resolved path.
	 * Throws: A ResourceManagerException if the path could not be resolved. */
	static char[] resolvePath(char[] path, char[] current_dir="")
	{	version (Windows)
		{	path = tolower(path);
			current_dir = tolower(current_dir);
		}
		if (std.file.exists(std.path.join(current_dir, path)))
			return cleanPath(current_dir~path);
		foreach(char[] p; paths)
			if (std.file.exists(std.path.join(p, path)))
				return cleanPath(p~path);
		throw new ResourceManagerException("The path '%s' could not be resolved.", path);
	}

	/// Remove a path from the array of resource search paths.
	static bool removePath(char[] path)
	{	version (Windows)
			path = tolower(path);
		for (int i=0; i<paths.length; i++)
			if (paths[i]==path)
			{	yage.core.array.remove(paths, i);
				return true;
			}
		return false;
	}

	/// Return an associative array of all loaded Textures.
	static GPUTexture[char[]][][] getTextures()
	{	return cast(GPUTexture[char[]][][])textures;
	}

	/// Return an associative array of all loaded Shaders.
	static Shader[char[]] getShaders()
	{	return shaders;
	}

	/// Return an associative array of all loaded Materials.
	static Material[char[]] getMaterials()
	{	return materials;
	}

	/// Return an associative array of all loaded Models.
	static Model[char[]] getModels()
	{	return models;
	}

	/// Return an associative array of all loaded Sounds.
	static Sound[char[]] getSounds()
	{	return sounds;
	}

	/** 
	 * Acquire and return the given Font.
	 * If it has already been loaded, the in-memory copy will be returned.
	 * If not, it will be loaded and then returned.
	 * Params: source = The Font file that will be loaded. */
	static Font font(char[] source)
	{	if (source in fonts)
			return fonts[source];
		Timer t = new Timer();
		fonts[source] = new Font(source);
		Log.write(Log.RESOURCE, "ResourceManager ", source ~ " loaded in ", t, " seconds.");
		return fonts[source];
	}
	
	/** 
	 * Acquire and return the given Model.
	 * If it has already been loaded, the in-memory copy will be returned.
	 * If not, it will be loaded and uploaded to video memory.
	 * All associated Materials, Textures, and Shaders will be loaded into
	 * the resource pool as well.
	 * Params: source = The 3D Model file that will be loaded. */
	static Model model(char[] source)
	{	if (source in models)
			return models[source];
		Timer t = new Timer();
		models[source] = new Model(source);
		Log.write(Log.RESOURCE, "ResourceManager ", source ~ " loaded in ", t, " seconds.");
		return models[source];
	}

	/** Acquire and return the given Material.
	 *  If the material has already been loaded, the in-memory copy will be returned.
	 *  If not, it will be loaded and stored in the resource pool.  This function
	 *  is called automatically for each of a Model's Materials when loading a Model.
	 *  Params: source = The xml Material file that will be loaded. */
	static Material material(char[] source)
	{	if (source in materials)
			return materials[source];
		Timer t = new Timer();
		materials[source] = new Material(source);
		Log.write(Log.RESOURCE, "ResourceManager ", source ~ " loaded in ", t, " seconds.");
		return materials[source];
	}

	/** Acquire and return the given Texture.
	 *  If a texture with the given properties already been loaded, the in-memory copy will be returned.  
	 *  If not, it will be loaded, uploaded to video memory, and stored in the resource pool.  
	 *  This function is called automatically for each of a material's textures when loading a material.
	 *  Params: source = The Texture image file that will be loaded. */
	static Texture texture(char[] source, bool compress=true, bool mipmap=true, bool clamp=false, int filter=TEXTURE_FILTER_DEFAULT)
	{	// Remember that multidimensional arrays must be accessed in reverse.
		if (source in textures[mipmap][compress])
			return Texture(textures[mipmap][compress][source]);
		Timer t = new Timer();
		textures[mipmap][compress][source] = new GPUTexture(source, compress, mipmap);
		Log.write(Log.RESOURCE, "ResourceManager ", source ~ " loaded in ", t, " seconds.");
		return Texture(textures[mipmap][compress][source], clamp, filter);
	}

	/** Acquire and return the given Shader.
	 *  If the Shader has already been loaded, the in-memory copy will be returned.
	 *  If not, it will be loaded and stored in the resource pool.  This function
	 *  is called automatically for each of a Material's Shaders when loading a Material.
	 *  Params: type = set to 0 for vertex shader or 1 for fragment shader.*/
	static Shader shader(char[] source, bool type)
	{	if (source in shaders)
			return shaders[source];
		Timer t = new Timer();
		shaders[source] = new Shader(source, type);
		Log.write(Log.RESOURCE, "ResourceManager ", source ~ " loaded in ", t, " seconds.");
		return shaders[source];
	}

	/** Acquire and return the given Sound.
	 *  If the Sound has already been loaded, the in-memory copy will be returned.
	 *  If not, it will be loaded and stored in the resource pool.
	 *  Params: source = The path to the sound file that will be loaded. */
	static Sound sound(char[] source)
	{	if (source in sounds)
			return sounds[source];
		Timer t = new Timer();
		sounds[source] = new Sound(source);
		Log.write(Log.RESOURCE, "ResourceManager ", source ~ " loaded in ", t, " seconds.");
		return sounds[source];
	}
	
	static void finalize()
	{	/*
		foreach (i; fonts)
			i.finalize();
		foreach (i; materials)
			i.finalize();
		foreach (i; models)
			i.finalize();
		foreach (i; shaders)
			i.finalize();
		foreach (i; sounds)
			i.finalize();
		foreach (i; textures)
			i.finalize();
		*/
	}


	/// Print a list of all resources loaded
	static void print()
	{	foreach (Model modl; models)
			writefln("%.*s", modl.getSource());
		foreach (Material matl; materials)
			writefln("%.*s", matl.getSource());
		foreach (Sound snd; sounds)
			snd.print();

		foreach (Shader shdr; shaders)
			writefln("%.*s", shdr.getSource());
		/*
		foreach (Texture tex1[2][2][2][char[]]; textures)
			foreach (Texture tex2[2][2][char[]]; tex1)
				foreach (Texture tex3[2][char[]]; tex2)
					foreach (Texture tex4[char[]]; tex3)
						foreach (Texture tex5; tex4)
							printf("%.*s, %d, %d, %d, %d\n", tex5.getSource(), tex5.getClamped(),
							tex5.getCompressed(), tex5.getMipmapped(), tex5.getFilter());
		*/
	}

}
