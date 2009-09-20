module unittests.tests.repeater;

import tango.io.Stdout;
import yage.core.repeater;


/**
 * Repeaters have previously caused a crash when compiled in debug mode */
void main () {	
	auto r = new Repeater();
	r.dispose();
	Stdout("Creating and desposing of a Repeater didn't crash.");
}
