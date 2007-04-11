/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.core.horde;

import std.stdio;
import yage.core.misc;

// For unit tests
import yage.core.vector;


/**
 * A templated storage class similar to C++'s STD::Vec3f.
 *
 * Horde's performance can exceed that of STD::Vec3f for removal times,
 * at the sacrifice of not maintaining order upon removal.  It also sort its
 * members by any key in linear time via a built-in radix sort.
 *
 * Horde is probably threadsafe, but has not been tested.
 *
 * Example:
 * --------------------------------
 * Horde!(Vec3f) a = new Horde!(Vec3f);     // Create a new Horde of Vec3f's.
 * a.add(Vec3f(1, 2, 3));                   // Add elements to the Horde.
 * a.add(Vec3f(5,-2, 7));
 * a.add(Vec3f(3, 2, 1));
 * a.sort((Vec3f v) { return v.y; });       // Sort by the y value of each Vec3f.
 * --------------------------------
 **/
struct Horde(T)
{
	protected T[] elements;		// An array of all elements in the Horde, + extra length in reserve for new elements
	protected uint count=0;		// number of elements currently in the horde.
	protected uint _reserve=0;	// reserve at least this much space in the array.

	// used in unit tests
	alias Horde!(real) hr;
	alias Horde!(Vec3f) hv;

	unittest
	{/*
		alias yage.core.vector.Vec3f Vec3f;		// Quick import
		Horde!(Vec3f) a = new Horde!(Vec3f);	// Create a new
		a.add(Vec3f(1, 2, 3));
		a.add(Vec3f(5,-2, 7));
		a.add(Vec3f(3, 2, 1));
		a.sort((Vec3f v) { return v.y; });		// Sort by the y value of each Vec3f.
	*/
		//hv a = hv([Vec3f(1, 2, 3), Vec3f(6, 5, 4)]);
		//assert(a[0] == Vec3f(1, 2, 3));
		//assert(a[1] == Vec3f(6, 5, 4));

	}

	/// Construct
	static Horde!(T) opCall()
	{	Horde!(T) res;
		return res;
	}

	/// Construct and reserve size
	static Horde!(T) opCall(uint size)
	{	Horde!(T) res;
		res.elements.length = size;
		res.reserve = size;
		return res;
	}

	/// Construct from an existing array or Horde.
	static Horde!(T) opCall(T[] array)
	{	Horde!(T) res;
		res.elements = array;
		res.count = array.length;
		return res;
	}
	/// ditto
	static Horde!(T) opCall(Horde!(T) horde)
	{	return opCall(horde.array);
	}

	// Reserve more space
	private void sizeup()
	{	if (count==elements.length)
		{	int newsize = (elements.length*2+1 > _reserve ? elements.length*2+1 : _reserve);
			elements.length = newsize;
		}
	}

	// Reserve less space
	private void sizedown()
	{	if ((count < elements.length/3) && (elements.length/2 >= _reserve))
			elements.length = elements.length/2;
	}

	/// Allow Horde to be used in foreach
	int opApply(int delegate(inout T) dg)
	{   int result = 0;
		for (int i = 0; i < count; i++)
		{	result = dg(elements[i]);
			if (result)
			break;
		}
		return result;
	}

	// Allow Horde to be used in foreach
	int opApplyReverse(int delegate(inout T) dg)
	{   int result = 0;
		for (int i = count-1; i >=0; i--)
		{	result = dg(elements[i]);
			if (result)
			break;
		}
		return result;
	}

	/// Create a new Horde by concatenating other elements.
	Horde!(T) opCat(T elem)
	{	return Horde!(T)(this.elements[0..count]~elem);
	}
	/// ditto
	Horde!(T) opCat(T[] array)
	{	return Horde!(T)(this.elements[0..count]~array);
	}
	/// ditto
	Horde!(T) opCat(Horde!(T) rhs)
	{	return Horde!(T)(this.elements[0..count]~rhs.array);
	}

	/// Concatenate values onto the Horde.
	Horde!(T) opCatAssign(T elem)
	{	add(elem);
		return *this;
	}
	/// ditto
	Horde!(T) opCatAssign(T[] array)
	{	add(array);
		return *this;
	}
	/// ditto
	Horde!(T) opCatAssign(Horde!(T) rhs)
	{	add(rhs);
		return *this;
	}

