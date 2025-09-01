#!/bin/bash

# Enhanced build script that simulates GitHub workflow caching for multiple platforms
# This script mimics the caching behavior from .github/workflows/build_release.yml

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Configuration ---
PLATFORM=""
ARCH="x86_64"
SCONS_FLAGS=""

# --- Helper Functions ---
show_usage() {
    echo -e "${YELLOW}Usage: $0 [linux|macos|windows]${NC}"
    echo "  linux: Build for Linux (x86_64)"
    echo "  macos: Build for macOS (universal)"
    echo "  windows: Build for Windows (x86_64, cross-compile)"
    exit 1
}

# --- Platform-specific Setup ---
setup_linux() {
    PLATFORM="linux"
    ARCH="x86_64"
    SCONS_FLAGS="platform=linux"
    echo -e "${BLUE}=== Gedis Local Build Script (Linux) ===${NC}"
}

setup_macos() {
    PLATFORM="macos"
    ARCH="universal"
    SCONS_FLAGS="platform=macos arch=universal"
    echo -e "${BLUE}=== Gedis Local Build Script (macOS) ===${NC}"
}

setup_windows() {
    PLATFORM="windows"
    ARCH="x86_64"
    SCONS_FLAGS="platform=windows use_mingw=yes"
    echo -e "${BLUE}=== Gedis Local Build Script (Windows Cross-Compile) ===${NC}"
}

# --- Build Functions ---

# Function to check if godot-cpp cache is valid
check_godotcpp_cache() {
    echo -e "${YELLOW}Checking godot-cpp cache...${NC}"
    
    # When cross-compiling with MinGW, we still get .a files, not .lib files
    # .lib files are only produced when building with MSVC on Windows
    local lib_ext="a"

    local required_files=(
        "godot-cpp/bin/libgodot-cpp.${PLATFORM}.template_release.${ARCH}.${lib_ext}"
        "godot-cpp/bin/libgodot-cpp.${PLATFORM}.template_debug.${ARCH}.${lib_ext}"
        "godot-cpp/gen/include"
        "godot-cpp/gen/src"
    )
    
    for file in "${required_files[@]}"; do
        if [ ! -e "$file" ]; then
            echo -e "${RED}Cache miss: $file not found${NC}"
            return 1
        fi
    done
    
    if [ -f "godot-cpp/.sconsign.dblite" ]; then
        echo -e "${GREEN}SCons signature file found${NC}"
    fi
    
    echo -e "${GREEN}godot-cpp cache is valid!${NC}"
    return 0
}

# Function to build godot-cpp
build_godotcpp() {
    echo -e "${YELLOW}Building godot-cpp (cache miss)...${NC}"
    
    cd godot-cpp
    
    echo -e "${BLUE}Building template_release...${NC}"
    scons $SCONS_FLAGS generate_bindings=yes target=template_release
    
    echo -e "${BLUE}Building template_debug...${NC}"
    scons $SCONS_FLAGS generate_bindings=yes target=template_debug
    
    cd ..
    
    echo -e "${GREEN}godot-cpp build completed!${NC}"
}

