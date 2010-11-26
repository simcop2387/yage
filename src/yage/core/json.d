/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.core.json;

import tango.core.Traits;
import yage.system.log;
import yage.core.misc;


/// TODO: This fails for base classes!
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
		bool useReferences = false; /// Print a reference to an object instead of adding it more than once.
		
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
				bool inl = is(ElementTypeOfArray!(T) : real); 
				
				// dynamic array from object
				T array = (object.length > options.maxArrayLength) ? object[0..options.maxArrayLength] : object;
			
				char[] result = "[";
				if (!inl)
					result ~= options.lineReturn;
				
				//static if (!is(ElementTypeOfArray!(T) : void))				
					foreach (int index, ElementTypeOfArray!(T) value; array) 
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
			return isCharType!(ElementTypeOfArray!(T));
		return false;
	}

	private static char[] shortName(char[] fullyQualifiedName) {
		for (int i = fullyQualifiedName.length-1; i >= 0; i--)     
			if (fullyQualifiedName[i] == '.')
				return fullyQualifiedName[i+1..$];
		return "enum_"~fullyQualifiedName;
	}
	
	unittest
	{
		class A
		{
			bool Bool = true;
			byte Byte = -1;
			ubyte UByte = 1;
			short Short = -2;
			ushort UShort = 2;
			protected int Int = -3;
			private uint UInt = 3;
			long Long = -4;
			ulong ULong = 4;
			float Float = 5.0;
			double Double = 6.0;
			real Real = 7.0;
			
			float* floatPtr;
			float[4] staticArray;
			
			void* v;
			//void[] v2; // TODO
			
			enum EnumType
			{	A,
				B
			}	
			EnumType enum1 = EnumType.A;
			EnumType enum2 = EnumType.B;
			
			struct StructType
			{	B b;
				float c;
			}
			StructType Struct;
			
			char[] String = "Hello World";
			char[] wString = "Hello World";
			char[] dString = "Hello World";
			float[] floatArray;
			int[int] aa;
			
			class B
			{	int i2 = 1234;
				int[int] aa2;	
			}	
			B b;
			B bRef;
			B nullRef;
			A selfRef;
			
			this()
			{	
				floatPtr = new float;
				*floatPtr = 5.0f;
			
				floatArray = [11f, 12f, 12f, 15.51234f];
				aa = [3:2, 1:4];
				b = new B();
				bRef = b;
				selfRef = this;
			}
		}
		class C : A
		{	int test=5;
		}
	}
}