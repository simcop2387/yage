/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.core.json;

import tango.core.Traits;
import tango.text.convert.Format;

/// TODO: enums
struct Json
{
	///
	static struct Options
	{
		char[] tab = "    ";       ///
		char[] lineReturn = "\n";  ///
		int maxDepth = 16;         ///
		int maxArrayLength = 64;   ///
		int floatPrecision = 6;    /// TODO
		int uintAsHex = false;     /// TODO
		bool useReferences = true; /// Print a reference to an object instead of adding it more than once.
		
		private int currentDepth = 0;
		
		static Options opCall()
		{	Options result;
			return result;
		}
	}
	
	private char[][Object] references;
	private char[][void*] pointers;
	
	/**
	 * Convert a primitive, object, or array to a Json string */
	static char[] encode(T)(T object, Options options=Options())
	{	Json json; // makes instance of references on the stack, keeps things thread-sate
		return json.internalEncode(object, options);
	}
	
	private char[] internalEncode(T)(T object, Options options=Options(), char[] path="this")
	{
		static if (is(T : bool)) // bool
			return object ? "true" : "false";			
		else if (is(T : real))  // byte-ulong, float-real, and enum
			return Format("{}", object);
		else static if (isCharType!(T) || isStringType!(T)) // char-dchar, char[]-dchar[]
			return "\"" ~ object ~ '"';
		else  static if (isArrayType!(T) || isAssocArrayType!(T) || is(T : Object) || is(T==struct)) // aggregate type, recurse
		{	
			if (options.currentDepth >= options.maxDepth)
				return "Max Depth Exceeded";						
			options.currentDepth++;
			
			// Repeat tabs to indentation level
			char[] tab = "";
			for (int i=0; i<options.currentDepth; i++)
				tab ~= options.tab;
			char[] tab2 = tab[0..$-options.tab.length]; // one tab less			
			
			static if (isArrayType!(T))
			{	// Show arrays inline?
				bool inl = is(ElementTypeOfArrayBuilder!(T) : real); 
				
				// dynamic array from object
				T array = (object.length > options.maxArrayLength) ? object[0..options.maxArrayLength] : object;
			
				char[] result = "[";
				if (!inl)
					result ~= options.lineReturn;
					
				foreach (int index, ElementTypeOfArrayBuilder!(T) value; array) 
				{	char[] newPath = Format("%s [{}]", path, index);
					char[] comma = index<object.length-1 ? "," : "";
					result ~= (inl ? " " : tab) ~ internalEncode(value, options, newPath) ~ comma ~ (inl ? "" : options.lineReturn);		
				}
				return result ~ (inl ? " " : tab2) ~ "]";		
			}
			else static if (isAssocArrayType!(T))
			{	KeyTypeOfAA!(T)[] keys = object.keys;
				if (keys.length > options.maxArrayLength)
					keys = keys[0..options.maxArrayLength];
			
				char[] result = "{" ~ options.lineReturn;
				
				foreach (int index, KeyTypeOfAA!(T) name; keys) 
				{	ValTypeOfAA!(T) value = object[name];
					char[] newPath = Format("%s [{}]", path, name);
					char[] comma = index<keys.length-1 ? "," : "";
					result ~= tab ~ Format("{}: ", name) ~ internalEncode(value, options, newPath) ~ comma ~ options.lineReturn;		
				}
				return result ~ tab2 ~ "}";
			}
			else static if (is(T : Object) || is(T==struct)) // class or struct
			{	
				static if (is(T : Object))
				{	if (!object)
						return "null";
					else if (options.useReferences)
					{	if (object in references)
							return references[object];						 
						references[object] = path; // store new reference
				}	}
					
				char[] result = "{" ~ options.lineReturn;
				foreach (int index, _; object.tupleof) 
				{	char[] name = shortName(object.tupleof[index].stringof);
					char[] comma = index<object.tupleof.length-1 ? "," : "";
					result ~= tab ~ name ~ ": " ~ internalEncode(object.tupleof[index], options, path~"."~name) ~ comma ~ options.lineReturn;
				}
				return result ~ tab2 ~ "}";
			} 	
			else static if (is(T : void*) && !is(T==void*)) // pointers, dereference through recursion
			{	
				if (options.currentDepth >= options.maxDepth)
					return "Max Depth Exceeded";						
				options.currentDepth++;
				
				if (!object)
					return "null";
				else if (options.useReferences && object in pointers)
					return pointers[object];
				pointers[object] = path;
				
				return internalEncode(*object);
			
			}
		}
		return "null";
	}

	private static bool isStringType(T)()
	{	static if (isArrayType!(T))
			return isCharType!(ElementTypeOfArrayBuilder!(T));
		return false;
	}

	private static char[] shortName(char[] fullyQualifiedName) {
		for (int i = fullyQualifiedName.length-1; i >= 0; i--)     
			if (fullyQualifiedName[i] == '.')
				return fullyQualifiedName[i+1..$];
		return "enum_"~fullyQualifiedName;
	}
}