# Function to install dependencies
install_dependencies() {
    echo -e "${YELLOW}Checking dependencies for ${PLATFORM}...${NC}"
    
    if [ "$PLATFORM" == "linux" ]; then
        if [[ "$OSTYPE" != "linux-gnu"* ]]; then
            echo -e "${RED}Linux build requires a Linux environment. Current OS: $OSTYPE${NC}"
            exit 1
        fi
        
        local required_tools=("scons" "g++" "pkg-config")
        local missing_tools=()
        
        for tool in "${required_tools[@]}"; do
            if ! command -v "$tool" &> /dev/null; then
                missing_tools+=("$tool")
            fi
        done
        
        if [ ${#missing_tools[@]} -ne 0 ]; then
            echo -e "${RED}Missing required tools: ${missing_tools[*]}${NC}"
            echo -e "${YELLOW}Please install them with:${NC}"
            echo "sudo apt-get update && sudo apt-get install -y build-essential scons pkg-config"
            exit 1
        fi
    elif [ "$PLATFORM" == "windows" ]; then
        # Check if we have the MinGW cross-compiler tools
        # Note: CC and CXX environment variables should already be set by this point
        local required_tools=("scons")
        local missing_tools=()
        
        # Check for scons first
        if ! command -v "scons" &> /dev/null; then
            missing_tools+=("scons")
        fi
        
        # Check for MinGW cross-compiler (use environment variables if set)
        local gcc_cmd="${CC:-x86_64-w64-mingw32-gcc}"
        local gxx_cmd="${CXX:-x86_64-w64-mingw32-g++}"
        
        if ! command -v "$gcc_cmd" &> /dev/null; then
            missing_tools+=("$gcc_cmd")
        fi
        
        if ! command -v "$gxx_cmd" &> /dev/null; then
            missing_tools+=("$gxx_cmd")
        fi
        
        if [ ${#missing_tools[@]} -ne 0 ]; then
            echo -e "${RED}Missing required tools for Windows cross-compilation: ${missing_tools[*]}${NC}"
            echo -e "${YELLOW}Please install MinGW-w64 with:${NC}"
            if [[ "$OSTYPE" == "linux-gnu"* ]]; then
                echo "sudo apt-get update && sudo apt-get install -y mingw-w64 scons"
            elif [[ "$OSTYPE" == "darwin"* ]]; then
                echo "brew install mingw-w64 scons"
            else
                echo "Please install MinGW-w64 cross-compiler for your system"
            fi
            exit 1
        fi
    elif [ "$PLATFORM" == "macos" ]; then
        if [[ "$OSTYPE" != "darwin"* ]]; then
            echo -e "${RED}macOS build requires a macOS environment. Current OS: $OSTYPE${NC}"
            exit 1
        fi
        # Add checks for Xcode, etc. if needed
    fi
    
    echo -e "${GREEN}All required dependencies are available${NC}"
}

# Function to build the main project
build_main_project() {
    echo -e "${YELLOW}Building main project...${NC}"
    scons $SCONS_FLAGS target=template_release
    echo -e "${GREEN}Main project build completed!${NC}"
}

# Function to package addon
package_addon() {
    echo -e "${YELLOW}Packaging addon...${NC}"
    
    local artifact_name="gedis-${PLATFORM}-${ARCH}"
    
    mkdir -p "package/addons"
    cp -r "addons/Gedis" "package/addons/"
    
    # Correctly copy the library based on the platform
    if [ "$PLATFORM" == "macos" ]; then
        cp -r "bin/libGedis.macos.template_release.framework" "package/addons/Gedis/bin/"
    elif [ "$PLATFORM" == "windows" ]; then
        # The actual file created is libgedis.dll in addons/Gedis/bin/
        cp "addons/Gedis/bin/libgedis.dll" "package/addons/Gedis/bin/"
    elif [ "$PLATFORM" == "linux" ]; then
        # For Linux, copy the .so file
        cp "addons/Gedis/bin/libgedis.so" "package/addons/Gedis/bin/"
    else
        echo -e "${YELLOW}Packaging for ${PLATFORM} is not fully implemented yet.${NC}"
    fi

    cd "package"
    zip -r "../${artifact_name}.zip" .
    cd ..
    
    rm -rf "package"
    
    echo -e "${GREEN}Addon packaged as ${artifact_name}.zip${NC}"
}

# Function to show cache status
show_cache_status() {
    echo -e "${BLUE}=== Cache Status ===${NC}"
    
    # When cross-compiling with MinGW, we still get .a files, not .lib files
    # .lib files are only produced when building with MSVC on Windows
    local lib_ext="a"

    if [ -f "godot-cpp/bin/libgodot-cpp.${PLATFORM}.template_release.${ARCH}.${lib_ext}" ]; then
        echo -e "${GREEN}✓ Release library cached${NC}"
    else
        echo -e "${RED}✗ Release library missing${NC}"
    fi
    
    if [ -f "godot-cpp/bin/libgodot-cpp.${PLATFORM}.template_debug.${ARCH}.${lib_ext}" ]; then
        echo -e "${GREEN}✓ Debug library cached${NC}"
    else
        echo -e "${RED}✗ Debug library missing${NC}"
    fi
    
    if [ -d "godot-cpp/gen/include" ] && [ -d "godot-cpp/gen/src" ]; then
        echo -e "${GREEN}✓ Generated bindings cached${NC}"
    else
        echo -e "${RED}✗ Generated bindings missing${NC}"
    fi
    
    if [ -f "godot-cpp/.sconsign.dblite" ]; then
        echo -e "${GREEN}✓ SCons signature file present${NC}"
    else
        echo -e "${YELLOW}! SCons signature file missing (will be created)${NC}"
    fi
    
    echo ""
}

# --- Main Execution ---
main() {
    # Parse command-line arguments
    if [ -z "$1" ]; then
        show_usage
    fi

    case "$1" in
        linux)
            setup_linux
            ;;
        macos)
            setup_macos
            ;;
        windows)
            export CC=x86_64-w64-mingw32-gcc
            export CXX=x86_64-w64-mingw32-g++
            setup_windows
            ;;
        *)
            show_usage
            ;;
    esac

    echo -e "${BLUE}Platform: ${PLATFORM}, Architecture: ${ARCH}${NC}"
    echo ""

    install_dependencies
    show_cache_status
    
    if ! check_godotcpp_cache; then
        build_godotcpp
    else
        echo -e "${GREEN}Using cached godot-cpp build${NC}"
    fi
    
    echo ""
    build_main_project
    echo ""
    
    read -p "Do you want to package the addon? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        package_addon
    fi
    
    echo ""
    echo -e "${GREEN}=== Build Complete! ===${NC}"
    echo -e "${BLUE}Built for: ${PLATFORM} (${ARCH})${NC}"
    
    show_cache_status
}

main "$@"