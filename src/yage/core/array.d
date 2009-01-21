/**
 * Copyright:  (c) 2005-2009 Eric Poggel
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
import std.random;
import yage.core.types;
import yage.core.timer;

/**
 * Add an element to an already sorted array, maintaining the same sort order. 
 * Params:
 *     array = The array to use.
 *     value = Value to add.
 *     increasing = The elements are stored in increasing order.
 *     getKey = A function to return a key of type K for each element.
 *     			K must be either a primitive type or a type that impelments opCmp.
 *              Only required for arrays of classes and structs. */
void addSorted(T)(inout T[] array, T value, bool increasing=true)
{	addSorted(array, value, increasing, (T a) { return a; });
}
/// ditto
void addSorted(T,K)(inout T[] array, T value, bool increasing, K delegate(T elem) getKey, int max_length=int.max)
{
	if (!array.length)
	{	array ~= value;
		return;		
	}
	
	K key_value = getKey(value);
	if (array.length < max_length) // increase the length
		array.length = array.length+1; // [below] If fixed length and no place to add, immediately return.
	else if (increasing ? key_value > getKey(array[length-1]) : key_value < getKey(array[length-1]))
		return;
	
	// Despite two loops, this still runs in worst-case O(n)
	for (int i=0; i<array.length-1; i++) // TODO: Use a binary search instead of linear.
	{	if (increasing ? key_value <= getKey(array[i]) : key_value >= getKey(array[i]))
		{	for (int j=array.length-2; j>=i; j--) // Shift all elements forward
				array[j+1] = array[j];			
			array[i] = value;
			return;
	}	}

	array[length-1] = value;
}
unittest
{	float[] array;
	array.addSorted(yage.core.types.dword(std.random.rand()).f);
	array.addSorted(yage.core.types.dword(std.random.rand()).f);
	array.addSorted(yage.core.types.dword(std.random.rand()).f);
	array.addSorted(yage.core.types.dword(std.random.rand()).f);
	assert(array.sorted());	
	array.length = 0;
	array.addSorted(yage.core.types.dword(std.random.rand()).f, false);
	array.addSorted(yage.core.types.dword(std.random.rand()).f, false);
	array.addSorted(yage.core.types.dword(std.random.rand()).f, false);
	array.addSorted(yage.core.types.dword(std.random.rand()).f, false);
	assert(array.sorted(false));
}



/// Return the element with the minimum or maximum value from an unsorted array.
T amax(T)(T[] array, )
{	T m = array[0];
	foreach (T a; array)
		if (a>m)
			m=a;	
	return m;
}
/// ditto
T amax(T, K)(T[] array, K delegate(T elem) getKey)
{	T m = array[0];
	K mk = getKey(array[0]);
	foreach (T a; array)
		if (getKey(a)>mk)
			m=a;	
	return m;
}
/// ditto
T amin(T)(T[] array)
{	T m = array[0];
	foreach (T a; array)
		if (a<m)
			m=a;	
	return m;
}
/// ditto
T amin(T, K)(T[] array, K delegate(T elem) getKey)
{	T m = array[0];
	K mk = getKey(array[0]);
	foreach (T a; array)
		if (getKey(a)<mk)
			m=a;	
	return m;
}

/**
 * Get the maximum n elements in an unsorted array.
 * Params:
 *     array = array to search.
 *     number = number of elements to find.
 *     lookup = Function used to lookup values in arrays of classes and structs
 *     min = do not return any values that are this value or less.
 * Returns: An unsorted array of length number. */
T[] maxRange(T, K/* : real*/)(T[] array, int number, K delegate(T elem) getKey, K min=-K.infinity)
in {
	assert(number <= array.length);
}
out (result)
{	assert (result.length == number);	
}
body
{
	struct Map
	{	T elem;
		K value;
	}
	
	Map[] array2 = new Map[array.length];	
	foreach (i, inout s; array2)
	{	s.elem = array[i];
		s.value = getKey(array[i]);
	}
	
	Map[] result2 = new Map[number];
	foreach (inout r; result2)
		r.value = min;
	
	// TODO: This could be greatly sped up using a heap, such as Tango's util.container.more.Heap.
	int min_index=0;
	int getMinIndex()
	{	for (int i=0; i<result2.length; i++)
			if (result2[i].value < result2[min_index].value)
				min_index = i;		
		return min_index;		
	}
	
	for (int i=0; i<array2.length; i++)
		if (array2[i].value > result2[min_index].value)
		{	if (result2[min_index].value > min || min_index == result2.length-1)
			{	result2[min_index] = array2[i];
				min_index = getMinIndex();
			} else
			{	result2[min_index] = array2[i];
				min_index++;
		}	}	
	
	// Copy results from the map array back to the result array
	T[] result = new T[number];	
	foreach (i, r; result2)
		result[i] = r.elem;
	
	return result;
}
unittest
{	class Foo
	{	float a;
		this (float a) { this.a = a; }
	}

	{
		Foo[] test;
		for (int i=0; i<1000; i++)
			test ~= new Foo((rand()-cast(float)rand())/rand());
	
		auto max = maxRange(test, 100, (Foo f){return f.a;} );
		max.radixSort(true, (Foo f){return f.a;});
		test.radixSort(true, (Foo f){return f.a;});
		test = test[length-max.length..length];
		assert(max == test);
	}
	{	// same as above, but tests a min value argument.
		Foo[] test;
		for (int i=0; i<1000; i++)
			test ~= new Foo((rand()-cast(float)rand())/rand());
	
		auto max = maxRange(test, 100, (Foo f){return f.a;}, 0.3f);
		max.radixSort(true, (Foo f){return f.a;});
		test.radixSort(true, (Foo f){return f.a;});
		test = test[length-max.length..length];
		assert(max == test);
		foreach (t; test)
			assert(t.a>0.3f);
	}
}

