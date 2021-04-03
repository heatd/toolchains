#!/bin/sh

set -e

if [ "$#" -ne "2" ]; then
	echo "Bad usage: build_llvm.sh [staging_directory] [target_directory]"
	exit 1
fi

LLVM_VER="11.0.0"

ONYX_SRCDIR=$PWD

staging_dir=$(realpath $1)
target_dir=$(realpath $2)

rm -rf $staging_dir

toolchains/download_patch_llvm.sh $staging_dir

cd $staging_dir

LLVM_SRCDIR=$PWD/llvm-project-${LLVM_VER}

mkdir build
cd build

# Don't build the linux target on other systems, since we don't provide a sysroot for linux
LINUX_OPTIONS=""

if [ uname -s = "Linux" ]; then
	LINUX_OPTIONS="-DLINUX_x86_64-unknown-linux-gnu_SYSROOT=/"
fi

using_lto="1"

if [ "$using_lto" = "1" ]; then
	LLVM_EXTRA="-DLLVM_ENABLE_LTO=ON -DLLVM_PARALLEL_LINK_JOBS=1"
else
	LLVM_EXTRA="-DLLVM_ENABLE_LTO=OFF"
fi

cmake -G Ninja -DCMAKE_BUILD_TYPE=Release \
-DLLVM_ENABLE_RTTI=ON  \
-DCMAKE_C_COMPILER=clang \
-DCMAKE_CXX_COMPILER=clang++ \
-DCMAKE_ASM_COMPILER=clang \
${LINUX_OPTIONS} \
-DONYX_SRCDIR=$ONYX_SRCDIR \
-DCMAKE_INSTALL_PREFIX= \
 ${LLVM_EXTRA} \
-DCMAKE_MODULE_PATH=${ONYX_SRCDIR}/toolchains/cmake \
-C ${LLVM_SRCDIR}/clang/cmake/caches/Onyx-stage2.cmake ${LLVM_SRCDIR}/llvm

ninja
DESTDIR=$target_dir ninja install
