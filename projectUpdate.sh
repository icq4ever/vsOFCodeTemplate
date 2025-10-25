#!/bin/bash
set -e

# ============================================================================
# Unified Project Update Script for openFrameworks (macOS/Linux)
# ============================================================================
# This script:
# - Renames project files to match folder name
# - Updates Makefile configuration
# - Configures VSCode IntelliSense for addons
# ============================================================================

# Get current folder name and project info
NEW_NAME="$(basename "$(pwd)")"
PROJECT_DIR="$(pwd)"
OF_ROOT="$(cd "$PROJECT_DIR/../../.." && pwd)"
ADDON_FILE="$PROJECT_DIR/addons.make"

echo "🔧 openFrameworks Project Update"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Project:  $NEW_NAME"
echo "Location: $PROJECT_DIR"
echo "OF Root:  $OF_ROOT"
echo ""

# ============================================================================
# Step 1: Detect old project name and rename if needed
# ============================================================================

OLD_NAME=""

# Try to find old name from various sources
if ls *.xcodeproj 2>/dev/null | grep -q .; then
    # macOS: find .xcodeproj
    OLD_PROJ="$(ls *.xcodeproj | head -1)"
    OLD_NAME="$(basename "$OLD_PROJ" .xcodeproj)"
elif ls *.vcxproj 2>/dev/null | grep -q .; then
    # Windows/Visual Studio: find .vcxproj (in case running on WSL)
    OLD_PROJ="$(ls *.vcxproj | head -1)"
    OLD_NAME="$(basename "$OLD_PROJ" .vcxproj)"
elif [ -f "Makefile" ]; then
    # Linux/macOS: try to find project name in Makefile
    OLD_NAME="$(grep -m 1 "APPNAME" Makefile 2>/dev/null | sed 's/.*=\s*//' || echo "")"
    if [ -z "$OLD_NAME" ]; then
        OLD_NAME="$NEW_NAME"
    fi
else
    OLD_NAME="$NEW_NAME"
fi

