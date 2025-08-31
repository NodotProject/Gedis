from SCons.Script import ARGUMENTS, Environment, Mkdir, Default, File, CacheDir
import os
import sys

# Resolve platform/target/arch from args (matches CI defaults)
platform = ARGUMENTS.get('platform')
if not platform:
    p = sys.platform
    if p.startswith('win'):
        platform = 'windows'
    elif p == 'darwin':
        platform = 'macos'
    else:
        platform = 'linux'

target = ARGUMENTS.get('target', 'template_release')
arch = ARGUMENTS.get('arch', 'x86_64')

# Set up the environment based on the platform
if platform == 'windows':
    # Use the MSVC compiler on Windows
    env = Environment(tools=['default', 'msvc'])
else:
    # Use the default compiler on other platforms
    env = Environment()
# Optional: enable SCons cache if SCONS_CACHE_DIR is provided (local or CI)
cache_dir = os.environ.get('SCONS_CACHE_DIR')
if cache_dir:
    CacheDir(cache_dir)
env.Append(CPPPATH=['src', '.', 'godot-cpp/include', 'godot-cpp/gen/include'])
env.Append(LIBPATH=['godot-cpp/bin'])

is_windows = platform == 'windows'
if is_windows:
    env.Append(CXXFLAGS=['/std:c++17'])
else:
    env.Append(CCFLAGS=['-fPIC'])
    env.Append(CXXFLAGS=['-std=c++17'])

lib_ext = '.lib' if is_windows else '.a'
lib_prefix = '' if is_windows else 'lib'
godot_cpp_lib = f"{lib_prefix}godot-cpp.{platform}.{target}.{arch}{lib_ext}"
env.Append(LIBS=[File(os.path.join('godot-cpp', 'bin', godot_cpp_lib))])

src_files = [
    'src/gedis.cpp',
    'src/gedis_store.cpp',
    'src/gedis_object.cpp',
    'src/register_types.cpp',
]

env.Execute(Mkdir('addons/Gedis/bin'))
library = env.SharedLibrary(target='addons/Gedis/bin/libgedis', source=src_files)
Default(library)