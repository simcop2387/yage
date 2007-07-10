module yage.gui.surface;

import yage.resource.texture;
import yage.core.vector;
import yage.system.device;
import derelict.opengl.gl;

import yage.system.constant;

import std.stdio;

class Surface{
	
	
	GPUTexture texture;
	
	Surface[] subs;
	
	Vec2f portion;
	
	Vec2f topLeft;
	Vec2f bottomRight;
	
	Vec2i position;
	Vec2i position2;
	
	Vec2i size;
	
	bool mapped;

	//add root position and stuff
	
	void delegate() onResize;
	
	this(Surface parent){
		if(parent is null){
			Device.subs ~= this;
		}
		else{
			parent.subs ~= this;
		}
	}
	
	void setTexture(GPUTexture tex){
		texture = tex;
		recalculateTexture();
	}
	
	void recalculate(int width, int height){ //not done
		position.x = cast(int)(topLeft.x * cast(float)width);
		position.y = cast(int)(topLeft.y * cast(float)height);
		
		position2.x = cast(int)(bottomRight.x * cast(float)width);
		position2.y = cast(int)(bottomRight.y * cast(float)height);
		
		size.x = position2.x - position.x;
		size.y = position2.y - position.y;
		
		foreach(sub ;this.subs)	sub.recalculate(size.x, size.y);
	}
	
	void recalculateTexture(){
		portion.x = texture.requested_width/cast(float)texture.getWidth();
		portion.y = texture.requested_height/cast(float)texture.getHeight();
	}
	
	void draw(){
		recalculateTexture();
		if(mapped){
			if (texture !is null){
				// Draw a textured quad of our current material
				Texture(texture, true, TEXTURE_FILTER_BILINEAR).bind();
		
				glBegin(GL_QUADS);

				glTexCoord2f(0, 0);
				glVertex2f(position.x, bottomRight.y);
				
				glTexCoord2f(portion.x, 0); 
				glVertex2f(bottomRight.x, bottomRight.y);
				
				glTexCoord2f(portion.x, portion.y); 
				glVertex2f(bottomRight.x, topLeft.y);

				glTexCoord2f(0, portion.y);
				glVertex2f(topLeft.x, topLeft.y);

				glEnd();
			}
			foreach(sub; subs)sub.draw();
		}
	}
	
	void map(){
		mapped = true;
	}
	void unmap(){
		mapped = false;
	}
}