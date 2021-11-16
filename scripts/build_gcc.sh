#!/bin/sh
# Copyright (c) 2021 Pedro Falcato
# This file is part of Onyx, and is released under the terms of the MIT License
# check LICENSE at the root directory for more information
#
# SPDX-License-Identifier: MIT
#

set -e

TEMP=$(getopt -o 'a:ct:h' --long 'arch:continue,threads:,help' -n 'build_gcc' -- "$@")

eval set -- "$TEMP"

ARCH=$(uname -m)

unset TEMP

just_continue=0

NR_THREADS=0

print_help()
{
    echo "Usage: build_gcc.sh [OPTIONS] [staging directory] [target directory]"
    echo "Build a GNU toolchain for Onyx, using the staging directory as a place to put build files,"
    echo "and the target directory as the destination for the toolchain."
    echo "Options:"
    echo "  -a, --arch=ARCH          Architecture for which to build the cross-toolchain. Defaults to the host architecture"
    echo "  -c, --continue           Don't wipe the staging directory and continue a previous build."
    echo "  -t, --threads=THREADS    Use THREADS threads for the builds. If 0 or unspecified, auto-detect."
    echo "  -h, --help               Show this help message."  
}

while true; do
	case "$1" in
		'-a'|'--arch')
			ARCH=$2
			shift 2
			continue
		;;
        '-c'|'--continue')
            just_continue=1
            shift
            continue
        ;;
        '-t'|'--threads')
            NR_THREADS=$2
            shift 2
            continue
		;;
        '-h'|'--help')
            print_help
            exit 0
        ;;
        '--')
			shift
			break
		;;
	esac
done

if [ "$#" -ne "2" ]; then
	echo "build_gcc.sh: Bad usage"
    print_help
	exit 1
fi

GNU_TARGET="$ARCH-onyx"

BINUTILS_VER="2.35"
GCC_VER="10.2.0"

echo "Building binutils $BINUTILS_VER and gcc $GCC_VER for target $GNU_TARGET"

ONYX_SRCDIR=$PWD

staging_dir=$(realpath $1)
target_dir=$(realpath $2)

# If we're asked to continue, skip the staging dir's removal and the download/patching
if [ "$just_continue" = "0" ]; then
    rm -rf $staging_dir
    toolchains/scripts/download_patch_gnu.sh $staging_dir
fi

cd $staging_dir

GCC_SRCDIR=$PWD/gcc-${GCC_VER}
BINUTILS_SRCDIR=$PWD/gcc-${BINUTILS_VER}

disable_gold=0

system=$(uname -s)
case "${system}" in
Darwin*)    NPROC_UTIL="sysctl -n hw.logicalcpu"
            disable_gold=1;;
*)          NPROC_UTIL="nproc";;
esac

# If -t 0 or no option was specified, auto-detect the number of threads using the system's number of processors
if [ "$NR_THREADS" = "0" ]; then
    NR_THREADS=$($NPROC_UTIL)
fi

echo "Using $NR_THREADS threads"

mkdir -p binutils-build

GOLD_CONFIGURE_OPTIONS="--enable-gold=default"

target_extra_binutils_options=""
target_extra_gcc_options=""

case "${ARCH}" in 
"riscv64")
    # RISCV doesn't support gold
    # We also don't support multilib due to the need for riscv32 headers
    disable_gold=1
    target_extra_gcc_options="--disable-multilib"
    ;;
esac


if [ "$disable_gold" = "1" ]; then
    # macOS can't build gold 
    GOLD_CONFIGURE_OPTIONS="--disable-gold"
fi

cd binutils-build
../binutils-${BINUTILS_VER}/configure --target="$GNU_TARGET" --prefix=$target_dir \
--with-sysroot=$ONYX_SRCDIR/sysroot \
--disable-werror --disable-nls $GOLD_CONFIGURE_OPTIONS --enable-lto --enable-plugins \
"$target_extra_binutils_options"

make -j $NR_THREADS
make install -j $NR_THREADS
cd ..

mkdir -p gcc-build
cd gcc-build
../gcc-${GCC_VER}/configure --target="$GNU_TARGET" --prefix=$target_dir \
--with-sysroot=$ONYX_SRCDIR/sysroot --enable-languages=c,c++ --disable-nls \
--enable-threads=posix --enable-libstdcxx-threads --enable-symvers=gnu --enable-default-pie \
--enable-lto --enable-default-ssp --enable-shared --enable-checking=release \
--with-bugurl=https://github.com/heatd/toolchains/issues "$target_extra_gcc_options"

make all-gcc all-target-libgcc all-target-libstdc++-v3 all-target-libsanitizer -j $NR_THREADS
make install-gcc install-target-libgcc install-target-libstdc++-v3 install-target-libsanitizer -j $NR_THREADS

