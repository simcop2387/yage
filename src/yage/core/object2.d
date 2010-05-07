/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */
module yage.core.object2;

import tango.math.random.Kiss;
import tango.util.Convert;
import yage.core.format;

debug {
	import tango.core.tools.TraceExceptions; // provide stack trace on error when compiled in debug mode.
}

/*
 * Unused. */
class YageObject
{}

/**
 * This is the default exception type for Yage. */
class YageException : Exception
{	
	/**
	 * Create an Exception with a message, using formatting like writefln(). 
	 * Example:
	 * --------
	 * throw new YageException("Your egg carton has %d eggs.  No more than %d eggs are supported", 13, 12);
	 * -------- 
	 */
	this(...)
	{	// TODO: Log.warn?
		super(swritef(_arguments, _argptr));
	}	
}

///
class OpenALException : YageException
{
	///
	this(...)
	{	super(swritef(_arguments, _argptr));
	}	
}

///
class ResourceException : YageException
{	
	///
	this(...)
	{	super(swritef(_arguments, _argptr));
	}	
}


/**
 * An interface for anything that can be cloned via a clone() method. */
interface ICloneable
{	Object clone(); ///
}

/**
 * Any class that has to do custom cleanup operations before destruction should implement this. */
interface IDisposable
{	
	/**
	 * Clean up resources before garbage collection that can't safely be cleaned up in a destructor.
	 * Finalize must be able to accept multiple calls, in case it is called manually and by a destroctor.
	 * After dispose is called, it's object should be considered to be in a non-usable state and ready for destruction.*/
	void dispose();
}


/**
 * Anything that implements this can act as a target for anything that
 * renders using OpenGL operations. */
interface IRenderTarget
{	
	int getWidth();
	int getHeight();
}


/**
 * An interface for anything that implements timekeeping functions. */
interface ITemporal
{	
	///
	void play();
	
	///
	void pause();
	
	///
	bool paused();
	
	///
	void stop();
	
	///
	void seek(double seconds);
	
	///
	double tell(); 
	
	/*
	Vec2f getRange(float min, float max)
	void setRange(float min, float max)
	void setPauseAfter(float time=float.infinity);
	float gePauseAfter();
	void onPauseAfter(void delegate() pause_after_func); // Can this be implemented w/o setTimeout?	
	void delegate() onPauseAfter();
	 */
	
	
	/*
	// Itemporal will be implemented by:	
	Timer
	Repeater (loop makes no sense)
	Scene (loop makes little sense)
	SoundNode
	ModelNode
	AnimatedTexture
	*/
}