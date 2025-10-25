# openFrameworks empty project template for cross-platform vscode setup

this template is include :
- support msbuild on windows
- build/run/update addon tasks for vscode on windows/linux/mac
- launching debug/release app
- read addon.make and update vcxproj references to addons in `{OF_ROOT}/addons`
- run powershell script on WSL (with alias)

## why made this ?
- in visual studio, adding new files are so annoying
- everytime add new addon, project should be update by `projectGenerator`
- visual studio is too heavy

## feature
- **unified project update script** - single command updates everything
  - renames project files to match folder name
  - scans and adds source files from `src/` (Windows)
  - reads `addons.make` and configures addon references
  - generates vcxproj, filters, and sln from official templates (Windows)
  - configures VSCode IntelliSense for all platforms
- addon support (references addons directly from `{OF_ROOT}/addons`)
  - no local copying - addons are referenced from the shared location
  - saves disk space and makes addon updates easier
  - addons must be cloned to `{OF_ROOT}/addons` before building
- cross-platform support:
  - **Windows**: `projectUpdate.ps1` (PowerShell) + MSBuild
  - **macOS/Linux**: `projectUpdate.sh` (Bash) + Makefile
  - macOS/Linux Makefile auto-detects source files (no manual vcxproj)

## dependencies
### vscode
- WSL extension (for Windows WSL development)
### windows
- microsoft visual studio community 2022 (v143)
- **⚠️ REQUIRED**: UTF-8 system locale setting
  - Go to `제어판` (Control Panel) → `국가 및 지역` (Region) → `관리자 탭` (Administrative tab) → `시스템 로케일 변경` (Change system locale)
  - Check "`세계 언어 지원을 위해 Unicode UTF-8 사용(BETA)`" (Use Unicode UTF-8 for worldwide language support)
  - Reboot required
  - **Without this setting, you will encounter encoding errors in PowerShell scripts**
- **⚠️ REQUIRED**: Git configuration for cross-platform line endings
  - **When installing Git on Windows**, ensure the following settings:
    - Select: **"Checkout as-is, commit Unix-style line endings"**
    - OR configure manually after installation:
      \`\`\`bash
      git config --global core.autocrlf input
      \`\`\`
  - This prevents CRLF line ending issues when working with shell scripts
  - All scripts in this template use LF (Unix-style) line endings for cross-platform compatibility

### mac
- xcode command line tool

## how to use it

### Windows
1. clone this repo to \`{OF_ROOT}/apps/myApps/vsOFCodeTemplate\`
2. copy template folder to new project location
3. add addons to \`addons.make\` if needed
   - **addons must be cloned to \`{OF_ROOT}/addons\` first**
4. run \`projectUpdate.ps1\` (PowerShell) or use VSCode task
   - renames project to match folder name
   - scans `src/` and adds all source files to vcxproj
   - reads `addons.make` and configures addon references
   - generates vcxproj, filters, and sln from templates
5. when you add new files or addons, just run \`projectUpdate.ps1\` again
6. build with VSCode tasks or MSBuild

### macOS/Linux
1. clone this repo to \`{OF_ROOT}/apps/myApps/vsOFCodeTemplate\`
2. copy template folder to new project location
3. add addons to \`addons.make\` if needed
   - **addons must be cloned to \`{OF_ROOT}/addons\` first**
4. run \`./projectUpdate.sh\` in terminal
   - renames project to match folder name
   - configures VSCode IntelliSense for addons
5. when you add addons, run \`./projectUpdate.sh\` again
6. build with \`make Debug\` or \`make Release\`
   - Makefile auto-detects source files in `src/`

## extra tip

### Project Generator Function (pg)

Add this function to your shell configuration file to quickly create new projects from this template.

#### for WSL2 / Windows
Add to \`.bashrc\` or \`.zshrc\`:
> **Note**: Replace \`templateDir\` with your template location
> Project location should be \`{OF_ROOT}/{ANY}/{ANY}/{NEW_PROJECTNAME}\`

```bash
pg() {
  local newName="$1"
  local destDir="$(pwd)/$newName"
  local templateDir="/mnt/c/oF_vs/apps/myApps/vsOFCodeTemplate"

  if [ -z "$newName" ]; then
    echo "❌ Usage: pg <project-name>"
    return 1
  fi

  if [ -d "$destDir" ]; then
    echo "❌ '$destDir' already exists"
    return 1
  fi

  # rsync with exclusion rules
  rsync -av --exclude='bin/*.exe' \\
            --exclude='bin/*.dll' \\
            --exclude='obj/' \\
            --exclude='.vs/' \\
            --exclude='*.user' \\
            --exclude='*.suo' \\
            --exclude='.vscode/ipch/' \\
            --exclude='.git/' \\
            --exclude='.claude/' \\
            "$templateDir/" "$destDir/"

  # create README.md with project name as heading
  echo "# $newName" > "$destDir/README.md"

  # run PowerShell project update
  cd "$destDir" && \\
  powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w "$destDir/projectUpdate.ps1")"

  # open in VSCode
  cmd.exe /c "code $(wslpath -w "$destDir")" & disown
}

# PowerShell script aliases
alias psh='powershell.exe -ExecutionPolicy Bypass -File'
```

#### for macOS / Linux
Add to \`.bashrc\` or \`.zshrc\`:
> **Note**: Replace \`templateDir\` with your template location

```bash
pg() {
  local newName="$1"
  local destDir="$(pwd)/$newName"
  local templateDir="$HOME/oF/apps/myApps/vsOFCodeTemplate"  # adjust this path

  if [ -z "$newName" ]; then
    echo "❌ Usage: pg <project-name>"
    return 1
  fi

  if [ -d "$destDir" ]; then
    echo "❌ '$destDir' already exists"
    return 1
  fi

  # rsync with exclusion rules
  rsync -av --exclude='bin/' \\
            --exclude='obj/' \\
            --exclude='*.xcodeproj/xcuserdata/' \\
            --exclude='*.xcodeproj/project.xcworkspace/' \\
            --exclude='.vscode/ipch/' \\
            --exclude='.git/' \\
            --exclude='.claude/' \\
            "$templateDir/" "$destDir/"

  # create README.md with project name as heading
  echo "# $newName" > "$destDir/README.md"

  # run project update script
  cd "$destDir" || return 1

  # fix line endings (convert CRLF to LF) and make executable
  sed -i 's/\\r$//' projectUpdate.sh 2>/dev/null || \\
    sed -i '' 's/\\r$//' projectUpdate.sh 2>/dev/null
  chmod +x projectUpdate.sh

  # run the update script
  if ./projectUpdate.sh; then
    echo ""
    echo "✅ Project '$newName' created successfully!"
    echo "   Location: $destDir"
    echo ""
    echo "Next steps:"
    echo "  1. cd $newName"
    echo "  2. Add addons to addons.make if needed"
    echo "  3. Run ./projectUpdate.sh again if you add addons"
    echo "  4. Build with 'make Debug' or 'make Release'"
  else
    echo "❌ Error: projectUpdate.sh failed"
    return 1
  fi

  code .
}
```

**What this script does:**
- Clone template folder to new project directory
- Exclude build artifacts and IDE-specific files (`.git/`, `.claude/`, `bin/`, `obj/`, etc.)
- Reset README.md with project name
- Run unified `projectUpdate` script to configure project
- (WSL only) Open project in VSCode
