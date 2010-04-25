#A backup build script for when buildyage.d fails.
#Uses rebuild, available at www.dsource.org/projects/dsss
#Linux only!

cd ../src
rebuild -g -clean demo1/main.d
mv main ../bin/yage3d
cd ../build