if [ "$OLD_NAME" != "$NEW_NAME" ]; then
    echo "🔁 Renaming project: '$OLD_NAME' → '$NEW_NAME'"
    echo ""

    # macOS: Rename .xcodeproj
    if [ -d "${OLD_NAME}.xcodeproj" ]; then
        mv "${OLD_NAME}.xcodeproj" "${NEW_NAME}.xcodeproj"
        echo "  ✔️ Renamed: ${OLD_NAME}.xcodeproj → ${NEW_NAME}.xcodeproj"

        # Update project.pbxproj inside
        if [ -f "${NEW_NAME}.xcodeproj/project.pbxproj" ]; then
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' "s/${OLD_NAME}/${NEW_NAME}/g" "${NEW_NAME}.xcodeproj/project.pbxproj"
            else
                sed -i "s/${OLD_NAME}/${NEW_NAME}/g" "${NEW_NAME}.xcodeproj/project.pbxproj"
            fi
            echo "  📝 Updated references inside: project.pbxproj"
        fi
    fi

    # Windows/Visual Studio: Rename .vcxproj and .sln (if running on WSL)
    if [ -f "${OLD_NAME}.vcxproj" ]; then
        mv "${OLD_NAME}.vcxproj" "${NEW_NAME}.vcxproj"
        echo "  ✔️ Renamed: ${OLD_NAME}.vcxproj → ${NEW_NAME}.vcxproj"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/<RootNamespace>${OLD_NAME}<\/RootNamespace>/<RootNamespace>${NEW_NAME}<\/RootNamespace>/g" "${NEW_NAME}.vcxproj"
        else
            sed -i "s/<RootNamespace>${OLD_NAME}<\/RootNamespace>/<RootNamespace>${NEW_NAME}<\/RootNamespace>/g" "${NEW_NAME}.vcxproj"
        fi
        echo "  📝 Updated RootNamespace in: ${NEW_NAME}.vcxproj"
    fi

    if [ -f "${OLD_NAME}.vcxproj.filters" ]; then
        mv "${OLD_NAME}.vcxproj.filters" "${NEW_NAME}.vcxproj.filters"
        echo "  ✔️ Renamed: ${OLD_NAME}.vcxproj.filters → ${NEW_NAME}.vcxproj.filters"
    fi

    if [ -f "${OLD_NAME}.sln" ]; then
        mv "${OLD_NAME}.sln" "${NEW_NAME}.sln"
        echo "  ✔️ Renamed: ${OLD_NAME}.sln → ${NEW_NAME}.sln"

        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/${OLD_NAME}/${NEW_NAME}/g" "${NEW_NAME}.sln"
        else
            sed -i "s/${OLD_NAME}/${NEW_NAME}/g" "${NEW_NAME}.sln"
        fi
        echo "  📝 Updated references inside: ${NEW_NAME}.sln"
    fi

    # Update Makefile if exists
    if [ -f "Makefile" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/APPNAME\s*=.*/APPNAME = ${NEW_NAME}/" Makefile
        else
            sed -i "s/APPNAME\s*=.*/APPNAME = ${NEW_NAME}/" Makefile
        fi
        echo "  📝 Updated APPNAME in Makefile"
    fi

    echo ""
fi

# ============================================================================
# Step 2: Create/Update config.make if needed
# ============================================================================

if [ ! -f "config.make" ]; then
    cat > config.make << 'EOF'
################################################################################
# CONFIGURE PROJECT MAKEFILE (optional)
#   This file is where we make project specific configurations.
################################################################################

################################################################################
# OF ROOT
#   The location of your root openFrameworks installation
#       (default) OF_ROOT = ../../..
################################################################################
# OF_ROOT = ../../..

################################################################################
# PROJECT ROOT
#   The location of the project - a starting place for searching for files
#       (default) PROJECT_ROOT = . (this directory)
#
################################################################################
# PROJECT_ROOT = .

################################################################################
# PROJECT SPECIFIC CHECKS
#   This is a project defined section to create internal makefile flags to
#   conditionally enable or disable the addition of various features within
#   this makefile.  For instance, if you want to make changes based on whether
#   GTK is installed, one might test that here and create a variable to check.
################################################################################
# None

################################################################################
# PROJECT EXTERNAL SOURCE PATHS
#   These are fully qualified paths that are not within the PROJECT_ROOT folder.
#   Like source folders in the PROJECT_ROOT, these paths are subject to
#   exlclusion via the PROJECT_EXLCUSIONS list.
#
#     (default) PROJECT_EXTERNAL_SOURCE_PATHS = (blank)
#
#   Note: Leave a leading space when adding list items with the += operator
################################################################################
# PROJECT_EXTERNAL_SOURCE_PATHS =

################################################################################
# PROJECT EXCLUSIONS
#   These makefiles assume that all folders in your current project directory
#   and any listed in the PROJECT_EXTERNAL_SOURCH_PATHS are are valid locations
#   to look for source code. The any folders or files that match any of the
#   items in the PROJECT_EXCLUSIONS list below will be ignored.
#
#   Each item in the PROJECT_EXCLUSIONS list will be treated as a complete
#   string unless teh user adds a wildcard (%) operator to match subdirectories.
#   GNU make only allows one wildcard for matching.  The second wildcard (%) is
#   treated literally.
#
#      (default) PROJECT_EXCLUSIONS = (blank)
#
#		Will automatically exclude the following:
#
#			$(PROJECT_ROOT)/bin%
#			$(PROJECT_ROOT)/obj%
#			$(PROJECT_ROOT)/%.xcodeproj
#
#   Note: Leave a leading space when adding list items with the += operator
################################################################################
# PROJECT_EXCLUSIONS =

################################################################################
# PROJECT LINKER FLAGS
#	These flags will be sent to the linker when compiling the executable.
#
#		(default) PROJECT_LDFLAGS = -Wl,-rpath=./libs
#
#   Note: Leave a leading space when adding list items with the += operator
################################################################################

# Currently, shared libraries that are needed are copied to the
# $(PROJECT_ROOT)/bin/libs directory.  The following LDFLAGS tell the linker to
# add a runtime path to search for those shared libraries, since they aren't
# incorporated directly into the final executable application binary.
# TODO: should this be a default setting?
# PROJECT_LDFLAGS=-Wl,-rpath=./libs

################################################################################
# PROJECT DEFINES
#   Create a space-delimited list of DEFINES. The list will be converted into
#   CFLAGS with the "-D" flag later in the makefile.
#
#		(default) PROJECT_DEFINES = (blank)
#
#   Note: Leave a leading space when adding list items with the += operator
################################################################################
# PROJECT_DEFINES =

################################################################################
# PROJECT CFLAGS
#   This is a list of fully qualified CFLAGS required when compiling for this
#   project.  These CFLAGS will be used IN ADDITION TO the PLATFORM_CFLAGS
#   defined in your platform specific core configuration files. These flags are
#   presented to the compiler BEFORE the PROJECT_OPTIMIZATION_CFLAGS below.
#
#		(default) PROJECT_CFLAGS = (blank)
#
#   Note: Before adding PROJECT_CFLAGS, note that the PLATFORM_CFLAGS defined in
#   your platform specific configuration file will be applied by default and
#   further flags here may not be needed.
#
#   Note: Leave a leading space when adding list items with the += operator
################################################################################
# PROJECT_CFLAGS =

################################################################################
# PROJECT OPTIMIZATION CFLAGS
#   These are lists of CFLAGS that are target-specific.  While any flags could
#   be conditionally added, they are usually limited to optimization flags.
#   These flags are added BEFORE the PROJECT_CFLAGS.
#
#   PROJECT_OPTIMIZATION_CFLAGS_RELEASE flags are only applied to RELEASE targets.
#
#		(default) PROJECT_OPTIMIZATION_CFLAGS_RELEASE = (blank)
#
#   PROJECT_OPTIMIZATION_CFLAGS_DEBUG flags are only applied to DEBUG targets.
#
#		(default) PROJECT_OPTIMIZATION_CFLAGS_DEBUG = (blank)
#
#   Note: Before adding PROJECT_OPTIMIZATION_CFLAGS, please note that the
#   PLATFORM_OPTIMIZATION_CFLAGS defined in your platform specific configuration
#   file will be applied by default and further optimization flags here may not
#   be needed.
#
#   Note: Leave a leading space when adding list items with the += operator
################################################################################
# PROJECT_OPTIMIZATION_CFLAGS_RELEASE =
# PROJECT_OPTIMIZATION_CFLAGS_DEBUG =

################################################################################
# PROJECT COMPILERS
#   Custom compilers can be set for CC and CXX
#		(default) PROJECT_CXX = (blank)
#		(default) PROJECT_CC = (blank)
#   Note: Leave a leading space when adding list items with the += operator
################################################################################
# PROJECT_CXX =
# PROJECT_CC =
EOF
    echo "✅ Created config.make"
    echo ""
fi

# ============================================================================
# Step 3: Configure VSCode IntelliSense for addons
# ============================================================================

CPP_PROPS_PATH="$PROJECT_DIR/.vscode/c_cpp_properties.json"

# Detect OS for appropriate configuration
if [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="macOS"
    COMPILER_PATH="/usr/bin/clang++"
    INTELLISENSE_MODE="macos-clang-x64"
else
    PLATFORM="Linux"
    COMPILER_PATH="/usr/bin/g++"
    INTELLISENSE_MODE="linux-gcc-x64"
fi

# Read addons from addons.make
ADDON_COUNT=0
if [ -f "$ADDON_FILE" ]; then
    echo "📦 Found addons in addons.make:"
    while IFS= read -r addon || [[ -n "$addon" ]]; do
        # Skip empty lines and comments
        if [[ -n "$addon" && ! "$addon" =~ ^# ]]; then
            echo "  • $addon"
            ADDON_COUNT=$((ADDON_COUNT + 1))
        fi
    done < "$ADDON_FILE"
    echo ""
fi

# Create .vscode directory if needed
mkdir -p "$(dirname "$CPP_PROPS_PATH")"

# Create or update c_cpp_properties.json
cat > "$CPP_PROPS_PATH" << EOF
{
  "version": 4,
  "configurations": [
    {
      "name": "$PLATFORM",
      "includePath": [
        "\${workspaceFolder}/src",
        "\${workspaceFolder}/src/**",
        "\${workspaceFolder}/../../../addons/*/src",
        "\${workspaceFolder}/../../../addons/*/include",
        "\${workspaceFolder}/../../../addons/*/libs/*/include",
        "\${workspaceFolder}/../../../addons/**/src",
        "\${workspaceFolder}/../../../libs/openFrameworks",
        "\${workspaceFolder}/../../../libs/openFrameworks/**",
        "\${workspaceFolder}/../../../libs/**/include"
      ],
      "defines": [],
      "compilerPath": "$COMPILER_PATH",
      "cStandard": "c17",
      "cppStandard": "c++17",
      "intelliSenseMode": "$INTELLISENSE_MODE"
    }
  ]
}
EOF

echo "✅ Updated .vscode/c_cpp_properties.json"
echo ""

# ============================================================================
# Summary
# ============================================================================

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✨ Project update complete!"
echo ""
echo "Project name:     $NEW_NAME"
echo "Addons found:     $ADDON_COUNT"
echo ""
echo "📝 Note: Addons are referenced from $OF_ROOT/addons"
echo "   Make sure addons are cloned there before building."
echo ""
echo "🔨 Build commands:"
echo "   make Debug        - Build debug version"
echo "   make Release      - Build release version"
echo "   make RunDebug     - Build and run debug"
echo "   make RunRelease   - Build and run release"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
