module yage.core.fastmap;

import yage.core.array;

/**
 * Behaves the same as a built-in associative array except for the following space-for-time tradeoffs:
 * <ul>
 *     <li>The .keys and .values properties execute in O(1) and perform no allocation.</li>
 *     <li>Iterating over the array is about 80% faster.</li>
 * </ul>
 * A .dup property has also been added.
 * 
 * Example:
 * -------
 * FastMap!(char[], Foo) fooMap;
 * fooMap["key"] = new Foo();
 * foreach(key, value; fooMap) {}
 * -------
 */
struct FastMap(K, V)
{
	private size_t[K] map; // a map from keys to their array index.
	private Array!(K) k; // keys
	private Array!(V) v; // values
	
	invariant {
		assert(k.length == v.length);
	}

	/**
	 * Perform a deep copy of the chain and its key value arrays. */
	FastMap!(K, V) dup()
	{	FastMap!(K, V) result;
		result.k = k.dup;
		result.v = v.dup;
		for (int i=0; i<k.length; i++)
			map[k[i]] = i;
		return result;		
	}
	
	///
	K[] keys()
	{	return k.data; // O(1)
	}	
	
	///
	size_t length()
	{	return v.length;		
	}
	
	///
	int opApply(int delegate(ref V) dg)
    {   int result = 0;
    	auto v = values;
    	int l = v.length;
    	
		for (int i=0; i<l; i++)
		{	if (dg(v[i]))
				break;
		}
		return result;
    }
	
	
	///
	V opIndex(K key)
	{	return values[map[key]];
	}
	
	///
	V opIndexAssign(V value, K key)
	{	size_t* index = key in map;
		if (!index)
		{	k ~= key;
			v ~= value;
			map[key] = v.length - 1;
		} else
			values[*index] = value;
		return value;
	}
	unittest
	{	FastMap!(int, int) map;
		map[0] = 12;
		map[5] = 13;
		assert(map[0] == 12);
		assert(map[5] == 13);
	}
	
	///
	/*
	V* op_in(K key)
	{	size_t* index = key in map;
		return index ? values[*index] : null;
	}
	*/

	///
	void rehash()
	{	map.rehash;		
	}
	
	///
	V[] values()
	{	return v.data; // O(1)
	}
}