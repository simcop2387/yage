/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.material;

import std.conv;
import std.file;
import std.path;
import std.stream;
import std.string;
import std.stdio;
import yage.core.all;
import yage.resource.texture;
import yage.resource.resource;
import yage.resource.shader;
import yage.system.constant;
import yage.system.device;
import yage.system.log;
public import yage.resource.layer;

/**
 * A material defines how an object in the 3D world appears.  Materials
 * can be assigned to sprite nodes, mesh nodes, and even GUI elements.
 * In addition, material parameters can be updated while the engine
 * is running, allowing for quite a few nice effects.*/
class Material
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
		source = Resource.resolvePath(filename);
		Log.write("Loading material '" ~ source ~ "'.");
		char[] path = source[0 .. rfind(source, "/") + 1]; // should be replace with getDirName(absolute(path))

		// Load xml file
		XmlNode xml;
		try
		{	xml = readDocument(source);
		} catch
		{	throw new Exception("Unable to parse xml material file '"~source~"'.");
		}

		// Load material attributes
		try
		{	max_lights = atoi(xml.getAttribute("maxlights"));
		}catch
		{	throw new Exception("Could not parse material attributes.");
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

			// Convert a 6-char hexadecimal color value to a Vec4f color
			Vec4f strToColor(char[] input)
			{	dword d;
				d.ui= hexToUint(input);
				return Vec4f(d.ub[0]/255.0f, d.ub[1]/255.0f, d.ub[2]/255.0f, 1.0);
			}
			// Load layer attributes
			try
			{	// Ambient, diffuse, specular, emissive, specularity
				if (xml_layer.hasAttribute("diffuse"))
					layer.diffuse = strToColor(xml_layer.getAttribute("diffuse"));
				if (xml_layer.hasAttribute("ambient"))
					layer.ambient = strToColor(xml_layer.getAttribute("ambient"));
				if (xml_layer.hasAttribute("specular"))
					layer.specular= strToColor(xml_layer.getAttribute("specular"));
				if (xml_layer.hasAttribute("emissive"))
					layer.emissive= strToColor(xml_layer.getAttribute("emissive"));
				if (xml_layer.hasAttribute("specularity"))
					layer.specularity = atoi(xml_layer.getAttribute("specularity"));
				if (layer.specularity<0 || layer.specularity>128)
					throw new Exception("Could not parse layer '" ~ .toString(i) ~
						"' attributes.  Specularity must be between 0 and 128.\n");

				// Blend
				if(xml_layer.hasAttribute("blend"))
				{	char[] blend = tolower(xml_layer.getAttribute("blend"));
					switch (blend)
					{	case "none"		: layer.blend = BLEND_NONE;  break;
						case "add"		: layer.blend = BLEND_ADD;  break;
						case "multiply"	: layer.blend = BLEND_MULTIPLY;  break;
						case "average"	: layer.blend = BLEND_AVERAGE;  break;
						default: throw new Exception("Invalid blend value '" ~ blend ~"'.");
				}	}

				// Cull, mode, width
				if(xml_layer.hasAttribute("cull"))
				{	char[] cull = tolower(xml_layer.getAttribute("cull"));
					switch (cull)
					{	case "front"	: layer.cull = LAYER_CULL_FRONT;  break;
						case "back"		: layer.cull = LAYER_CULL_FRONT;  break;
						default: throw new Exception("Invalid cull value '" ~ cull ~"'.");
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
						default: throw new Exception("Invalid draw value '" ~ draw~"'.");
				}	}
				if(xml_layer.hasAttribute("width"))
					layer.width = atoi(xml_layer.getAttribute("width"));

			}catch (Exception e)
			{	throw new Exception("Could not parse layer '" ~ .toString(i) ~"' attributes.\n"
					~ e.toString());
			}

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
								default: throw new Exception("Invalid blend value '" ~ blend ~"'.");
						}	}

						// Filter
						if (xmap.hasAttribute("filter"))
						{	char[] str = xmap.getAttribute("filter");
							switch (str)
							{	case "none"		:
								case "nearest"	: ti.filter = TEXTURE_FILTER_NONE; break;
								case "bilinear"	: ti.filter = TEXTURE_FILTER_BILINEAR; break;
								case "trilinear": ti.filter = TEXTURE_FILTER_TRILINEAR; break;
								default: throw new Exception("Invalid filter value '" ~ str ~"'.");
						}	}

						// Position, rotation, scale
						if (xmap.hasAttribute("position")) ti.position.v[0..2] = csvToFloat(xmap.getAttribute("position"));
						if (xmap.hasAttribute("rotation")) ti.rotation         =       atof(xmap.getAttribute("rotation"));
						if (xmap.hasAttribute("scale"   )) ti.scale.v[0..2]    = csvToFloat(xmap.getAttribute("scale"));
					}
					catch (Exception e)
					{	throw new Exception(
							"Could not parse texture '" ~ .toString(t) ~"' in layer '" ~ .toString(i) ~"'.\n"
							~ e.toString());
					}

					// Add the texture instance to the layer
					ti.texture = Resource.texture(Resource.resolvePath(source, path), compress, mipmap).texture;
 					layer.addTexture(ti);
				}
				// If this xml node is a shader
				else if (name == "shader" && Device.getSupport(DEVICE_SHADER))
				{	s++;
					bool type;
					char[] source, str_type;
					try
					{	source	= xmap.getAttribute("src");
						str_type= tolower(xmap.getAttribute("type"));
					}catch
					{	throw new Exception(
							"Could not parse shader '" ~ .toString(s) ~"' in layer '" ~ .toString(i) ~"'.\n");
					}
					// Convert type from string to bool, and load
					if (str_type=="vertex") type = 0;
					else if (str_type=="fragment") type = 1;
					else throw new Exception("Could not parse shader type '" ~ str_type ~ "' in shader '"
									~ .toString(s) ~ "'.  Must be 'vertex' or 'fragment'.");
					layer.addShader(Resource.shader(Resource.resolvePath(source, path), type));
				}
			}

			// Warning for too many textures
			static int max_textures;
			if (max_textures==0)
				max_textures = Device.getLimit(DEVICE_MAX_TEXTURES);
			if (t>max_textures)
			{	Log.write("WARNING:  layer '", .toString(i) ,"' has ", .toString(t),
					" textures, but this hardware only supports ", .toString(max_textures), ".");
			}

			// Link Shaders
			if (layer.getShaders().length)
				layer.linkShaders();
		}
	}

	/// Remove the layer with the given index from this material.
	void removeLayer(int index)
	{	yage.core.array.remove(layers, index, true);
	}

	/// Return a string of xml for this material along with all layers.
	char[] toString()
	{	char[] result;
		result = formatString("<material maxlights=%d>\n", max_lights);
		// Loop through layers
		foreach (Layer layer; layers)
			result ~= layer.toString();
		result~= formatString("</material>\n");
		return result;
	}
}



