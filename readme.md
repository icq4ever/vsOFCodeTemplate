# openFrameworks empty project template for vscode support msbuild on windows

this template is include :
- build/run/update addon tasks for vscode 
- launching debug/release app
- read addon.make and update addon, vs filter update using powershell script

## why made this ?
- in visual studio, adding new files are so annoying
- everytime add new addon, project should be update by `projectGenerator`
- visual studio is too heavy

## feature
- support vcxproj update
- addon update (copy from `{OF_ROOT}/addon` to local `addon`)
- addonUpdate / projectUpdate using powershell script
- mac/linux still can build, run by `make Debug`, `make Debug`, `make RunDebug`, `make RunRelease` in terminal

## dependencies 
### windows
- microsoft visual studio community 2022 (v143)

### mac
- xcode command line tool

## how to use it
1. clone this repo : `{OF_ROOT}/apps/myApps/oFVSCodeExample`
2. copy to new Folder
3. run `projectUpdate` task
4. when addon added on `addons.make`, run `addonUpdate` task. addon should already clone to `{OF_ROOT}/addons`
5. can build project with with `tasks`

## extra tip

### for WSL2
add this alias on `.bashrc` or `.zshrc`.<br/>
you can generate `$ pg newProjectName` on linux shell, anywhere you want.<br/>
> **mind that you should replace `local templateDir` to your template location**.<br/>
> project location should be `{OF_ROOT}/{ANY}/{ANY}/{NEW_PROJECTNAME}`
```
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

  # rsync with exclusion rules, including .git
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

  # open in VSCode, in windows!
  cmd.exe /c "code $(wslpath -w "$destDir")" & disown
}

```
- this script doing ...
  - clone folder and rename folder 
  - reset git info
  - readme.md will be resets

### broken characters on windows terminal? (like Korean Windows)
- `제어판` / `국가 및 지역` / `관리자 탭` / 시스템 로케일 변경 에 들어간 뒤
  - "`세계 언어 지원을 위해 Unicode UTF-8 사용(BETA)` 체크 후 재부팅 