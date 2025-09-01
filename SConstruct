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
    # Don't use the 'mingw' tool as it may interfere with our custom setup
    env = Environment(tools=['default'])
    
    # Debug: Show what we're working with
    print(f"DEBUG: Environment CC={os.environ.get('CC', 'not set')}")
    print(f"DEBUG: Environment CXX={os.environ.get('CXX', 'not set')}")
    print(f"DEBUG: Current working directory: {os.getcwd()}")
    
    # For MSYS2 environment, we need to use full paths to the compilers
    # because SCons executes them in a different shell context
    if 'CC' in os.environ and 'CXX' in os.environ:
        # Use environment variables if they're set (from CI)
        cc_cmd = os.environ['CC']
        cxx_cmd = os.environ['CXX']
        
        # Convert Windows-style paths to MSYS2 paths if needed
        # In MSYS2, /mingw64/bin is the standard location
        if not os.path.isabs(cc_cmd):
            # Try to find the full path
            potential_paths = [
                f'/mingw64/bin/{cc_cmd}',
                f'/usr/bin/{cc_cmd}',
                cc_cmd  # Keep original as fallback
            ]
            
            for path in potential_paths:
                if os.path.exists(path):
                    cc_cmd = path
                    break
            
            # Do the same for CXX
            potential_paths = [
                f'/mingw64/bin/{cxx_cmd}',
                f'/usr/bin/{cxx_cmd}',
                cxx_cmd  # Keep original as fallback
            ]
            
            for path in potential_paths:
                if os.path.exists(path):
                    cxx_cmd = path
                    break
        
        env['CC'] = cc_cmd
        env['CXX'] = cxx_cmd
        print(f"DEBUG: Set CC={cc_cmd}")
        print(f"DEBUG: Set CXX={cxx_cmd}")
        print(f"DEBUG: CC exists: {os.path.exists(cc_cmd) if os.path.isabs(cc_cmd) else 'unknown (relative path)'}")
        print(f"DEBUG: CXX exists: {os.path.exists(cxx_cmd) if os.path.isabs(cxx_cmd) else 'unknown (relative path)'}")
    else:
        # Fallback: try to find MinGW compilers in standard locations
        print("DEBUG: CC/CXX environment variables not set, trying fallback")
        mingw_locations = [
            '/mingw64/bin/x86_64-w64-mingw32-gcc',
            '/usr/bin/x86_64-w64-mingw32-gcc',
            'x86_64-w64-mingw32-gcc'  # Last resort: hope it's in PATH
        ]
        
        for gcc_path in mingw_locations:
            gxx_path = gcc_path.replace('-gcc', '-g++')
            print(f"DEBUG: Checking {gcc_path} and {gxx_path}")
            if os.path.exists(gcc_path) and os.path.exists(gxx_path):
                env['CC'] = gcc_path
                env['CXX'] = gxx_path
                print(f"DEBUG: Found MinGW compilers: CC={gcc_path}, CXX={gxx_path}")
                break
        else:
            # Use default names and hope for the best
            env['CC'] = 'x86_64-w64-mingw32-gcc'
            env['CXX'] = 'x86_64-w64-mingw32-g++'
            print("DEBUG: Using default MinGW compiler names (fallback)")
    
    # Verify final compiler settings
    print(f"DEBUG: Final CC={env['CC']}")
    print(f"DEBUG: Final CXX={env['CXX']}")
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