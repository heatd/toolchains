#!/bin/sh
set -e

if [ "$#" -ne "1" ]; then
	echo "Bad usage: download_patch_llvm.sh [staging_directory]"
	exit 1
fi

LLVM_VER="11.0.0"

STAGING_DIR=$1
PATCHES=$PWD/toolchains

mkdir -p $STAGING_DIR
cd $STAGING_DIR

LLVM_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-11.0.0/llvm-project-11.0.0.tar.xz"

curl -O $LLVM_URL

rm -rf llvm-project-${LLVM_VER}

tar xf llvm-project-${LLVM_VER}.tar.xz

cd llvm-project-${LLVM_VER}
patch -p1 < $PATCHES/llvm-project-${LLVM_VER}.patch
cd ..
