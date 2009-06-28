/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */

module yage.resource.lazyresource;

import tango.io.Stdout;
import yage.core.closure;
import yage.system.system;


/**
 * This class manages a queue of operations that can only be performed in the rendering thread.
 * This should eventually be replaced with a glContext that manages openGL state and can allow synchronized OpenGL calls from any thread.
 * Alternatively, the renderer itself should be lazy and only load recources during rendering? */
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
		assert(System.isSystemThread());
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