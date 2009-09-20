/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 */

module yage.resource.resource;

import yage.core.array;
import yage.core.object2;

abstract class Resource : YageObject, IDisposable
{
	override void dispose()
	{		
	}
}

class ExternalResource : Resource
{
	protected static ExternalResource[ExternalResource] all;
	
	/// Get a list of all GPUTextures that have been created but not disposed. 
	static ExternalResource[ExternalResource] getAll()
	{	return all;
	}
	
	this()
	{	all[this] = this;		
	}
	
	void dispose()
	{	if (this in all)
			all.remove(this);
	}
}