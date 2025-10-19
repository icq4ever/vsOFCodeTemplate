#!/bin/bash
set -e

echo "🔄 Project Migration Tool"
echo "This will import template configuration files into your existing project"
echo ""

# Get current project directory
PROJECT_DIR="$(pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

# Auto-detect template directory
# Assuming OF structure: {OF_ROOT}/apps/{category}/{projectName}
TEMPLATE_NAME="vsOFCodeTemplate"
TEMPLATE_DIR=""

# Try to find template in same category first
CATEGORY_DIR="$(dirname "$PROJECT_DIR")"
if [ -d "$CATEGORY_DIR/$TEMPLATE_NAME" ]; then
    TEMPLATE_DIR="$CATEGORY_DIR/$TEMPLATE_NAME"
fi

# Try to find in myApps category
if [ -z "$TEMPLATE_DIR" ]; then
    APPS_DIR="$(dirname "$CATEGORY_DIR")"
    if [ -d "$APPS_DIR/myApps/$TEMPLATE_NAME" ]; then
        TEMPLATE_DIR="$APPS_DIR/myApps/$TEMPLATE_NAME"
    fi
fi

# If still not found, ask user
if [ -z "$TEMPLATE_DIR" ] || [ ! -d "$TEMPLATE_DIR" ]; then
    echo "❌ Template directory not found automatically."
    echo "Please specify the template directory path:"
    read -r TEMPLATE_DIR
    if [ ! -d "$TEMPLATE_DIR" ]; then
        echo "❌ Directory does not exist: $TEMPLATE_DIR"
        exit 1
    fi
fi

echo "📂 Template found: $TEMPLATE_DIR"
echo "📂 Target project: $PROJECT_DIR"
echo ""

# Check if already in template directory
if [ "$PROJECT_DIR" = "$TEMPLATE_DIR" ]; then
    echo "❌ You are already in the template directory!"
    exit 1
fi

# Warn if .git exists
if [ -d ".git" ]; then
    echo "⚠️  Existing git repository detected. It will be preserved."
fi

# Warn if src/ exists
if [ -d "src" ]; then
    echo "✓ Existing src/ directory will be preserved."
fi

# Warn if addons.make exists
if [ -f "addons.make" ]; then
    echo "✓ Existing addons.make will be preserved."
fi

# Warn if README exists
if [ -f "README.md" ] || [ -f "readme.md" ]; then
    echo "✓ Existing README will be preserved."
fi

echo ""
read -p "Continue with migration? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Migration cancelled."
    exit 0
fi

echo ""
echo "🚀 Starting migration..."

# 1. Copy script files
echo "📝 Copying update scripts..."
for script in addonUpdate.sh projectUpdate.sh addonUpdate.ps1 projectUpdate.ps1; do
    if [ -f "$TEMPLATE_DIR/$script" ]; then
        cp "$TEMPLATE_DIR/$script" "$PROJECT_DIR/"
        chmod +x "$PROJECT_DIR/$script" 2>/dev/null || true
        echo "  ✓ $script"
    fi
done

# 2. Copy Makefile and config.make if they don't exist
echo "📝 Copying build files..."
if [ ! -f "Makefile" ] && [ -f "$TEMPLATE_DIR/Makefile" ]; then
    cp "$TEMPLATE_DIR/Makefile" "$PROJECT_DIR/"
    echo "  ✓ Makefile"
else
    echo "  ⊘ Makefile (already exists, skipped)"
fi

if [ ! -f "config.make" ] && [ -f "$TEMPLATE_DIR/config.make" ]; then
    cp "$TEMPLATE_DIR/config.make" "$PROJECT_DIR/"
    echo "  ✓ config.make"
fi

# 3. Merge .gitignore
echo "📝 Merging .gitignore..."
if [ -f "$TEMPLATE_DIR/.gitignore" ]; then
    if [ -f ".gitignore" ]; then
        # Backup existing
        cp ".gitignore" ".gitignore.backup"
        echo "  ⚠️  Backed up existing .gitignore to .gitignore.backup"

        # Merge (append template, remove duplicates)
        cat "$TEMPLATE_DIR/.gitignore" >> ".gitignore"
        # Remove duplicate lines while preserving order
        if command -v awk >/dev/null 2>&1; then
            awk '!seen[$0]++' ".gitignore" > ".gitignore.tmp" && mv ".gitignore.tmp" ".gitignore"
        fi
        echo "  ✓ .gitignore (merged)"
    else
        cp "$TEMPLATE_DIR/.gitignore" "$PROJECT_DIR/"
        echo "  ✓ .gitignore (new)"
    fi
fi

# 4. Copy .gitattributes
echo "📝 Copying .gitattributes..."
if [ -f "$TEMPLATE_DIR/.gitattributes" ]; then
    if [ -f ".gitattributes" ]; then
        cp ".gitattributes" ".gitattributes.backup"
        echo "  ⚠️  Backed up existing .gitattributes"
    fi
    cp "$TEMPLATE_DIR/.gitattributes" "$PROJECT_DIR/"
    echo "  ✓ .gitattributes"
fi

# 5. Merge .vscode directory
echo "📝 Merging .vscode configuration..."
mkdir -p ".vscode"

# Copy VSCode config files (tasks, launch, c_cpp_properties)
for vscode_file in tasks.json launch.json c_cpp_properties.json; do
    if [ -f "$TEMPLATE_DIR/.vscode/$vscode_file" ]; then
        cp "$TEMPLATE_DIR/.vscode/$vscode_file" ".vscode/"
        echo "  ✓ $vscode_file"
    fi
done

# Don't copy settings.json (user-specific)
if [ -f "$TEMPLATE_DIR/.vscode/settings.json" ] && [ ! -f ".vscode/settings.json" ]; then
    cp "$TEMPLATE_DIR/.vscode/settings.json" ".vscode/"
    echo "  ✓ settings.json (new)"
fi

# 6. Create addons.make if it doesn't exist
if [ ! -f "addons.make" ]; then
    touch "addons.make"
    echo "  ✓ Created empty addons.make"
fi

# 7. Fix line endings for all scripts
echo "🔧 Fixing line endings..."
for script in addonUpdate.sh projectUpdate.sh projectMigrate.sh addonUpdate.ps1 projectUpdate.ps1; do
    if [ -f "$script" ]; then
        sed -i 's/\r$//' "$script" 2>/dev/null || sed -i '' 's/\r$//' "$script" 2>/dev/null || true
    fi
done

echo ""
echo "✅ Migration complete!"
echo ""
echo "📋 Summary:"
echo "  • Update scripts installed"
echo "  • Build configuration copied"
echo "  • .gitignore and .gitattributes updated"
echo "  • .vscode/ configuration merged"
echo "  • Your source code and addons.make preserved"
echo ""
echo "📝 Next steps:"
echo "  1. Review .gitignore.backup if it exists"
echo "  2. Review .vscode/*.backup files if they exist"
echo "  3. Run ./projectUpdate.sh to update project files"
echo "  4. Run ./addonUpdate.sh if you have addons in addons.make"
echo ""
