#!/bin/bash
set -e

# Get current project info
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"
ADDON_FILE="$PROJECT_DIR/addons.make"
CPP_PROPS_PATH="$PROJECT_DIR/.vscode/c_cpp_properties.json"

# Determine openFrameworks root
OF_ROOT="$(cd "$PROJECT_DIR/../../.." && pwd)"

echo "📦 Addon Update Script"
echo "Project: $PROJECT_NAME"
echo "OF Root: $OF_ROOT"
echo ""

# Read addons from addons.make
if [ -f "$ADDON_FILE" ]; then
    echo "Found addons in addons.make:"
    while IFS= read -r addon || [[ -n "$addon" ]]; do
        # Skip empty lines and comments
        if [[ -n "$addon" && ! "$addon" =~ ^# ]]; then
            echo "  - $addon"
        fi
    done < "$ADDON_FILE"
    echo ""
fi

# Update c_cpp_properties.json for includePath
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

# Create c_cpp_properties.json if it doesn't exist
mkdir -p "$(dirname "$CPP_PROPS_PATH")"

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
        "\${workspaceFolder}/src",
        "\${workspaceFolder}/src/**",
        "\${workspaceFolder}/../../../addons/*/src",
        "\${workspaceFolder}/../../../addons/*/include",
        "\${workspaceFolder}/../../../addons/**/src",
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
echo "✅ Addon configuration complete!"
echo "Note: Addons are now referenced directly from $OF_ROOT/addons"
