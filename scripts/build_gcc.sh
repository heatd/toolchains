#!/bin/sh

set -e

if [ "$#" -ne "2" ]; then
	echo "Bad usage: build_gcc.sh [staging_directory] [target_directory]"
	exit 1
fi

BINUTILS_VER="2.35"
GCC_VER="10.2.0"

ONYX_SRCDIR=$PWD

staging_dir=$(realpath $1)
target_dir=$(realpath $2)

rm -rf $staging_dir

toolchains/download_and_patch_tools.sh $staging_dir

cd $staging_dir

GCC_SRCDIR=$PWD/gcc-${GCC_VER}
BINUTILS_SRCDIR=$PWD/gcc-${BINUTILS_VER}


system=$(uname -s)
case "${system}" in
Darwin*)    NPROC_UTIL="sysctl -n hw.logicalcpu";;
*)          NPROC_UTIL="nproc";;
esac

NR_THREADS=$($NPROC_UTIL)

mkdir -p binutils-build

cd binutils-build
../binutils-${BINUTILS_VER}/configure --target=x86_64-onyx --prefix=$target_dir \
--with-sysroot=$ONYX_SRCDIR/sysroot \
--disable-werror --disable-nls --enable-gold=default --enable-lto --enable-plugins
make -j $NR_THREADS
make install -j $NR_THREADS
cd ..

mkdir -p gcc-build
cd gcc-build
../gcc-${GCC_VER}/configure --target=x86_64-onyx --prefix=$target_dir \
--with-sysroot=$ONYX_SRCDIR/sysroot --enable-languages=c,c++ --disable-nls \
--enable-threads=posix --enable-libstdcxx-threads --enable-symvers=gnu --enable-default-pie \
--enable-lto --enable-default-ssp --enable-shared --enable-checking=release \
--with-bugurl=https://github.com/heatd/toolchains/issues

make all-gcc all-target-libgcc all-target-libstdc++-v3 all-target-libsanitizer -j $NR_THREADS
make install-gcc install-target-libgcc install-target-libstdc++-v3 install-target-libsanitizer -j $NR_THREADS

