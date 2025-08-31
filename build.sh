#!/bin/bash

# Exit on error
set -e

# Build godot-cpp if the library doesn't exist
if [ ! -f "godot-cpp/bin/libgodot-cpp.linux.template_release.x86_64.a" ]; then
  echo "Building godot-cpp..."
  cd godot-cpp
  scons platform=linux target=template_release
  cd ..
else
  echo "godot-cpp library already built. Skipping."
fi

# Build the main project
scons
