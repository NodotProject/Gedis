#!/bin/bash

# Enhanced build script that simulates GitHub workflow caching for Linux
# This script mimics the caching behavior from .github/workflows/build_release.yml

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Platform and architecture (matching GitHub workflow)
PLATFORM="linux"
ARCH="x86_64"

echo -e "${BLUE}=== Gedis Local Build Script (Linux) ===${NC}"
echo -e "${BLUE}Platform: ${PLATFORM}, Architecture: ${ARCH}${NC}"
echo ""

# Function to check if godot-cpp cache is valid
check_godotcpp_cache() {
    echo -e "${YELLOW}Checking godot-cpp cache...${NC}"
    
    # Files that should exist for a complete cache (matching GitHub workflow)
    local required_files=(
        "godot-cpp/bin/libgodot-cpp.linux.template_release.x86_64.a"
        "godot-cpp/bin/libgodot-cpp.linux.template_debug.x86_64.a"
        "godot-cpp/gen/include"
        "godot-cpp/gen/src"
    )
    
    # Check if all required files exist
    for file in "${required_files[@]}"; do
        if [ ! -e "$file" ]; then
            echo -e "${RED}Cache miss: $file not found${NC}"
            return 1
        fi
    done
    
    # Check if SCons signature file exists (optional but good for cache validation)
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
    
    # Build both release and debug versions (matching GitHub workflow)
    echo -e "${BLUE}Building template_release...${NC}"
    scons platform=$PLATFORM generate_bindings=yes target=template_release
    
    echo -e "${BLUE}Building template_debug...${NC}"
    scons platform=$PLATFORM generate_bindings=yes target=template_debug
    
    cd ..
    
    echo -e "${GREEN}godot-cpp build completed!${NC}"
}

# Function to install Linux dependencies (matching GitHub workflow)
install_dependencies() {
    echo -e "${YELLOW}Checking Linux dependencies...${NC}"
    
    # Check if we're on Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        echo -e "${RED}This script is designed for Linux. Current OS: $OSTYPE${NC}"
        exit 1
    fi
    
    # Check if required tools are available
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
        echo "sudo apt-get update"
        echo "sudo apt-get install -y build-essential scons pkg-config libx11-dev libxcursor-dev libxinerama-dev libgl1-mesa-dev libglu1-mesa-dev libasound2-dev libpulse-dev libudev-dev libxi-dev libxrandr-dev yasm"
        exit 1
    fi
    
    echo -e "${GREEN}All required dependencies are available${NC}"
}

# Function to build the main project
build_main_project() {
    echo -e "${YELLOW}Building main project...${NC}"
    
    # Build with SCons (matching GitHub workflow parameters)
    scons platform=$PLATFORM target=template_release arch=$ARCH
    
    echo -e "${GREEN}Main project build completed!${NC}"
}

# Function to package addon (optional, matching GitHub workflow)
package_addon() {
    echo -e "${YELLOW}Packaging addon...${NC}"
    
    local artifact_name="gedis-${PLATFORM}-${ARCH}"
    
    # Create package directory
    mkdir -p package/addons
    cp -r addons/Gedis package/addons/
    
    # Create zip file
    cd package
    zip -r "../${artifact_name}.zip" .
    cd ..
    
    # Clean up
    rm -rf package
    
    echo -e "${GREEN}Addon packaged as ${artifact_name}.zip${NC}"
}

# Function to show cache status
show_cache_status() {
    echo -e "${BLUE}=== Cache Status ===${NC}"
    
    if [ -f "godot-cpp/bin/libgodot-cpp.linux.template_release.x86_64.a" ]; then
        echo -e "${GREEN}✓ Release library cached${NC}"
    else
        echo -e "${RED}✗ Release library missing${NC}"
    fi
    
    if [ -f "godot-cpp/bin/libgodot-cpp.linux.template_debug.x86_64.a" ]; then
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

# Main execution
main() {
    # Check dependencies first
    install_dependencies
    
    # Show current cache status
    show_cache_status
    
    # Check and build godot-cpp if needed
    if check_godotcpp_cache; then
        echo -e "${GREEN}Using cached godot-cpp build${NC}"
    else
        build_godotcpp
    fi
    
    echo ""
    
    # Build main project
    build_main_project
    
    echo ""
    
    # Ask if user wants to package
    read -p "Do you want to package the addon? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        package_addon
    fi
    
    echo ""
    echo -e "${GREEN}=== Build Complete! ===${NC}"
    echo -e "${BLUE}Built for: ${PLATFORM} (${ARCH})${NC}"
    
    # Show final cache status
    show_cache_status
}

# Run main function
main "$@"