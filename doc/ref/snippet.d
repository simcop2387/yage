void remove(T)(inout T[] array, size_t pos)
{	foreach (idx, inout elem; array[pos..$])
		elem=array[pos..$][idx+1];
	array.length=array.length-1;
}