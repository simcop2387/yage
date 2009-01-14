Yage can be compiled several times faster if it doesn't also have to compile derelict.
The build script (proj/buildyage.d) will build src/derelict as a lib and place it here, 
if such a lib file doesn't already exist.

Of course, if derelict is udpated, the derelict lib file in this folder should be deleted
so that a new up-to-date lib can be built.