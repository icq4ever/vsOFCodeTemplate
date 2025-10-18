# openFrameworks empty project template for cross-platform vscode setup

this template is include :
- support msbuild on windows
- build/run/update addon tasks for vscode on windows/linux/mac
- launching debug/release app
- read addon.make and update addon, vs filter update using powershell script
- run powershell script on WSL (with alias)

## why made this ?
- in visual studio, adding new files are so annoying
- everytime add new addon, project should be update by `projectGenerator`
- visual studio is too heavy

## feature
- support vcxproj update (Windows)
- addon update (copy from `{OF_ROOT}/addons` to local `addons`)
- addonUpdate / projectUpdate scripts:
  - **Windows**: `addonUpdate.ps1`, `projectUpdate.ps1` (PowerShell)
  - **macOS/Linux**: `addonUpdate.sh`, `projectUpdate.sh` (Bash)
- cross-platform build support:
  - **Windows**: MSBuild via Visual Studio tasks
  - **macOS/Linux**: `make Debug`, `make Release`, `make RunDebug`, `make RunRelease`

## dependencies
### vscode
- WSL extension (for Windows WSL development)
### common
- rsync
### windows
- microsoft visual studio community 2022 (v143)- rsync (WSL)
- **⚠️ REQUIRED**: UTF-8 system locale setting
  - Go to `제어판` (Control Panel) → `국가 및 지역` (Region) → `관리자 탭` (Administrative tab) → `시스템 로케일 변경` (Change system locale)
  - Check "`세계 언어 지원을 위해 Unicode UTF-8 사용(BETA)`" (Use Unicode UTF-8 for worldwide language support)
  - Reboot required
  - **Without this setting, you will encounter encoding errors in PowerShell scripts**

### mac
- xcode command line tool

## how to use it

### Windows
1. clone this repo : `{OF_ROOT}/apps/myApps/vsOFCodeExample`
2. copy to new folder
3. run `projectUpdate.ps1` (PowerShell) or use VSCode task
4. when addon added on `addons.make`, run `addonUpdate.ps1` or use VSCode task
   - addon should already be cloned to `{OF_ROOT}/addons`
5. build project with VSCode tasks

### macOS/Linux
1. clone this repo : `{OF_ROOT}/apps/myApps/vsOFCodeExample`
2. copy to new folder
3. run `./projectUpdate.sh` in terminal
4. when addon added on `addons.make`, run `./addonUpdate.sh`
   - addon should already be cloned to `{OF_ROOT}/addons`
5. build project with `make Debug` or `make Release`

## extra tip

### Project Generator Function (pg)

Add this function to your shell configuration file to quickly create new projects from this template.

#### for WSL2 / Windows
Add to `.bashrc` or `.zshrc`:
> **Note**: Replace `templateDir` with your template location
> Project location should be `{OF_ROOT}/{ANY}/{ANY}/{NEW_PROJECTNAME}`

```bash
pg() {
  local newName="$1"
  local destDir="$(pwd)/$newName"
  local templateDir="/mnt/c/oF_vs/apps/myApps/vsOFCodeExample"

  if [ -z "$newName" ]; then
    echo "❌ Usage: pg <project-name>"
    return 1
  fi

  if [ -d "$destDir" ]; then
    echo "❌ '$destDir' already exists"
    return 1
  fi

  # rsync with exclusion rules
  rsync -av --exclude='bin/*.exe' \
            --exclude='bin/*.dll' \
            --exclude='obj/' \
            --exclude='.vs/' \
            --exclude='*.user' \
            --exclude='*.suo' \
            --exclude='.vscode/ipch/' \
            --exclude='.git/' \
            "$templateDir/" "$destDir/"

  # create README.md with project name as heading
  echo "# $newName" > "$destDir/README.md"

  # run PowerShell project update
  cd "$destDir" && \
  powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w "$destDir/projectUpdate.ps1")"

  # open in VSCode
  cmd.exe /c "code $(wslpath -w "$destDir")" & disown
}

# PowerShell script aliases
alias psh='powershell.exe -ExecutionPolicy Bypass -File'
```

#### for macOS / Linux
Add to `.bashrc` or `.zshrc`:
> **Note**: Replace `templateDir` with your template location

```bash
pg() {
  local newName="$1"
  local destDir="$(pwd)/$newName"
  local templateDir="$HOME/oF/apps/myApps/vsOFCodeExample"  # adjust this path

  if [ -z "$newName" ]; then
    echo "❌ Usage: pg <project-name>"
    return 1
  fi

  if [ -d "$destDir" ]; then
    echo "❌ '$destDir' already exists"
    return 1
  fi

  # rsync with exclusion rules
  rsync -av --exclude='bin/' \
            --exclude='obj/' \
            --exclude='*.xcodeproj/xcuserdata/' \
            --exclude='*.xcodeproj/project.xcworkspace/' \
            --exclude='.vscode/ipch/' \
            --exclude='.git/' \
            "$templateDir/" "$destDir/"

  # create README.md with project name as heading
  echo "# $newName" > "$destDir/README.md"

  # run project update script
  cd "$destDir" || return 1

  # fix line endings (convert CRLF to LF) and make executable
  sed -i 's/\r$//' projectUpdate.sh addonUpdate.sh 2>/dev/null || \
    sed -i '' 's/\r$//' projectUpdate.sh addonUpdate.sh 2>/dev/null
  chmod +x projectUpdate.sh addonUpdate.sh

  # run the update script
  if ./projectUpdate.sh; then
    echo ""
    echo "✅ Project '$newName' created successfully!"
    echo "   Location: $destDir"
    echo ""
    echo "Next steps:"
    echo "  1. cd $newName"
    echo "  2. Add addons to addons.make if needed"
    echo "  3. Run ./addonUpdate.sh to sync addons"
    echo "  4. Build with 'make Debug' or 'make Release'"
  else
    echo "❌ Error: projectUpdate.sh failed"
    return 1
  fi
}
```

**What this script does:**
- Clone template folder to new project directory
- Exclude build artifacts and IDE-specific files
- Reset README.md with project name
- Run appropriate update script (`.ps1` for Windows, `.sh` for macOS/Linux)
- (WSL only) Open project in VSCode
