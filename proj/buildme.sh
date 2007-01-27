#A backup build script for when buildme.d fails.
#Uses bud, available at www.dsource.org/projects/build
#Linux only!

cd ../src
bud -op -clean yage/main.d dl.a
cd yage
mv main ../../bin/yage
