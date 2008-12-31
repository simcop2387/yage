/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.lazyresource;

import yage.core.closure;
import yage.system.device;


/**
 * This class manages a queue of operations that can only be performed in the rendering thread.*/
class LazyResourceManager
{
	protected static Closure[] queue;
	protected static Object queue_mutex;
	
	static this()
	{	queue_mutex = new Object();		
	}
	
	/**
	 * Process the queues. */
	static void processQueue()
	in {
		assert(Device.isDeviceThread());
	}
	body
	{	synchronized(queue_mutex)
		{	foreach(func; queue)
				func.call();
			queue.length = 0;
		}
	}
	
	/**
	 * Add an operation to perform in the rendering thread just before rendering. */
	static void addToQueue(Closure c)
	{	 synchronized(queue_mutex) queue ~= c;
	}	
}