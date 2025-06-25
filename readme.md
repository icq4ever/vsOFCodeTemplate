# openFrameworks empty project template for vscode with msbuild

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

## dependencies
- microsoft visual studio community 2022 (v143)
- vscode

## how to use it
1. clone this repo : `{OF_ROOT}/apps/myApps/oFVSCodeExample`
2. copy to new Folder
3. run `projectUpdate` task
4. when addon added on `addons.make`, run `addonUpdate` task. addon should already clone to `{OF_ROOT}/addons`
5. can build project with with `tasks`

## tip for WSL2
add this alias on `.bashrc` or `.zshrc`.<br/>
you can generate `$ pg newProject` command on linux shell, anywhere you want.<br/>
> **mind that you should replace `local templateDir` to your template location**
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

  # rsync with exclusion rules
  rsync -av --exclude='bin/*.exe' \
            --exclude='bin/*.dll' \
            --exclude='obj/' \
            --exclude='.vs/' \
            --exclude='*.user' \
            --exclude='*.suo' \
            --exclude='.vscode/ipch/' \
            "$templateDir/" "$destDir/"

  cd "$destDir" && \
  powershell.exe -ExecutionPolicy Bypass -File "$(wslpath -w "$destDir/projectUpdate.ps1")"

  code . & disown
}
```