/*
* This example is a modified version of the code from Jari Komppa's 'SDL Skeleton
* and Putting Pixels' tutorial (http://sol.planet-d.net/gp/ch02.html) from his
* 'Graphics For Beginners' tutorials (http://sol.planet-d.net/gp/index.html). 
* Used by permission. If you need to learn how to use SDL, his tutorials are
* a good introduction.
*/


module sdl_sample1;

import derelict.sdl.sdl;	// required to use SDL through Derelict
import std.stdio;			// for writefln

SDL_Surface* screen;		// pointer to the screen surface object

/*
* Draws individual pixels to the screen to create a funky pattern.
*/
void render()
{
	// lock the surface if needed (sometimes surfaces must be 'locked' when
	// writing directly to surface memory)
	if(SDL_MUSTLOCK(screen))
		if(SDL_LockSurface(screen) < 0)
			return;
	
	// set up for the rendering loop - current clock ticks will be used as
	// part of the rendering algorithm		
	int tick = SDL_GetTicks();
	
	// track the current yoffset when looping throught the pixels
	int yoff = 0;

	// cast the pixel buffer from a byte pointer to a uint pointer so that
	// 32 bit color values can be written to it
	uint* buff = cast(uint*)screen.pixels;

	// loop through each row of the pixel array
	for(int i=0; i<480; ++i)
	{
		// calculate the color value of each pixel in the current row
		for(int j=0, off = yoff; j<640; ++j, ++off)
		{		
			// at the start of the loop, off will equal the yoffset. This means
			// that if off is 0, the buff[off] will be the first pixel in the
			// array, or the pixel at coordinates (0,0) on screen. off is 
			// incremented each iteration, thereby moving it sequentially to
			// each pixel in the row. When this loop has completed, the yoffset
			// for the next row is calculated, the outer loop goes to the next
			// iteration, then this loop begins again at the first pixel on the
			// next row.
			buff[off] = i * i + j * j + tick;
		}
		
		// add the width of the screen (the surface pitch / bytes per pixel)
		// to the yoffset in order to move to the next row
		yoff += screen.pitch/4;
	}
	
	// unlock the screen if we had to lock it
	if(SDL_MUSTLOCK(screen))
		SDL_UnlockSurface(screen);
		
	// tell SDL to update the whole screen
	SDL_UpdateRect(screen, 0, 0, 640, 480);
}

/*
* App entry.
*/
int main()
{
	// load the SDL shared library
	DerelictSDL_Load();
	
	// Initialize SDL
	if(SDL_Init(SDL_INIT_VIDEO) < 0)
	{
		writefln("Unable to init SDL: %s", SDL_GetError());
		SDL_Quit();
		return 1;
	}
	
	// Create the screen surface (window)
	screen = SDL_SetVideoMode(640, 480, 32, SDL_SWSURFACE);
	if(screen is null)
	{
		writefln("Unable to set 640x480 video: %s", SDL_GetError());
		SDL_Quit();
		return 1;
	}	
	
	// main loop flag
	bool running = true;
	
	// main loop
	while(running)
	{
		// draw to the screen
		render();
		
		// process events
		SDL_Event event;
		while(SDL_PollEvent(&event))
		{
			switch(event.type)
			{
				// exit if SDLK or the window close button are pressed
				case SDL_KEYUP:
					if(event.key.keysym.sym == SDLK_ESCAPE)
						running = false;
					break;
				case SDL_QUIT:
					running = false;
					break;
				default:
					break;	
			}
		}
		
		// yield the rest of the timeslice
		SDL_Delay(0);
	}

	// clean up SDL
	SDL_Quit();
	return 0;
}