	/// Get the element at index from the Horde.
	T opIndex(uint index)
	in{ assert (index<count); }
	body
	{	return elements[index];
	}

	/// Assign to the element at index in the Horde.
	T opIndexAssign(T rhs, uint index)
	{	return elements[index] = rhs;
	}

	/// Get the Horde as an array.
	T[] opSlice()
	{	return elements[0..count];
	}

	/// Return an array of T[i..j].
	T[] opSlice(uint start, uint end)
	in{ assert (start<count && end<count && start<=end); }
	body
	{	return elements[start..end];
	}

	/// Overwrite the values in the Horde.
	T[] opSliceAssign(T[] rhs)
	{	elements[] = rhs;
		count = rhs.length;
		return elements[0..count];
	}
	/// ditto
	T[] opSliceAssign(Horde!(T) rhs)
	{	return opSliceAssign(rhs.array);
	}

	/// Assign to the range of values from i to j.
	T[] opSliceAssign(T[] rhs, uint start, uint end)
	in{ assert (start<count && end<count && start<=end); }
	body
	{	return elements[start..end] = rhs;
	}
	/// ditto
	T[] opSliceAssign(Horde!(T) rhs, uint start, uint end)
	{	return opSliceAssign(rhs.array, start, length);
	}

	/**
	 * Add one or more elements to the Horde.  Elements are added by value,
	 * So if you add pointer-based element twice (like a class),
	 * both indexes in the horde will point to the same element.
	 * Returns: the index of element in the Horde. */
	uint add(T element)
	{	sizeup();
		elements[count] = element;
		count++;
		return count-1;
	}

	/// ditto
	void add(T[] elems)
	{	int old_count = count;
		count = elements.length+elems.length;
		sizeup();
		elements.length = old_count;	// sizedown
		elements ~= elems;				// append
		elements.length = maxi(old_count, elements.length);
	}

	/// ditto
	void add(Horde!(T) elems)
	{	add(elems.array());
	}

	/**
	 * Return an array containing all elements in the horde.
	 * It gets the original elements by reference and not a copy, so it's very fast. */
	T[] array()
	{	return elements[0..count];
	}

	/**
	 * Return the size of the Horde, including reserved space for new elements.
	 * When length() > capacity(), the Horde is resized larger to make room for new elements.
	 * When length() < capacity()/3, the Horde is resized smaller to free memory. */
	uint capacity()
	{	return elements.length;
	}

	/// Get and set the length of the Horde via this property, just like an array.
	uint length()
	{	return count;
	}

	/// ditto
	uint length(uint l)
	{	return count = l;
	}

	/**
	 * Remove an element from the Horde and return it.
	 * This takes constant time, or linear time if preserve_order is true.
	 * Params:
	 * index = Index of the element to remove.
	 * preserve_order = Keep all elements in the same order, at the cost of performane. */
	T remove(uint index, bool preserve_order=false)
	in{	assert(index<count); }
	body
	{	T result =  elements[index];
		if (index < count-1)
		{	if (preserve_order)	// remove element[index] and shift all after it down by one
				for (size_t i=index; i<count-1; i++)
					elements[i]=elements[i+1];
			else	// remove one from the end and overwrite element[index]
				elements[index] = elements[count-1];
		}count--;
		sizedown();
		return result;
	}

	/**
	 * Get and set the reserve size of the Horde via this property.
	 * Room for at least this many elements will always be reserved.
	 * When the number of elements exceeds the reserve size, memory has to be reallocated. */
	uint reserve()
	{	return _reserve;
	}

	/// ditto
	void reserve(uint size)
	{	_reserve = size;
		sizeup();
	}

	/// Remove every element from the Horde and reset the reserve.
	void reset()
	{	count = _reserve = 0;
		sizedown();
	}

	/// Broken
	char[] toString()
	{	char[] result;
	//	result = "Horde: <length="~.toString(count)~", capacity="~.toString(elements.length)~", reserve="~.toString(_reserve)~">\n";
		result ~= "[";
		//foreach (T; elements)
		//	result ~= .toString(T);
		result ~= "]";
		return result;
	}

