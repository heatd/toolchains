#!/bin/sh
# Copyright (c) 2021 Pedro Falcato
# This file is part of Onyx, and is released under the terms of the MIT License
# check LICENSE at the root directory for more information
#
# SPDX-License-Identifier: MIT
#

set -e

TEMP=$(getopt -o 'a:cT:ht:' --long 'arch:,continue,threads:,help,toolchain:,use-lto,strip,no-strip,no-libc' -n 'build_toolchain' -- "$@")

eval set -- "$TEMP"

ARCH=$(uname -m)

unset TEMP

just_continue=0

NR_THREADS=0
toolchain="GNU"
lowercase_toolchain="gnu"
use_lto="false"
strip_toolchain="yes"
enable_libc="yes"

if [ -z "$STRIP" ]; then
    export STRIP="strip"
fi

print_help()
{
    echo "Usage: build_toolchain.sh [OPTIONS] [staging directory] [target directory]"
    echo "Build a toolchain for Onyx, either GNU or LLVM, using the staging directory as a place to put build files,"
    echo "and the target directory as the destination for the toolchain."
    echo "Options:"
    echo "  -a, --arch=ARCH             Architecture for which to build the cross-toolchain. Defaults to the host architecture"
    echo "  -c, --continue              Don't wipe the staging directory and continue a previous build."
    echo "  -T, --threads=THREADS       Use THREADS threads for the builds. If 0 or unspecified, auto-detect."
    echo "  -t, --toolchain=TOOLCHAIN   Build the toolchain TOOLCHAIN. Supported values: GNU, LLVM, gnu, llvm."
    echo "                              If not specified, builds the GNU toolchain."
    echo "  --use-lto                   Compile the toolchain using LTO. Results in a faster toolchain, but a much slower build."
    echo "                              By default, the build does not use LTO."
    echo "  --strip/--no-strip          Controls the executable and library stripping of the toolchain. Stripping is on by default."
    echo "  --no-libc                   Build the toolchain without the libc. Useful for building toolchains before compiling the C library."
    echo "  -h, --help                  Show this help message."
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
        '-T'|'--threads')
            NR_THREADS=$2
            shift 2
            continue
		;;
        '-t'|'--toolchain')
            toolchain=$2
            shift 2
            continue
        ;;
        '-h'|'--help')
            print_help
            exit 0
        ;;
        '--use-lto')
            use_lto="true"
            shift
            continue
        ;;
        "--strip")
            strip_toolchain="yes"
            shift
            continue
        ;;
        "--no-strip")
            strip_toolchain="no"
            shift
            continue
        ;;
        "--no-libc")
            enable_libc="no"
            shift
            continue
        ;;
        '--')
			shift
			break
		;;
	esac
done

if [ "$#" -ne "2" ]; then
	echo "build_toolchain.sh: Bad usage"
    print_help
	exit 1
fi

# Normalise the toolchain name, and use this occasion to sanitize the toolchain.
case "${toolchain}" in
GNU|gnu)
    toolchain="GNU"
    lowercase_toolchain="gnu"
    ;;
LLVM|llvm)
    toolchain="LLVM"
    lowercase_toolchain="llvm"
    ;;
*)
    echo "build_toolchain.sh: Invalid toolchain ${toolchain}"
    print_help
    exit 1
    ;;
esac

case "${ARCH}" in
arm64|ARM64)
    # AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAARCH64 is stupid, but GNU really likes it
    ARCH="aarch64"
    ;;
esac

GNU_TARGET="$ARCH-onyx"
LLVM_VER="14.0.0"
BINUTILS_VER="2.37"
GCC_VER="11.2.0"

if [ "$toolchain" = "GNU" ]; then
    echo "Building binutils $BINUTILS_VER and gcc $GCC_VER for target $GNU_TARGET"
elif [ "$toolchain" = "LLVM" ]; then
    # TODO: Should we add a way to control which targets get built?
    echo "Building LLVM $LLVM_VER for all supported targets"
fi

ONYX_SRCDIR=$PWD

staging_dir=$(realpath $1)
target_dir=$(realpath $2)

# If we're asked to continue, skip the staging dir's removal and the download/patching
if [ "$just_continue" = "0" ]; then
    rm -rf $staging_dir
    toolchains/scripts/download_patch_${lowercase_toolchain}.sh $staging_dir
fi

cd $staging_dir

LLVM_SRCDIR=$PWD/llvm-project-${LLVM_VER}

GCC_SRCDIR=$PWD/gcc-${GCC_VER}
BINUTILS_SRCDIR=$PWD/binutils-${BINUTILS_VER}

disable_gold=0

NPROC_UTIL="nproc"

# Add some build quirks for each system 
system=$(uname -s)

