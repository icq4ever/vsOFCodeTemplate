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