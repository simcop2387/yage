/**
 * Copyright:  (c) 2005-2010 Eric Poggel
 * Authors:    Eric Poggel
 * License:    Boost 1.0
 */

module unittests.tests.repeater;

import yage.system.log;
import yage.core.repeater;


/**
 * Repeaters have previously caused a crash when compiled in debug mode */
void main () {	
	auto r = new Repeater(() {});
	r.dispose(); 
	Log.write("Creating and disposing of a Repeater didn't crash.  Test passed.");
}
