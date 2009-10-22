/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.core.freelist;

/**
 * A class to allow fast allocations / de-allocations, using a free list.
 * This can be several times faster than new and delete.
 * Inherit from this class and instantiate it as the same type as the class it's used in.
 * Example:
 * --------------------------------
 * class Node : FreeList!(Node)
 * { ...
 * }
 * Node a = Node.allocate();  // Pull from the freelist if available or allocate a new one if not.
 * Node.free(a);              // a is placed on the global freelist ready for the next allocation.
 * --------------------------------*/
class FreeList(T)
{
	// Used for fast allocations / frees.
    private static T freelist;		// points to the end of the free list
    private T next;

	/** Used to quickly allocate a new type T.
	 *  Note that the values of the new type T will contain memory garbage and needs to be set.*/
    static T allocate()
    {	if (freelist)
		{	T hello;
			hello = freelist;
			freelist = hello.next;
			return hello;
		}else
			return new T();
    }

	/// Place one or more type T back on a free list for the next allocation.
	static void free(T[] args ...)
    {	foreach(T a; args)
		{	a.next = freelist;
			freelist = a;
		}
    }

}
