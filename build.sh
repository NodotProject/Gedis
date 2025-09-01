#!/bin/bash
set -e

# Set full paths to compilers
export CC=/mingw64/bin/x86_64-w64-mingw32-gcc
export CXX=/mingw64/bin/x86_64-w64-mingw32-g++

# Build with verbose output
scons platform=windows target=template_release arch=$1 use_mingw=yes -j1 --debug=explain -v