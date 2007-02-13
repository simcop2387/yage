/**
 * Copyright:  (c) 2006-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.resource;

import std.file;
import std.path;
import std.stdio;
import yage.core.horde;
import yage.core.misc;
import yage.resource.model;
import yage.resource.material;
import yage.resource.texture;
import yage.resource.shader;
import yage.resource.sound;
import yage.core.timer;
import yage.system.log;
import std.string;


/**
 * The Resource Manager keeps track of which filesystem resources are in memory.
 * All functions that load resources insert the source path of what was loaded
 * as a key in the associative array while the value returns the class itself.
 * When a manual request is made to load a resource, such as a Texture or a Material,
 * a check should first be made with the resource manager.*/
abstract class Resource
{
	static Horde!(char[]) paths;		// paths to look for resources

	private static Texture[char[]][2][2]  textures; // [source][clamped][compressed][mipmapped][filter]
	private static Shader[char[]]	shaders;
	private static Material[char[]] materials;
	private static Model[char[]]	models;
	private static Sound[char[]]	sounds;

	/// Initialize
	static this()
	{	paths.add("");
	}

	/// Get the array of path strings
	static char[][] getPath()
	{	return paths.array();
	}

	/**
	 * Add a path to searh when loading resource files.
	 * Paths are relative to the location of the executable.
	 * Returns:
	 * The number of paths defined after adding the path.*/
	static int addPath(char[] path)
	{	version (Windows)
			path = tolower(path);
		if (path[length-1] != std.path.sep[0])
			path ~= std.path.sep;
		return paths.add(path);
	}

	/**
	 * Resolve a relative path to a path relative to the working directory.
	 * Any paths defined by Resource.addPath() are taken into account.
	 * Params:
	 * path = Path to a file, relative to a path defined by addPath().
	 * current_dir = Optional.  A directory relative to the working directory
	 * to search for the file pointed to by path.
	 * Returns:
	 * The resolved path.
	 * Throws:
	 * An Exception if the path could not be resolved.*/
	static char[] resolvePath(char[] path, char[] current_dir="")
	{	version (Windows)
		{	path = tolower(path);
			current_dir = tolower(current_dir);
		}
		if (std.file.exists(std.path.join(current_dir, path)))
			return cleanPath(current_dir~path);
		foreach(char[] p; paths.array())
			if (std.file.exists(std.path.join(p, path)))
				return cleanPath(p~path);
		throw new Exception("The path '" ~ path ~ "' could not be resolved.");
	}

	/// Remove a path from the array of resource search paths.
	static bool removePath(char[] path)
	{	version (Windows)
			path = tolower(path);

		for (int i=0; i<paths.length; i++)
			if (paths[i]==path)
			{	paths.remove(i);
				return true;
			}
		return false;
	}

	/// Return an associative array of all loaded Textures.
	static Texture[char[]][][] getTextures()
	{	return cast(Texture[char[]][][])textures;
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

	static void clearShaders()
	{	shaders = null;
	}


	/** Acquire and return the given Model.
	 *  If it has already been loaded, the in-memory copy will be returned.
	 *  If not, it will be loaded and uploaded to video memory.
	 *  All associated Materials, Textures, and Shaders will be loaded into
	 *  the resource pool as well.
	 *  \param source The 3D Model file that will be loaded. */
	static Model model(char[] source)
	{	if (source in models)
			return models[source];
		Timer a = new Timer();
		models[source] = new Model(source);
		Log.write("Model loaded in " ~ .toString(a.get()) ~ "seconds");
		return models[source];
	}

	/** Acquire and return the given Material.
	 *  If the material has already been loaded, the in-memory copy will be returned.
	 *  If not, it will be loaded and stored in the resource pool.  This function
	 *  is called automatically for each of a Model's Materials when loading a Model.
	 *  \param source The xml Material file that will be loaded. */
	static Material material(char[] source)
	{	if (source in materials)
			return materials[source];
		return materials[source] = new Material(source);
	}

	/** Acquire and return the given Yexture.
	 *  If a texture with the given properties already been loaded, the in-memory
	 *  copy will be returned.  If not, it will be loaded, uploaded to video memory,
	 *  and stored in the resource pool.  This function is called automatically
	 *  for each of a material's textures when loading a material.
	 *  \param source The Texture image file that will be loaded. */
	static Texture texture(char[] source, bool compress, bool mipmap)
	{	// Remember that multidimensional arrays must be accessed in reverse.
		if (source in textures[mipmap][compress])
			return textures[mipmap][compress][source];
		return textures[mipmap][compress][source] =
				new Texture(source, compress, mipmap);
	}

	/** Acquire a Texture with default settings
	 *  \param source The Texture image file that will be loaded. */
	static Texture texture(char[] source)
	{	if (source in textures[1][1])
			return textures[1][1][source];
		return textures[1][1][source] = new Texture(source, 1, 1);
	}

	/** Acquire and return the given Shader.
	 *  If the Shader has already been loaded, the in-memory copy will be returned.
	 *  If not, it will be loaded and stored in the resource pool.  This function
	 *  is called automatically for each of a Material's Shaders when loading a Material.
	 *  \param type set to 0 for vertex shader or 1 for fragment shader.*/
	static Shader shader(char[] source, bool type)
	{	if (source in shaders)
			return shaders[source];
		return shaders[source] = new Shader(source, type);
	}

	/** Acquire and return the given Sound.
	 *  If the Sound has already been loaded, the in-memory copy will be returned.
	 *  If not, it will be loaded and stored in the resource pool.
	 *  \param source The path to the sound file that will be loaded. */
	static Sound sound(char[] source)
	{	if (source in sounds)
			return sounds[source];
		return sounds[source] = new Sound(source);
	}


	/// Print a list of all resources loaded
	static void print()
	{	printf("=== Resources Loaded ===\n");
		foreach (Model modl; models)
			printf("%.*s\n", modl.getSource());
		foreach (Material matl; materials)
			printf("%.*s\n", matl.getSource());
		foreach (Sound snd; sounds)
			snd.print();

		foreach (Shader shdr; shaders)
			printf("%.*s\n", shdr.getSource());
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
