#A backup build script for when buildme.d fails.
#Uses rebuild, available at www.dsource.org/projects/dsss
#Linux only!

cd ../src
rebuild -g -clean demo2/main.d
mv main ../bin/yage3d
cd ../proj