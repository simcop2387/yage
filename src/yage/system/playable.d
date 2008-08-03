/**
 * 
 */
module yage.system.playable;


interface IPlayable
{
	void play();
	void pause();
	void seek(double seconds);
	double tell();
	void stop();
}