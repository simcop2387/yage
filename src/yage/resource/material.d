/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.material;

import tango.util.Convert;
import tango.text.convert.Format;
import tango.io.device.File;
import std.file;
import std.path;
import std.stream;
import std.string;
import std.stdio;
import yage.core.all;
import yage.core.object2;
import yage.resource.texture;
import yage.resource.manager;
import yage.resource.resource;
import yage.resource.shader;
import yage.system.system;
import yage.system.graphics.probe;
import yage.system.log;
public import yage.resource.layer;

/**
 * @deprecated
 * This is old code and will be replaced once Collada becomes the default model format.
 * Layer should be renamed to Material, and Meshes should have an array of materials
 * 
 * A material defines how an object in the 3D world appears.  Materials
 * can be assigned to sprite nodes, mesh nodes, and even GUI elements.
 * In addition, material parameters can be updated while the engine
 * is running, allowing for quite a few nice effects.*/
class Material : Resource
{
	// Internal structure
	protected char[] source;		// the path to the xml file.
	protected int max_lights;
	protected Layer[] layers;

	/// Construct an empty material.
	this()
	{	}

	/// Create this material from an xml material file.
	this(char[] filename)
	{	this();
		load(filename);
	}

	/// Add a new layer to this material and return it.
	int addLayer(Layer l)
	{	layers~=l;
		return layers.length; 
	}

	/// Get all Layers as an array.
	Layer[] getLayers()
	{	return layers;
	}

	/// Return the path and filename from where this material was loaded.
	char[] getSource()
	{	return source;
	}

