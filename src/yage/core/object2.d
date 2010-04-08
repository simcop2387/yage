/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */
module yage.core.object2;

import tango.math.random.Kiss;
import tango.util.Convert;
import yage.core.format;

import tango.core.tools.TraceExceptions; // provide stack trace on error when compiled in debug mode.

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




///
interface IBindable
{	void bind(); ///
	void unbind(); ///
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
 * Interface for any resource that has an external component outside of D memory, such as an OpenGL Texture. */
interface IExternalResource : IDisposable
{
	/// Initializes the external part of the resource.  This function must support multiple calls.
	void commit();
	
	/// Destroyes the external part of the resource.  This function must support multiple calls.
	void dispose();
	
	/// Get an id that is used to reference the external part of the resource.  This will be 0 if the external part doesn't exist.
	uint getId();
	
	/// Get a self-indexed associative array of all of this external resource type.  This is useful for cleanup.
	static IExternalResource[IExternalResource] getAll(); // note that static interface members aren't enforced!
	
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