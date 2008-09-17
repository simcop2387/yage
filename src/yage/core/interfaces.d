/**
 * 
 */
module yage.core.interfaces;

interface ITemporal
{	
	void play();
	void pause();
	bool paused();
	void stop();
	void seek(double seconds);
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
	// Alternate approach
	void setTime(float amount); // get / set the time (seek/tell)
	float getTime()	
	void setPlaying(bool playing) // get / set whether the timer is paused.
	bool getPlaying()
	
	Vec2f loop(float min=0, float max=float.infinity);
	float stopAfter(float time=float.infinity);
	void delegate() onStopAfter; // Can this be implemented w/o setTimeout?	
	
	// Itemporal will be implemented by:	
	Timer
	Repeater (loop makes no sense)
	Scene (loop makes little sense)
	SoundNode
	ModelNode
	AnimatedTexture
	*/
}