llvm_build_extra_host_opts=""
llvm_build_extra=""
target_extra_binutils_options=""
target_extra_gcc_options=""

case "${system}" in
Darwin*)    NPROC_UTIL="sysctl -n hw.logicalcpu"
            disable_gold=1
            ;;
Linux*)     llvm_build_extra_host_opts="-DLINUX_x86_64-unknown-linux-gnu_SYSROOT=/"
            ;;
esac

# If -t 0 or no option was specified, auto-detect the number of threads using the system's number of processors
if [ "$NR_THREADS" = "0" ]; then
    NR_THREADS=$($NPROC_UTIL)
fi

echo "Using $NR_THREADS threads"

if [ "$toolchain" = "GNU" ]; then
    mkdir -p binutils-build

    GOLD_CONFIGURE_OPTIONS="--enable-gold=default"

    case "${ARCH}" in 
    "riscv64")
        # GNU gold doesn't support riscv
        disable_gold=1
        ;;
    esac


    if [ "$disable_gold" = "1" ]; then
       # macOS can't build gold 
        GOLD_CONFIGURE_OPTIONS="--disable-gold"
    fi

    cd binutils-build
    $BINUTILS_SRCDIR/configure --target="$GNU_TARGET" --prefix=$target_dir \
    --with-sysroot=$ONYX_SRCDIR/sysroot \
    --disable-werror --disable-nls $GOLD_CONFIGURE_OPTIONS --enable-lto --enable-plugins \
    "$target_extra_binutils_options"

    make -j $NR_THREADS
    make install -j $NR_THREADS
    cd ..

    libc_options="--enable-threads=posix --enable-libstdcxx-threads --enable-shared"
    extra_make_targets=""
    extra_install_targets=""
    compiler_runtimes="libstdc++-v3 libsanitizer"

    if [ "$enable_libc" = "no" ]; then
        libc_options="--without-headers --with-newlib --disable-shared --disable-threads"
        compiler_runtimes=""
    fi

    for runtime in $compiler_runtimes; do
        extra_make_targets="$extra_make_targets all-target-${runtime}"
        extra_install_targets="$extra_install_targets install-target-${runtime}"
    done

    mkdir -p gcc-build
    cd gcc-build
    $GCC_SRCDIR/configure --target="$GNU_TARGET" --prefix=$target_dir \
    --with-sysroot=$ONYX_SRCDIR/sysroot --enable-languages=c,c++ --disable-nls \
    $libc_options --enable-symvers=gnu --enable-default-pie \
    --enable-lto --enable-default-ssp --enable-checking=release \
    --with-bugurl=https://github.com/heatd/toolchains/issues "$target_extra_gcc_options"

    make all-gcc all-target-libgcc $extra_make_targets -j $NR_THREADS
    make install-gcc install-target-libgcc $extra_install_targets -j $NR_THREADS
elif [ "$toolchain" = "LLVM" ]; then

    if [ "$use_lto" = "true" ]; then
        llvm_build_extra="$llvm_build_extra -DLLVM_ENABLE_LTO=Thin -DLLVM_PARALLEL_LINK_JOBS=1"
    else
        llvm_build_extra="$llvm_build_extra -DLLVM_ENABLE_LTO=OFF"
    fi

    cmake -G Ninja -DCMAKE_BUILD_TYPE=Release \
    -DLLVM_ENABLE_RTTI=ON  \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_ASM_COMPILER=clang \
    ${llvm_build_extra_host_opts} \
    -DONYX_SRCDIR=$ONYX_SRCDIR \
    -DCMAKE_INSTALL_PREFIX= \
     ${llvm_build_extra} \
    -DCMAKE_MODULE_PATH=${ONYX_SRCDIR}/toolchains/cmake \
    -C ${LLVM_SRCDIR}/clang/cmake/caches/Onyx-stage2.cmake ${LLVM_SRCDIR}/llvm

    ninja distribution
    DESTDIR=$target_dir ninja install-distribution-stripped
fi

if [ "$strip_toolchain" = "yes" ]; then

# TODO: This doesn't really work for llvm and leaves some things unstripped
# This is kind of hacky, adapt llvm to use distribution and install-distribution-stripped
# Strip bin, libexec, lib
find "$target_dir/bin" -type f -exec sh -c '(! echo {} | grep -q .*.o) && (file {} | grep ELF)' \; -exec $STRIP {} \; || true
find "$target_dir/libexec" -type f -exec sh -c '(! echo {} | grep -q .*.o) && (file {} | grep ELF)' \; -exec $STRIP {} \; || true
find "$target_dir/lib" -type f -exec sh -c '(! echo {} | grep -q .*.o) && (file {} | grep ELF)' \; -exec $STRIP {} \; || true

fi
