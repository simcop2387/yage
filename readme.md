Layout
======

    ./doc       DDoc generated html documentation files (Out of date)
    ./lib       Static library files built from src
    ./res       Resource files (models, textures, sounds, fonts)
    ./src       Source code for yage library
    ./demo*     Examples of Yage games

Building
========

All building is done with dub build.  The following packages will build the various parts of yage

    yage - Main library put into lib/libyage.a
    yage:demo1 - First demo, put into ./yage_demo1
    yage:demo2 - Second demo, put into ./yage_demo2
    yage:demo3 - Third demo, put into ./yage_demo3
