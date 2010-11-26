/**
 * Copyright:  (c) 2005-2009 Eric Poggel
 * Authors:    Eric Poggel
 * License:    <a href="lgpl3.txt">LGPL v3</a>
 *
 * Import every module in the scene package.  
 * The scene package contains all Nodes types used for building a scene graph in Yage.
 * 
 * Ideally, the scene package should depend only on the core and resource packages,
 * or at least depend on other packages as minimally as possible.
 * This will allow complete abstraction of rendering and sound processing.
 */

module yage.scene.all;

public
{	import yage.scene.camera;
	import yage.scene.graph;
	import yage.scene.light;	
	import yage.scene.model;
	import yage.scene.node;
	import yage.scene.scene;
	import yage.scene.sound;
	import yage.scene.sprite;	
	import yage.scene.terrain;
	import yage.scene.visible;
}