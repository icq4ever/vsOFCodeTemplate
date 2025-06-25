# openFrameworks template for vscode with msbuild

this template is include :
- build/run/update addon tasks for vscode 
- launching for debug/release app
- read addon.make and update addon, vs filter update using powershell script

# why made this ?
- in visual studio, adding new files are so annoying
- everytime add new addon, project should be update by `projectGenerator`
- visual studio is too heavy

# dependencies
- microsoft visual studio community 2022 (v143)
- vscode

# how to use it
## build 
in visual studio code, `ctrl + shift + P` and `Tasks: run task`. 