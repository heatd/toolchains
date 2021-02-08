#!/bin/sh
set -e

if [ "$#" -ne "1" ]; then
	echo "Bad usage: download_and_patch_tools.sh [staging_directory]"
	exit 1
fi

BINUTILS_VER="2.35"
GCC_VER="10.2.0"

STAGING_DIR=$1
PATCHES=$PWD/toolchains

mkdir -p $STAGING_DIR
cd $STAGING_DIR

BINUTILS_URL="https://mirrors.up.pt/pub/gnu/binutils/binutils-$BINUTILS_VER.tar.xz"

GCC_URL="ftp://ftp.uvsq.fr/pub/gcc/releases/gcc-$GCC_VER/gcc-$GCC_VER.tar.xz"

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
