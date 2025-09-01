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
    
    # For MSYS2 environment, we need to use full paths to the compilers
    # because SCons executes them in a different shell context
    if 'CC' in os.environ and 'CXX' in os.environ:
        # Use environment variables if they're set (from CI)
        cc_cmd = os.environ['CC']
        cxx_cmd = os.environ['CXX']
        
        # If they're just command names, try to find full paths
        if not os.path.isabs(cc_cmd):
            # Try common MSYS2 locations first
            msys2_paths = ['/mingw64/bin', '/usr/bin']
            for path in msys2_paths:
                full_cc_path = os.path.join(path, cc_cmd)
                full_cxx_path = os.path.join(path, cxx_cmd)
                if os.path.exists(full_cc_path) and os.path.exists(full_cxx_path):
                    cc_cmd = full_cc_path
                    cxx_cmd = full_cxx_path
                    break
            else:
                # Try using 'which' as fallback
                import subprocess
                try:
                    cc_cmd = subprocess.check_output(['which', cc_cmd], universal_newlines=True).strip()
                    cxx_cmd = subprocess.check_output(['which', cxx_cmd], universal_newlines=True).strip()
                except (subprocess.CalledProcessError, FileNotFoundError):
                    # Keep the original command names as last resort
                    pass
        
        env['CC'] = cc_cmd
        env['CXX'] = cxx_cmd
        print(f"Using MinGW compilers: CC={cc_cmd}, CXX={cxx_cmd}")
    else:
        # Fallback: try to find MinGW compilers in standard locations
        mingw_locations = [
            '/mingw64/bin/x86_64-w64-mingw32-gcc',
            '/usr/bin/x86_64-w64-mingw32-gcc',
            'x86_64-w64-mingw32-gcc'  # Last resort: hope it's in PATH
        ]
        
        for gcc_path in mingw_locations:
            gxx_path = gcc_path.replace('-gcc', '-g++')
            if os.path.exists(gcc_path) and os.path.exists(gxx_path):
                env['CC'] = gcc_path
                env['CXX'] = gxx_path
                print(f"Found MinGW compilers: CC={gcc_path}, CXX={gxx_path}")
                break
        else:
            # Use default names and hope for the best
            env['CC'] = 'x86_64-w64-mingw32-gcc'
            env['CXX'] = 'x86_64-w64-mingw32-g++'
            print("Using default MinGW compiler names (fallback)")
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