T[] maxRange(T)(T[] array, int number) /// ditto
in 
{	assert(number <= array.length);
}
out (result)
{	assert (result.length == number);	
}
body
{
	T[] result = new T[number];
	foreach (inout r; result)
		r = -T.infinity;
	
	// TODO: This could be greatly sped up using a heap, such as Tango's util.container.more.Heap.
	int min_index=0;
	int getMinIndex()
	{	for (int i=0; i<result.length; i++)
			if (result[i] < result[min_index])
				min_index = i;		
		return min_index;		
	}
	
	for (int i=0; i<array.length; i++)
		if (array[i] > result[min_index])
		{	if (result[min_index] != -T.infinity || min_index == result.length-1)
			{	result[min_index] = array[i];
				min_index = getMinIndex();
			} else
			{	result[min_index] = array[i];
				min_index++;
		}	}

	return result;
}
unittest
{	float[] test;
	for (int i=0; i<1000; i++)
		test ~= (rand()-cast(float)rand())/rand();

	auto max = maxRange(test, 100);
	max.radixSort();
	test.radixSort();	
	test = test[length-max.length..length];
	assert(max == test);
}


/**
 * Is the array sorted?
 * Params:
 * increasing = Check for ordering by small to big.
 * getKey = A function to return a key of type K for each element.
 *          Only required for arrays of classes and structs.
 * Example:
 * --------------------------------
 * Timer[] array;
 * // ... fill array with new Timer() ...
 * array.sorted(true, (Timer a) { return a.get(); }); // should return true
 * -------------------------------- 
 */ 
bool sorted(T)(T[] array, bool increasing=true)
{	return sorted(array, increasing, (T a) { return a; });
}

/// Ditto
bool sorted(T, K)(T[] array, bool increasing, K delegate(T elem) getKey)
{	if (array.length <= 1)
		return true;
	
	if (increasing)
	{	for (int i=0; i<array.length-1; i++)
			if (getKey(array[i]) > getKey(array[i+1]))
				return false;
	} else
	{	for (int i=0; i<array.length-1; i++)
			if (getKey(array[i]) < getKey(array[i+1]))
				return false;		
	}				
	return true;
}
unittest
{	assert(sorted([-1, 0, 1, 2, 2, 5]) == true);
	assert(sorted([-1, 0, 1, 2, 1, 5]) == false);
	assert(sorted([5, 3, 3, 3, 2, -1], false) == true);
}

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
 * -------------------------------- 
 */
void radixSort(T)(inout T[] array, bool increasing=true)
{	radixSort(array, increasing, (T a) { return a; });
}

/// ditto
void radixSort(T, K)(inout T[] array, bool increasing, K delegate(T elem) getKey, bool signed=true)
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
		offset[0]=neg;
		for(int i=0; i<127; i++)
			offset[i+1] = offset[i] + histogram[i];
		if (neg)  // only if last past and negative
			offset[128]=0;
		else
			offset[128] = offset[127] + histogram[127];
		for (int i=128; i<255; i++)
			offset[i+1] = offset[i] + histogram[i];

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
	// If odd number of passes, move data back to return buffer
	if (increasing)
	{	static if (K.sizeof % 2 == 1)
			for (size_t i=0; i<count; i++)
				array[i] = elem_copy[i].data;
		else
			for (size_t i=0; i<count; i++)
				array[i] = elem[i].data;
	}
	else
	{	static if (K.sizeof % 2 == 1)
			for (size_t i=0; i<count; i++)
				array[count-i-1] = elem_copy[i].data;
		else
			for (size_t i=0; i<count; i++)
				array[count-i-1] = elem[i].data;
	}

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
	test2.radixSort(false);
	assert(test2 == [7, 5, 3, 2, 0, -1, -4]);
	
	// Sort doubles
	double[] test3 = [3.0, 5, 2, 0, -1, 7, -4];
	test3.radixSort();
	assert(test3 == [-4.0, -1, 0, 2, 3, 5, 7]);
	
	// large array of +- floats	
	float[] test4;
	for (int i=0; i<10000; i++)
		test4 ~= (rand()-cast(float)rand())/rand();
	Timer a = new Timer();
	test4.radixSort();
	assert(test4.sorted());
}