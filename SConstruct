from SCons.Script import *
import os

env = Environment(tools=['g++', 'ar', 'link'], CPPPATH=['src'])
env.Append(CPPPATH=['#src'])

# Add godot-cpp headers
env.Append(CPPPATH=['godot-cpp/include'])
env.Append(CPPPATH=['godot-cpp/gen/include'])

# Add gdextension_interface.h from root directory
env.Append(CPPPATH=['.'])

# Add godot-cpp library
env.Append(LIBPATH=['godot-cpp/bin'])
env.Append(LIBS=['godot-cpp.linux.template_debug.x86_64'])

# Ensure position-independent code for shared library
env.Append(CCFLAGS=['-fPIC'])

src_files = [
    'src/gedis.cpp',
    'src/gedis_store.cpp',
    'src/gedis_object.cpp',
    'src/register_types.cpp',
]

# Create the target directory
env.Execute(Mkdir('addons/Gedis/bin'))

# Build to the correct location expected by the .gdextension file
library = env.SharedLibrary(target='addons/Gedis/bin/libgedis', source=src_files)

Default(library)