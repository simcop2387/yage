/**
 * Copyright:  (c) 2005-2007 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 * 
 * Array operation functions that are either not part of,
 * or improved from the standard library.
 * 
 * Note that they can also be accessed by arrayname.function().
 * 
 * Example:
 * --------------------------------
 * // Removing
 * int[] numbers = [0, 1, 2];
 * numbers.remove(0); // numbers is now [0, 1];
 */
module yage.core.array;

import std.stdio;

/**
 * 
 */

/**
 * Remove an element from an array.
 * This takes constant time, or linear time if ordered is true.
 * Params:
 *     array    = The array to use.
 *     index    = Index of the element to remove.
 *     ordered  = Keep all elements in the same order, at the cost of performance. */
void remove(T)(inout T[] array, int index, bool ordered=true)
{	if (ordered)
		for (size_t i=index; i<array.length-1; i++)
			array[i]=array[i+1];
	else
		array[index] = array[length-1];
	array.length=array.length-1;
}

/**
 * Reserve space inside the array.
 * Params:
 *     array  = The array in which to reserve space.
 *     length = The array will reserve enough space to hold this many total elements. */
void reserve(T)(inout T[] array, int length)
{	int old = array.length;
	array.length = length;
	array.length = old;	
}


/**
 * Sort the elements of an array using a radix sort.
 * This runs in linear time and can sort several million items per second on modern hardware.
 * Special thanks go to Pierre Terdiman for his essay: Radix Sort Revisited.
 * Params:
 *     getKey = A function to return a key of type K for each element.
 *              Only required for arrays of classes and structs.
 *     signed = interpret the key data as being signed.  Defaults to true.
 * Example:
 * --------------------------------
 * Timer[] array;
 * // ... fill array with new Timer() ...
 * array.radixSort((Timer a) { return a.get(); });
 * -------------------------------- */
void radixSort(T)(inout T[] array)
{	radixSort(array, (T a) { return a; });
}

/// ditto
void radixSort(T, K)(inout T[] array, K delegate(T elem) getKey, bool signed=true)
{	// Are we sorting floats?
	bool isfloat = false;
	static if (is(K == float) || is(K == double) || is(K == real) || 
		is(K ==ifloat) || is(K ==idouble) || is(K ==ireal) ||	// Not sure if these will work.
		is(K ==cfloat) || is(K ==cdouble) || is(K ==creal))
		isfloat = true;
	
	// A struct to hold our key and a pointer to our value
	struct Elem
	{	union
		{	K key2;	// The sort key is of variable size
			byte[K.sizeof] key;
		}
		T data;
	}	
	
	// Perform the radix sort.
	int count = array.length;
	Elem* elem_copy = cast(Elem*)std.c.stdlib.malloc(count*Elem.sizeof);
	Elem* elem = cast(Elem*)std.c.stdlib.malloc(count*Elem.sizeof);

	// Move everything into an array of structs for faster sorting.
	// This way we don't get all of the cache misses from using classes by reference.
	for (size_t i=0; i<count; i++)
	{	elem[i].key2 = getKey(array[i]);
		elem[i].data = array[i];
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
		if (!isfloat || !last_pass || !neg) // sort as usual
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
	static if (K.sizeof % 2 == 1)
		for (size_t i=0; i<count; i++)
			array[i] = elem_copy[i].data;
	else
		for (size_t i=0; i<count; i++)
			array[i] = elem[i].data;

	// free memory
	std.c.stdlib.free(elem);
	std.c.stdlib.free(elem_copy);
}

unittest 
{
	// Remove
	int[] test1 = [0, 1, 2, 3, 4];
	test1.remove(0);
	test1.remove(4);
	assert(test1 == [1, 2, 3]);
	test1.remove(0, false);
	assert(test1 == [3, 2]);
	
	// Sort ints
	int[] test2 = [3, 5, 2, 0, -1, 7, -4];
	test2.radixSort();
	assert(test2 == [-4, -1, 0, 2, 3, 5, 7]);
	
	// Sort doubles
	double[] test3 = [3.0, 5, 2, 0, -1, 7, -4];
	test3.radixSort();
	assert(test3 == [-4.0, -1, 0, 2, 3, 5, 7]);	
}