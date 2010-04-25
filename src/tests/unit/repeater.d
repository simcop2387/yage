module unittests.tests.repeater;

import yage.system.log;
import yage.core.repeater;


/**
 * Repeaters have previously caused a crash when compiled in debug mode */
void main () {	
	auto r = new Repeater();
	r.dispose();
	Log.trace("Creating and desposing of a Repeater didn't crash.  Test passed.");
}
