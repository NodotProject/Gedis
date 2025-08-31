#!/bin/bash
cd "addons/Gedis" && scons -Q && cd ../../
godot --headless -s res://addons/gut/gut_cmdln.gd -gdir=res://test -gexit -ginclude_subdirs