	/*
	 * Sort the elements of the Horde by a key.
	 * getKey should be a function that takes an elemeent and returns a sort key
	 * for that element. */
	// These have trouble with Code::blocks' incremental compilation
	/*
	void sort(int delegate(T elem) getKey)
	{	sortType!(int).radix(getKey, false, true);
	}
	void sort(uint delegate(T elem) getKey)
	{	sortType!(uint).radix(getKey, false, false);
	}
	void sort(float delegate(T elem) getKey)
	{	sortType!(float).radix(getKey, true, true);
	}
	void sort(double delegate(T elem) getKey)
	{	sortType!(double).radix(getKey, true, true);
	}
	void sort(real delegate(T elem) getKey)
	{	sortType!(real).radix(getKey, true, true);
	}*/

	/**
	 * Specify the type of the key for a radix sort.
	 * Example:
	 * --------------------------------
	 * Horde!(Vec3f) a = new Horde!(Vec3f);
	 * a.sortType!(float).radix( (Vec3f v) { return v.x }, true, true)
	 * --------------------------------*/
	template sortType(K)
	{
		// A struct to hold our key and a pointer to our value
		struct Elem
		{	union
			{	K key2;	// The sort key is of variable size
				byte[K.sizeof] key;
			}
			T data;
		}

		/**
		 * Sort the elements of the Horde using a radix sort.
		 * This runs in linear time and can sort several million items per
		 * second on modern hardware.
		 * Special thanks go to Pierre Terdiman for his essay: Radix Sort Revisited.
		 * Params:
		 * getKey = A function to return a key of type K for each element.
		 * Float  = interpret the key data as floating point.  Use for floats, doubles, and reals.
		 * signed = interpret the key data as being signed.  Defaults to true.
		 * Example:
		 * --------------------------------
		 * Horde!(Timer) a = new Horde!(Timer);
		 * // ...
		 * a.sortType!(float).radix((Timer a) { return a.get(); }, true, false);
		 * -------------------------------- */
		void radix(K delegate(T elem) getKey, bool Float, bool signed=true)
		{
			Elem* elem_copy = cast(Elem*)std.c.stdlib.malloc(count*Elem.sizeof);
			Elem* elem = cast(Elem*)std.c.stdlib.malloc(count*Elem.sizeof);

			// Move everything into an array of structs for faster sorting.
			// This way we don't get all of the cache misses from using classes by reference.
			for (size_t i=0; i<count; i++)
			{	elem[i].key2 = getKey(elements[i]);
				elem[i].data = elements[i];
			}

			for (int k=0; k<K.sizeof; k++)
			{
				// Build histograms
				uint[256] histogram;
				for (size_t i=0; i<count; i++)
					histogram[cast(ubyte)elem[i].key[k]]++;

				// Count negative values
				uint neg;
				bool last_pass = k==K.sizeof-1;
				if (signed && last_pass)
					for (size_t i=128; i<256; i++)
						neg += histogram[i];

				// Build offset table
				uint offset[256];
				for (size_t i=0; i<255; i++)
					offset[i+1] = offset[i] + histogram[i];
				if (neg)  // only if last past and negative
				{	offset[0]=neg;
					for(int i=0; i<127; i++)
						offset[i+1] = offset[i] + histogram[i];
					offset[128]=0;
					for (int i=128; i<255; i++)
						offset[i+1] = offset[i] + histogram[i];
				}

				// Fill destination buffer
				if (!Float || !last_pass || !neg) // sort as usual
					for (size_t i=0; i<count; i++)
						elem_copy[offset[cast(ubyte)elem[i].key[k]]++] = elem[i];
				else // special case if floating point negative numbers exist
				{	int negm1 = neg-1;
					for (size_t i=0; i<count; i++)
					{	int v = elem[i].key[k];
						if (v >= 0)
							elem_copy[offset[cast(ubyte)v]++] = elem[i];
						else // put all negative numbers in reverse order, since not represented /w 2's comp
							elem_copy[negm1-offset[cast(ubyte)v]++] = elem[i];
					}
				}

				// Only not swap pointers if last pass of an odd size.
				if (!last_pass || K.sizeof % 2 == 0)
				{	Elem* temp = elem_copy;
					elem_copy = elem;
					elem = temp;
				}
			}

			// Move everything back again
			// Radix is not in place, if odd number of passes, move data back to return buffer
			if (K.sizeof % 2 == 1)
				for (size_t i=0; i<count; i++)
					elements[i] = elem_copy[i].data;
			else
				for (size_t i=0; i<count; i++)
					elements[i] = elem[i].data;

			// free memory
			std.c.stdlib.free(elem);
			std.c.stdlib.free(elem_copy);
		}
	}
}



