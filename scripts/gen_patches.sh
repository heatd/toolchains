#!/bin/bash
set -e
binutils_dir="$1"
gcc_dir="$2"

for d in $binutils_dir $gcc_dir; do
	echo -n "Generating patch for $d..."
	mv $d $d-patched
	tar xf ${d}.tar.xz
	find $d-patched -depth -name "autom4te.cache" -type d -exec rm -r {} \;
	diff -Naur $d $d-patched > $d.patch || true
	echo " done."
	rm -rf $d
	mv $d-patched $d
done
