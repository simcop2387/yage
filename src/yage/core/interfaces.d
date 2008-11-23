/**
 * Copyright:  (c) 2005-2008 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl.txt">LGPL</a>
 */
module yage.core.interfaces;

/**
 * An interface for anything that implements timekeeping functions. */
interface ITemporal
{	
	void play(); ///
	void pause(); ///
	bool paused(); ///
	void stop(); ///
	void seek(double seconds); ///
	double tell(); ///
	
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

/**
 * An interface for anything that can be cloned via a clone() method. */
interface ICloneable
{	typeof(this) clone(); ///
}

interface IFinalizable
{	
	void finalize();
}
 