#!/bin/sh
# Copyright (c) 2021 Pedro Falcato
# This file is part of Onyx, and is released under the terms of the MIT License
# check LICENSE at the root directory for more information
#
# SPDX-License-Identifier: MIT
#

set -e

if [ "$#" -ne "1" ]; then
	echo "Bad usage: download_patch_llvm.sh [staging_directory]"
	exit 1
fi

LLVM_VER="13.0.0"

STAGING_DIR=$1
PATCHES=$PWD/toolchains

rm -rf $STAGING_DIR
mkdir -p $STAGING_DIR
cd $STAGING_DIR

TARBALL_NAME="llvm-project-${LLVM_VER}.src.tar.xz"

LLVM_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VER}/${TARBALL_NAME}"

wget $LLVM_URL

tar xf ${TARBALL_NAME}

mv llvm-project-${LLVM_VER}.src llvm-project-${LLVM_VER}
cd llvm-project-${LLVM_VER}
patch -p1 < $PATCHES/llvm-project-${LLVM_VER}.patch
cd ..
