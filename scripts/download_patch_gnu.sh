#!/bin/sh
# Copyright (c) 2021 Pedro Falcato
# This file is part of Onyx, and is released under the terms of the MIT License
# check LICENSE at the root directory for more information
#
# SPDX-License-Identifier: MIT
#

set -e

if [ "$#" -ne "1" ]; then
	echo "Bad usage: download_and_patch_tools.sh [staging_directory]"
	exit 1
fi

BINUTILS_VER="2.43.1"
GCC_VER="14.2.0"

STAGING_DIR=$1
PATCHES=$PWD/toolchains

mkdir -p $STAGING_DIR
cd $STAGING_DIR

MIRROR_BASE=$(curl -I -Ls -o /dev/null -w %{url_effective} http://ftpmirror.gnu.org/)

echo "ftpmirror.gnu.org picked mirror $MIRROR_BASE"

BINUTILS_URL="${MIRROR_BASE}/binutils/binutils-$BINUTILS_VER.tar.xz"

GCC_URL="${MIRROR_BASE}/gcc/gcc-$GCC_VER/gcc-$GCC_VER.tar.xz"

curl -O $BINUTILS_URL
curl -O $GCC_URL

rm -rf $BINUTILS_VER
rm -rf $GCC_VER

tar xf binutils-${BINUTILS_VER}.tar.xz
tar xf gcc-${GCC_VER}.tar.xz

cd binutils-$BINUTILS_VER
patch -p1 < $PATCHES/binutils-$BINUTILS_VER.patch
cd ..

cd gcc-$GCC_VER
patch -p1 < $PATCHES/gcc-$GCC_VER.patch
cd ..