	/// Parse the given XML file and load it into memory, creating layers and textures as necessary
	void load(char[] filename)
	{
		source = ResourceManager.resolvePath(filename);
		char[] path = source[0 .. rfind(source, "/") + 1]; // should be replace with getDirName(absolute(path))

		// Load xml file
		XmlNode xml;
		try
		{	xml = readDocument(source);
		} catch
		{	throw new ResourceException("Unable to parse xml material file '"~source~"'.");
		}

		// Load material attributes
		try
		{	max_lights = to!(int)(xml.getAttribute("maxlights"));
		}catch
		{	throw new ResourceException("Could not parse material attributes.");
		}

		// Loop through each xml layer node
		layers.length = 0;
		foreach (XmlNode xml_layer; xml.getChildren())
		{	// Skip all nodes that aren't layers
			if(tolower(xml_layer.getName()) != "layer")
				continue;

			// Create layer with default values
			Layer layer = new Layer();
			int i = addLayer(layer);

			// Load layer attributes
			try
			{	// Ambient, diffuse, specular, emissive, specularity
				if (xml_layer.hasAttribute("diffuse"))
					layer.diffuse = Color(xml_layer.getAttribute("diffuse"));
				if (xml_layer.hasAttribute("ambient"))
					layer.ambient = Color(xml_layer.getAttribute("ambient"));
				if (xml_layer.hasAttribute("specular"))
					layer.specular= Color(xml_layer.getAttribute("specular"));
				if (xml_layer.hasAttribute("emissive"))
					layer.emissive= Color(xml_layer.getAttribute("emissive"));
				if (xml_layer.hasAttribute("specularity"))
					layer.specularity = atoi(xml_layer.getAttribute("specularity"));
				if (layer.specularity<0 || layer.specularity>128)
					throw new ResourceException("Could not parse layer '", i,
						"' attributes.  Specularity must be between 0 and 128.\n");

				// Blend
				if(xml_layer.hasAttribute("blend"))
				{	char[] blend = tolower(xml_layer.getAttribute("blend"));
					switch (blend)
					{	case "none"		: layer.blend = BLEND_NONE;  break;
						case "add"		: layer.blend = BLEND_ADD;  break;
						case "multiply"	: layer.blend = BLEND_MULTIPLY;  break;
						case "average"	: layer.blend = BLEND_AVERAGE;  break;
						default: throw new ResourceException("Invalid blend value '" ~ blend ~"'.");
				}	}

				// Cull, mode, width
				if(xml_layer.hasAttribute("cull"))
				{	char[] cull = tolower(xml_layer.getAttribute("cull"));
					switch (cull)
					{	case "front"	: layer.cull = LAYER_CULL_FRONT;  break;
						case "back"		: layer.cull = LAYER_CULL_FRONT;  break;
						default: throw new ResourceException("Invalid cull value '" ~ cull ~"'.");
				}	}
				if(xml_layer.hasAttribute("draw"))
				{	char[] draw = tolower(xml_layer.getAttribute("draw"));
					switch (draw)
					{	case "fill"		:
						case "polygon"	:
						case "polygons"	: layer.draw = LAYER_DRAW_FILL;  break;
						case "line"		:
						case "lines"	: layer.draw = LAYER_DRAW_LINES;  break;
						case "point"	:
						case "points"	: layer.draw = LAYER_DRAW_POINTS;  break;
						default: throw new ResourceException("Invalid draw value '" ~ draw~"'.");
				}	}
				if(xml_layer.hasAttribute("width"))
					layer.width = atoi(xml_layer.getAttribute("width"));

			}catch (Exception e)
			{	throw new ResourceException("Could not parse layer '", i, "' attributes.\n", e);
			}
			
			char[] vertexShader;
			char[] fragmentShader;

			// Loop through each xml texture and shader of the layer
			int t, s;	// texture and shader counters
			foreach (XmlNode xmap; xml_layer.getChildren())
			{	char[] name = tolower(xmap.getName());				
			
				// If this xml node is a texture
				if (name == "texture" || name == "map")
				{	t++;
					// Create map and store attributes
					char[] source;
					bool compress=true, mipmap=true;
					Texture ti;
					try
					{	// Source, name, compress, mipmap, clamp, reflective
						source = xmap.getAttribute("src"); // required attribute?
						if (xmap.hasAttribute("name"  ))  ti.name   = xmap.getAttribute("name");
						if (xmap.hasAttribute("compress")) compress = strToBool(xmap.getAttribute("compress"));
						if (xmap.hasAttribute("mipmap"  )) mipmap   = strToBool(xmap.getAttribute("mipmap"));
						if (xmap.hasAttribute("clamp"  ))  ti.clamp = strToBool(xmap.getAttribute("clamp"));
						if (xmap.hasAttribute("reflective")) ti.reflective = strToBool(xmap.getAttribute("reflective"));


						// Blend
						if(xmap.hasAttribute("blend"))
						{	char[] blend = tolower(xmap.getAttribute("blend"));
							switch (blend)
							{	case "none"		: ti.blend = BLEND_NONE;  break;
								case "add"		: ti.blend = BLEND_ADD;  break;
								case "multiply"	: ti.blend = BLEND_MULTIPLY;  break;
								case "average"	: ti.blend = BLEND_AVERAGE;  break;
								default: throw new ResourceException("Invalid blend value '" ~ blend ~"'.");
						}	}

						// Filter
						if (xmap.hasAttribute("filter"))
						{	char[] str = xmap.getAttribute("filter");
							switch (str)
							{	case "none"		:
								case "nearest"	: ti.filter = Texture.Filter.NONE; break;
								case "bilinear"	: ti.filter = Texture.Filter.BILINEAR; break;
								case "trilinear": ti.filter = Texture.Filter.TRILINEAR; break;
								default: throw new ResourceException("Invalid filter value '" ~ str ~"'.");
						}	}

						// Position, rotation, scale
						if (xmap.hasAttribute("position")) ti.transform.setPosition(Vec3f(csvToFloat(xmap.getAttribute("position"))));
						//if (xmap.hasAttribute("rotation")) ti.rotation         =       atof(xmap.getAttribute("rotation"));
						//if (xmap.hasAttribute("scale"   )) ti.scale.v[0..2]    = csvToFloat(xmap.getAttribute("scale"));
					}
					catch (Exception e)
					{	throw new ResourceException(
							"Could not parse texture '", t, "' in layer '", i, "'.\n"
							~ e.toString());
					}

					// Add the texture instance to the layer
					ti.texture = ResourceManager.texture(ResourceManager.resolvePath(source, path), compress, mipmap).texture;
 					layer.addTexture(ti);
				}
				// If this xml node is a shader
				else if (name == "shader" && Probe.feature(Probe.Feature.SHADER))
				{	s++;
					char[] source, type;
					try
					{	source	= xmap.getAttribute("src");
						type= tolower(xmap.getAttribute("type"));
					}catch
					{	throw new ResourceException(
							"Could not parse shader '", s, "' in layer '", i, "'.\n");
					}
					// Convert type from string to bool, and load
					if (type=="vertex")
						vertexShader = cast(char[])tango.io.device.File.File.get(ResourceManager.resolvePath(source, path));
					else if (type=="fragment") 
						fragmentShader = cast(char[])tango.io.device.File.File.get(ResourceManager.resolvePath(source, path));
					else 
						throw new ResourceException("Could not parse shader type '" ~ type ~ "' in shader '",
									s, "'.  Must be 'vertex' or 'fragment'.");					
				}
			}
			
			// New
			if (vertexShader.length && fragmentShader.length) // TODO: Send through resource manager.
				layer.shader = new Shader(vertexShader, fragmentShader);

			// Warning for too many textures
			static int max_textures;
			if (max_textures==0)
				max_textures = Probe.feature(Probe.Feature.MAX_TEXTURE_UNITS);
			if (t>max_textures)
			{	Log.info("WARNING:  layer '", i ,"' has ", t,
					" textures, but this hardware only supports ", max_textures, ".");
			}
		}
	}

	/// Remove the layer with the given index from this material.
	void removeLayer(int index)
	{	yage.core.array.remove(layers, index, true);
	}

	/// Return a string of xml for this material along with all layers.
	char[] toString()
	{	char[] result;
		result = Format.convert("<material maxlights={}>\n", max_lights);
		// Loop through layers
		foreach (Layer layer; layers)
			result ~= layer.toString();
		result~= "</material>\n";
		return result;
	}
}



