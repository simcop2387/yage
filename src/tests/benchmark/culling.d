/**
 * Copyright:  (c) 2005-2010 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Boost 1.0
 */

module tests.benchmark.culling;

import tango.core.sync.Mutex;
import tango.core.sync.ReadWriteMutex;
import yage.core.array;
import yage.core.timer;
import yage.core.math.plane;
import yage.core.math.math;
import yage.core.math.vector;
import yage.system.log;

/**
 * This is a test to benchmark how fast culling can be when working with tightly packed values placed contiguously in memory. 
 * It seems to show that culling is about 5x faster when it operates on contiguous data. */
void main()
{
	
	Timer a = new Timer(true);
	cull!(0)(1_000_000);
	Log.write(a.tell());
	
	Timer b = new Timer(true);
	cull!(128)(1_000_000);
	Log.write(b.tell());

}

struct NodePosition(int S) 
{	Vec3f position;
	void* node;
	static if (S > 0)
		float[S] otherJunk;
	
	static NodePosition opCall()
	{	NodePosition result;
		result.position = Vec3f(random(-1000, 1000), random(-1000, 1000), random(-1000, 1000));
		return result;
	}		
}

void cull(int S)(int size)
{	
	// Initialize
	NodePosition!(S)[] nodes= new NodePosition!(S)[size];
	foreach(inout node; nodes)
		node = NodePosition!(S)();
	
	auto mutex = new Object();
	auto mutex2 = new Mutex(); // also testing Tango vs D's mutex
	auto mutex3 = new ReadWriteMutex(); // also testing Tango vs D's mutex
	
	Plane[6] frustum; // just a simple 200^3 sized box
	frustum [0] = Plane(-1, 0, 0, 100);
	frustum [1] = Plane( 0,-1, 0, 100);
	frustum [2] = Plane( 0, 0,-1, 100);
	frustum [3] = Plane( 1, 0, 0, 100);
	frustum [4] = Plane( 0, 1, 0, 100);
	frustum [5] = Plane( 0, 0, 1, 100);
	
	ArrayBuilder!(void*) visibleNodes;
	foreach (node; nodes)
	{	bool visible = true; // [below] a quick test for synchronization speeds
		// none, 146 ms
		//synchronized(mutex) // 229 ms
		//mutex2.lock(); // 173ms
		//mutex3.reader().lock(); // 375 ms
		//mutex3.writer().lock(); // 374 ms
		{	foreach (f; frustum)
			{	if (f.x*node.position.x +f.y*node.position.y + f.z*node.position.z + f.d < 0)
				{	visible = false;			
					break;
				}				
			}
			if (visible)
				visibleNodes ~= node.node;
		}
		//mutex2.unlock();
		//mutex3.reader().unlock();
		//mutex3.writer().unlock();
	}
}

