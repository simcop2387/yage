#A backup build script for when buildme.d fails.
#Uses bud, available at www.dsource.org/projects/build
#Linux only!

cd ../src
bud -op -clean demo1/main.d dl.a
cd demo1
mv main ../../bin/yage
cd ../../proj
