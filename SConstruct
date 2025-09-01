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
use_mingw = ARGUMENTS.get('use_mingw', 'no') == 'yes'

if platform == 'windows' and not use_mingw:
    # Use the MSVC compiler on Windows (native build)
    env = Environment(tools=['default', 'msvc'])
elif platform == 'windows' and use_mingw:
    # Use MinGW for Windows cross-compilation
    env = Environment(tools=['default', 'mingw'])
    # Ensure we use the cross-compiler if CC/CXX are set
    if 'CC' in os.environ:
        env['CC'] = os.environ['CC']
    if 'CXX' in os.environ:
        env['CXX'] = os.environ['CXX']
else:
    # Use the default compiler on other platforms
    env = Environment()
# Optional: enable SCons cache if SCONS_CACHE_DIR is provided (local or CI)
cache_dir = os.environ.get('SCONS_CACHE_DIR')
if cache_dir:
    CacheDir(cache_dir)
env.Append(CPPPATH=['src', '.', 'godot-cpp/include', 'godot-cpp/gen/include', 'godot-cpp/gdextension'])
env.Append(LIBPATH=['godot-cpp/bin'])

is_windows = platform == 'windows'
if is_windows and not use_mingw:
    # MSVC flags
    env.Append(CXXFLAGS=['/std:c++17'])
elif is_windows and use_mingw:
    # MinGW flags (similar to Linux but for Windows target)
    env.Append(CCFLAGS=['-fPIC'])
    env.Append(CXXFLAGS=['-std=c++17'])
else:
    # Linux/macOS flags
    env.Append(CCFLAGS=['-fPIC'])
    env.Append(CXXFLAGS=['-std=c++17'])

# When using MinGW for cross-compilation, we still get .a files with lib prefix
# .lib files without prefix are only used with MSVC
use_mingw = ARGUMENTS.get('use_mingw', 'no') == 'yes'
if is_windows and not use_mingw:
    lib_ext = '.lib'
    lib_prefix = ''
else:
    lib_ext = '.a'
    lib_prefix = 'lib'
godot_cpp_lib = f"{lib_prefix}godot-cpp.{platform}.{target}.{arch}{lib_ext}"
env.Append(LIBS=[File(os.path.join('godot-cpp', 'bin', godot_cpp_lib))])

src_files = [
    'src/gedis.cpp',
    'src/gedis_store.cpp',
    'src/gedis_object.cpp',
    'src/register_types.cpp',
]

env.Execute(Mkdir('addons/Gedis/bin'))

# Set the correct library suffix and prefix based on platform
if is_windows:
    # Windows shared libraries are .dll files
    env['SHLIBSUFFIX'] = '.dll'
    env['SHLIBPREFIX'] = 'lib'

# Create the library with a simple name, SCons will add the correct extension
library = env.SharedLibrary(target='addons/Gedis/bin/libgedis', source=src_files)
Default(library)