/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.manager;

import tango.text.Unicode;
import tango.text.Util;
import tango.io.device.File;
import tango.io.FilePath;
import tango.io.Path;
import tango.io.model.IFile : FileConst;

import yage.core.array;
import yage.core.misc;
import yage.core.object2;
import yage.core.timer;

import yage.resource.collada;
import yage.resource.embed.embed;
import yage.resource.font;
import yage.resource.model;
import yage.resource.graphics.material;
import yage.resource.graphics.texture;
import yage.resource.graphics.shader;
import yage.resource.sound;
import yage.system.log;

/**
 * The ResourceManager Manager is a static class that keeps track of which filesystem resources are in memory.
 * All functions that load resources insert the source path of what was loaded
 * as a key in the associative array while the value returns the class itself.
 * In order to prevent duplicates of resources loaded into memory, this class should be used
 * to acquire resources.*/
struct ResourceManager
{

	private struct TextureKey
	{	char[] source;
		Texture.Format format;
		bool mipmap;
		
		hash_t toHash()
		{	return typeid(char[]).getHash(&source) ^ format ^ mipmap;
		}
		int opEquals(TextureKey* rhs) // seems to go unused
		{	return source == rhs.source && format == rhs.format && mipmap == rhs.mipmap;
		}
		int opCmp(TextureKey* rhs)
		{	// return positive if this is greater, negative if rhs is greater
			if (source != rhs.source) 
				return source > rhs.source ? 1 : -1;
        	if (format != rhs.format)
        		return format = rhs.format;
        	return cast(byte)mipmap - cast(byte)rhs.mipmap;
		}
	}
	
	static const DEFAULT_FONT = "__DEFAULT_FONT__"; // Used to specify the default font that's embedded as a resource in the yage executable.
	
