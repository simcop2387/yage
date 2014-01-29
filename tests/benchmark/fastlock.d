/**
 * Copyright:  (c) 2005-2010 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Boost 1.0
 */

module tests.unit.fastlock;

import tango.core.Thread;
import tango.core.sync.Mutex;
import tango.io.Stdout;

import yage.core.misc;
import yage.core.timer;
import yage.system.log;

int[5] array;
Object sync;
Mutex mutex;
FastLock fastLock;

void mayhem()
{	for (int i=0; i<100000; i++)
		foreach (ref a; array)
			a++;
}

void syncd()
{	for (int i=0; i<100000; i++)
		synchronized(sync)
			foreach (ref a; array)
				a++;
}

void locked()
{	
	for (int i=0; i<100000; i++)
	{	mutex.lock();
		foreach (ref a; array)
			a++;
		mutex.unlock();
	}
}


void fast()
{	for (int i=0; i<100000; i++)
	{	fastLock.lock();
		foreach (ref a; array)
			a++;
		fastLock.unlock();
	}
}

void syncdNested()
{	synchronized(sync)
		for (int i=0; i<100000; i++)		
			synchronized(sync)
				foreach (ref a; array)
					a++;
}

void lockedNested()
{	mutex.lock();
	for (int i=0; i<100000; i++)
	{	mutex.lock();
		foreach (ref a; array)
			a++;
		mutex.unlock();
	}
	mutex.unlock();
}

void fastNested()
{	fastLock.lock();
	for (int i=0; i<100000; i++)
	{	fastLock.lock();
		foreach (ref a; array)
			a++;
		fastLock.unlock();
	}
	fastLock.unlock();
}

void test(void function() func)
{	auto thread1 = new Thread(func);
	auto thread2 = new Thread(func);
	
	Timer a = new Timer(true);
	thread1.start();
	thread1.join();
	thread2.start();
	
	
	thread2.join();
	Log.write(array, " ", a.tell());
	array[] = 0;
}

// Shows that fastLock is fastest for nested locking in release builds.
// (It barely incurs any penalty over the mayhem version).
// However, mayhem is 3 times faster when using only one thread.
void main()
{
	sync = new Object();
	mutex = new Mutex();
	fastLock = new FastLock();
	
	test(&mayhem);
	test(&syncd);
	test(&locked);
	test(&fast);
	test(&syncdNested);
	test(&lockedNested);
	test(&fastNested);
}