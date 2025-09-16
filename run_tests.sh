#!/bin/bash
set -e
if [ -n "$1" ]; then
    godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://test -gexit -ginclude_subdirs -gselect=$1
else
    godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://test -gexit -ginclude_subdirs "$@"
fi