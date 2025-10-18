#!/bin/bash
set -e

# Get current project info
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
ADDON_FILE="$PROJECT_DIR/addons.make"
ADDON_DEST="$PROJECT_DIR/addons"
CPP_PROPS_PATH="$PROJECT_DIR/.vscode/c_cpp_properties.json"

# Determine openFrameworks root
OF_ROOT="$(cd "$PROJECT_DIR/../../.." && pwd)"

echo "📦 Addon Update Script"
echo "Project: $PROJECT_NAME"
echo "OF Root: $OF_ROOT"
echo ""

# 0. Clean up outdated addons
if [ -d "$ADDON_DEST" ]; then
    if [ -f "$ADDON_FILE" ]; then
        # Get list of used addons
        USED_ADDONS=()
        while IFS= read -r line || [[ -n "$line" ]]; do
            # Skip empty lines and comments
            if [[ -n "$line" && ! "$line" =~ ^# ]]; then
                ADDON_NAME="$(basename "$line")"
                USED_ADDONS+=("$ADDON_NAME")
            fi
        done < "$ADDON_FILE"

        # Check for unused addons and remove them
        for existing in "$ADDON_DEST"/*; do
            if [ -d "$existing" ]; then
                ADDON_NAME="$(basename "$existing")"
                if [[ ! " ${USED_ADDONS[@]} " =~ " ${ADDON_NAME} " ]]; then
                    echo "🧹 Removing unused addon: $ADDON_NAME"
                    rm -rf "$existing"
                fi
            fi
        done
    fi
else
    mkdir -p "$ADDON_DEST"
fi

# 1. Copy addons
if [ -f "$ADDON_FILE" ]; then
    while IFS= read -r addon || [[ -n "$addon" ]]; do
        # Skip empty lines and comments
        if [[ -n "$addon" && ! "$addon" =~ ^# ]]; then
            SRC="$OF_ROOT/addons/$addon"
            ADDON_NAME="$(basename "$addon")"
            DST="$ADDON_DEST/$ADDON_NAME"

            if [ ! -d "$DST" ]; then
                if [ -d "$SRC" ]; then
                    echo "📦 Copying addon: $addon"
                    rsync -a --delete "$SRC/" "$DST/"
                else
                    echo "⚠️  Warning: Addon not found: $SRC"
                fi
            else
                echo "✓ Addon already exists: $ADDON_NAME"
            fi
        fi
    done < "$ADDON_FILE"
fi

# 2. Update c_cpp_properties.json for includePath
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

# Create c_cpp_properties.json if it doesn't exist or update it
mkdir -p "$(dirname "$CPP_PROPS_PATH")"

# Check if file exists and read current content
if [ -f "$CPP_PROPS_PATH" ]; then
    echo "✓ c_cpp_properties.json already exists, keeping current configuration"
else
    cat > "$CPP_PROPS_PATH" << EOF
{
  "version": 4,
  "configurations": [
    {
      "name": "$PLATFORM",
      "includePath": [
        "\${workspaceFolder}/src/**",
        "\${workspaceFolder}/addons/*/src",
        "\${workspaceFolder}/addons/*/include",
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
    echo "✅ Created $CPP_PROPS_PATH"
fi

echo ""
echo "✅ Addon update complete!"
