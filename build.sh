#!/bin/bash

export PATH=/home/itachi/toolchain/clang/host/linux-x86/clang-r383902/bin:$PATH
export CROSS_COMPILE=/home/itachi/toolchain/clang/host/linux-x86/clang-r383902/bin/aarch64-linux-gnu-
export CC=/home/itachi/toolchain/clang/host/linux-x86/clang-r383902/binclang
export CLANG_TRIPLE=aarch64-linux-gnu-
export ARCH=arm64
export ANDROID_MAJOR_VERSION=r

make -C $(pwd) O=$(pwd)/out KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y LLVM=1 LLVM_IAS=1 a22x_defconfig
make -C $(pwd) O=$(pwd)/out KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y LLVM=1 LLVM_IAS=1 -j8

#cp out/arch/arm64/boot/Image $(pwd)/arch/arm64/boot/Image
