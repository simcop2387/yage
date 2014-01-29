This folder contains tests for Yage.

system
	Larger and more interesting demos for testing all of yage's functionality working together.
	
integration
	Demos to test specific parts of yage, such as lighting or sound.
	
unit
	Small tests for very specific functionality, like a sorting function.
	Normally, these tests are included inline in unittest{} blocks, but some tests
	(e.g. those that use threads) have to be separated.
	
benchmark
	Similar to unit tests, but these test the performance of lower-level operations,
	often testing one algorithm against another.