	private static char[][] paths = [""];		// paths to look for resources
	private static Collada[char[]]	colladas;
	private static Font[char[]]		fonts;
	private static Material[char[]] materials;
	private static Model[char[]]	models;	
	private static Shader[char[]]	shaders;
	private static Sound[char[]]	sounds;
	private static Texture[TextureKey] textures;
	
	
	private static Font defaultFont;
	
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
			path = toLower(path);
		if (path[length-1] != FileConst.PathSeparatorChar)
			path ~= FileConst.PathSeparatorChar;
		paths ~= path;
		return paths.length;
	}

	static int addPath(char[][] paths)	// ditto
	{	foreach (p; paths)
			addPath(p);
		return paths.length;		
	}

	/**
	 * Resolve a relative path to a path relative to the working directory.
	 * Any paths defined by ResourceManager.addPath() are taken into account.
	 * Params:
	 *     path = Path to a file, relative to a path defined by addPath().
	 *     current_dir = Optional.  A directory relative to the working directory to search for the file pointed to by path.
	 * Returns: The resolved path.
	 * Throws: A ResourceException if the path could not be resolved. */
	static char[] resolvePath(char[] path, char[] current_dir="")
	{	
		// TODO: Quick return if it starts with / or _:/
		version (Windows)
		{	path = toLower(path);
			current_dir = toLower(current_dir);
		}
		char[] result = cleanPath(FS.join(current_dir, path));
		if (FilePath(result).exists)
			return result;
		foreach(char[] p; paths)
		{	result = cleanPath(FS.join(p, path));
			if (FilePath(result).exists)
				return result;
		}
		throw new ResourceException("The path '%s' could not be resolved.", path);
	}

	/// Remove a path from the array of resource search paths.
	static bool removePath(char[] path)
	{	version (Windows)
			path = toLower(path);
		for (int i=0; i<paths.length; i++)
			if (paths[i]==path)
			{	yage.core.array.remove(paths, i);
				return true;
			}
		return false;
	}

	/// Simply load a file, using ResourceManager's paths to resolve relative paths.
	static ubyte[] getFile(char[] filename)
	{	char[] absPath = ResourceManager.resolvePath(filename);
		return cast(ubyte[])File.get(absPath);
	}
	
	/// Return an associative array (indexed by filename) of a resource type.
	static Shader[char[]] getShaders() /// ditto
	{	return shaders;
	}
	static Model[char[]] getModels() /// ditto
	{	return models;
	}
	static Sound[char[]] getSounds() /// ditto
	{	return sounds;
	}
	
	static Font getDefaultFont()
	{	if (!defaultFont)
			defaultFont = new Font(cast(ubyte[])Embed.vera_ttf, "auto");
		return defaultFont;
	}

	/** 
	 * Acquire and return a requested Font.
	 * If it has already been loaded, the in-memory copy will be returned.
	 * If not, it will be loaded and then returned.
	 * Params: filename = The Font file that will be loaded, or Resource.DEFAULT_FONT */
	static Font font(char[] filename)
	{
		if (filename=="__DEFAULT_FONT__") // dmd 1.066, __DEFAULT_FONT__ becomes garbage when yage.lib and demo1 are compiled separately.  So much for const protection!
			return getDefaultFont();
		
		filename = resolvePath(filename);
		if (filename in fonts)
			return fonts[filename];
		Timer t = new Timer(true);
		fonts[filename] = new Font(filename);
		Log.info("Font ", filename ~ " loaded in ", t, " seconds.");
		return fonts[filename];
	}
	
	/** 
	 * Acquire and return a requested Model.
	 * If it has already been loaded, the in-memory copy will be returned.
	 * If not, it will be loaded and uploaded to video memory.
	 * All associated Materials, Textures, and Shaders will be loaded into
	 * the resource pool as well.
	 * Params: filename = The 3D Model file that will be loaded. */
	static Model model(char[] filename)
	{	char[] absPath = resolvePath(filename);		
		if (absPath in models)
			return models[absPath];
		
		Timer t = new Timer(true);
		models[absPath] = new Model(absPath);
		Log.info("Model ", absPath ~ " loaded in ", t, " seconds.");
		return models[absPath];
	}
	
	/**
	 * 
	 * Params:
	 *     filename = Path and id to collada file.  e.g. foo/bar.dae#IdForMaterial3 */
	static Material material(char[] filename, char[] id)
	{	
		filename = resolvePath(filename);
		char[] path = filename~"#"~id;
		auto result = path in materials;
		if (result)
			return *result;
		
		Timer t = new Timer(true);		
	
		Collada c = new Collada(filename);
		Material m = c.getMaterialById(id);
		materials[path] = m;
		Log.info("Material '%s' loaded in %s seconds.", path, t);
		return m;
	}

	/*
	 * TODO: Update this to store a hash of the source code for future lookups.
	 * Acquire and return a requested Shader.
	 *  If the Shader has already been loaded, the in-memory copy will be returned.
	 *  If not, it will be loaded and stored in the resource pool.  This function
	 *  is called automatically for each of a Material's Shaders when loading a Material.
	 *  Params: type = set to 0 for vertex shader or 1 for fragment shader.
	static Shader shader(char[] source, bool type)
	{	if (source in shaders)
			return shaders[source];
		Timer t = new Timer(true);
		shaders[source] = new Shader(source, type);
		Log.info("Shader ", source ~ " loaded in ", t, " seconds.");
		return shaders[source];
	}
	*/

	/** Acquire and return a requested Sound.
	 *  If the Sound has already been loaded, the in-memory copy will be returned.
	 *  If not, it will be loaded and stored in the resource pool.
	 *  Params: filename = The path to the sound file that will be loaded. */
	static Sound sound(char[] filename)
	{	filename = resolvePath(filename);
		if (filename in sounds)
			return sounds[filename];
		
		Timer t = new Timer(true);
		sounds[filename] = new Sound(filename);
		Log.info("Sound ", filename ~ " loaded in ", t, " seconds.");
		return sounds[filename];
	}
	
	/** 
	 * Acquire and return a requested Texture.
	 * If a texture with the given properties already been loaded, the in-memory copy will be returned.  
	 * If not, it will be loaded, uploaded to video memory, and stored in the resource pool.  
	 * This function is called automatically for each of a material's textures when loading a material.
	 * Keep in mind that multiple requested textures may use the same Texture.
	 * Params: filename = The Texture image file that will be loaded. */	
	static Texture texture(char[] filename, Texture.Format format=Texture.Format.AUTO, bool mipmap=true)
	{	filename = resolvePath(filename);
		TextureKey key;
		key.source = filename;		
		key.mipmap = mipmap;
		
		// Search for matching format
		int minFormat = Texture.Format.AUTO ? 0 : format;
		int maxFormat = Texture.Format.AUTO ? Texture.Format.max : format;
		for (int i=minFormat; i<maxFormat+1; i++)
		{	key.format = cast(Texture.Format)i;
			auto result = key in textures;
			if (result)
				return *result;
		}
		
		// Create new texture
		Timer t = new Timer(true);
		Texture result = new Texture(filename, format, mipmap);
		Log.info("Texture '%s' loaded in %s seconds.", filename, t);
		textures[key] = result;
		return result;		
	}
	
	//static void cleanup(uint age=3600) {} // TODO We'd need a way to store an age for each resource type, render would update it.
	
	/**
	 * Clear all references to loaded resources. */
	static void dispose()
	{	
		// Perhaps this should be handled elsewhere?
		foreach (res; sounds)
			res.dispose();

		fonts = null;
		materials = null;
		models = null;
		shaders = null;
		sounds = null;
		textures = null;
		
		defaultFont = null;
	}
}