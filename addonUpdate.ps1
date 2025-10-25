$ErrorActionPreference = "Stop"

# Get current project info
$projectDir = Get-Location
$projectName = Split-Path $projectDir -Leaf
$vcxprojPath = Join-Path $projectDir "$projectName.vcxproj"
$filtersPath = Join-Path $projectDir "$projectName.vcxproj.filters"
$addonFile = Join-Path $projectDir "addons.make"
$cppPropsPath = Join-Path $projectDir ".vscode\c_cpp_properties.json"

# Determine openFrameworks root
$oFRoot = Resolve-Path "$projectDir\..\..\.."

# Read addons from addons.make
$addons = @()
if (Test-Path $addonFile) {
    $addons = Get-Content $addonFile | Where-Object { $_ -and -not $_.StartsWith("#") }
    Write-Host "📦 Found addons: $($addons -join ', ')"
}

# Update .vcxproj (remove old, add new)
[xml]$proj = Get-Content $vcxprojPath
$projRoot = $proj.Project

# Remove previous ClInclude/ClCompile ItemGroups
$nsMgr = New-Object System.Xml.XmlNamespaceManager($proj.NameTable)
$nsMgr.AddNamespace("ns", $projRoot.NamespaceURI)

$oldNodes = $projRoot.SelectNodes("//ns:ItemGroup[ns:ClInclude or ns:ClCompile]", $nsMgr)
foreach ($node in $oldNodes) {
    $projRoot.RemoveChild($node) | Out-Null
}

# Add new files from src and addons
function Add-ItemGroupEntry {
    param($type, $relativePath)
    $group = $proj.CreateElement("ItemGroup", $projRoot.NamespaceURI)
    $item = $proj.CreateElement($type, $projRoot.NamespaceURI)
    $item.SetAttribute("Include", $relativePath)
    $group.AppendChild($item) | Out-Null
    $projRoot.AppendChild($group) | Out-Null
}

# Collect all source files
$srcFiles = @()

# Add src files
$srcFiles += Get-ChildItem -Recurse -Include *.h,*.hpp,*.cpp,*.c -Path "$projectDir\src"

# Add addon files from {OF_ROOT}/addons
foreach ($addon in $addons) {
    $addonPath = Join-Path $oFRoot "addons\$addon"
    if (Test-Path $addonPath) {
        $addonFiles = Get-ChildItem -Recurse -Include *.h,*.hpp,*.cpp,*.c -Path $addonPath
        $srcFiles += $addonFiles
    }
}

# Add files to vcxproj
foreach ($file in $srcFiles) {
    # Use relative path from project directory
    if ($file.FullName.StartsWith("$projectDir\")) {
        # Files in src/
        $relPath = $file.FullName.Replace("$projectDir\", "").Replace("\", "/")
    } else {
        # Files in {OF_ROOT}/addons - use relative path
        $relPath = $file.FullName.Replace("$oFRoot\", "..\..\..\").Replace("\", "/")
    }

    if ($file.Extension -match "\.h|\.hpp") {
        Add-ItemGroupEntry -type "ClInclude" -relativePath $relPath
    } else {
        Add-ItemGroupEntry -type "ClCompile" -relativePath $relPath
    }
}

$proj.Save($vcxprojPath)
Write-Host "✅ Updated $vcxprojPath"

# 3. Generate .filters file
function Make-Filter {
    param($path)
    $parts = $path -split '[\\/]', 0, 'SimpleMatch'
    if ($parts.Length -gt 1) {
        return ($parts[0..($parts.Length - 2)] -join '\')
    }
    return ""
}

$filtersXml = "<Project ToolsVersion=`"4.0`" xmlns=`"http://schemas.microsoft.com/developer/msbuild/2003`">`n"
$filtersXml += "  <ItemGroup>`n"
$filterMap = @{}
foreach ($file in $srcFiles) {
    $relPath = $file.FullName.Replace("$projectDir\", "").Replace("\", "/")
    $filter = Make-Filter $relPath
    $type = if ($file.Extension -match "\.h|\.hpp") { "ClInclude" } else { "ClCompile" }
    $escapedPath = $relPath -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'

    $filtersXml += '    <' + $type + ' Include="' + $escapedPath + '">' + "`n"
    if ($filter -ne "") {
        $filtersXml += "      <Filter>$filter</Filter>`n"
        $filterMap[$filter] = $true
    }
    $filtersXml += '    </' + $type + '>' + "`n"
}
$filtersXml += "  </ItemGroup>`n  <ItemGroup>`n"
foreach ($f in $filterMap.Keys) {
    $filtersXml += '    <Filter Include="' + $f + '">' + "`n"
    $filtersXml += "      <UniqueIdentifier>{$(New-Guid)}</UniqueIdentifier>`n"
    $filtersXml += "    </Filter>`n"
}
$filtersXml += "  </ItemGroup>`n</Project>"

Set-Content -Path $filtersPath -Value $filtersXml -Encoding UTF8
Write-Host "✅ Generated $filtersPath"

# Update c_cpp_properties.json for includePath
$includePaths = @(
    "`${workspaceFolder}/src",
    "`${workspaceFolder}/src/**",
    "`${workspaceFolder}/../../../addons/*/src",
    "`${workspaceFolder}/../../../addons/*/include",
    "`${workspaceFolder}/../../../addons/**/src",
    "`${workspaceFolder}/../../../libs/openFrameworks/**",
    "`${workspaceFolder}/../../../libs/**/include"
)

# Load existing configuration or create new one
if (Test-Path $cppPropsPath) {
    $cppJson = Get-Content $cppPropsPath -Raw | ConvertFrom-Json

    # Find and update Win64 configuration
    $win64Config = $cppJson.configurations | Where-Object { $_.name -eq "Win64" }
    if ($win64Config) {
        $win64Config.includePath = $includePaths
    } else {
        # Add Win64 configuration if it doesn't exist
        $newWin64Config = @{
            name = "Win64"
            includePath = $includePaths
            defines = @()
            compilerPath = "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/*/bin/Hostx64/x64/cl.exe"
            cStandard = "c17"
            cppStandard = "c++17"
            intelliSenseMode = "windows-msvc-x64"
        }
        $cppJson.configurations += $newWin64Config
    }
} else {
    # Create new configuration file
    $cppJson = @{
        version = 4
        configurations = @(
            @{
                name = "Win64"
                includePath = $includePaths
                defines = @()
                compilerPath = "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/*/bin/Hostx64/x64/cl.exe"
                cStandard = "c17"
                cppStandard = "c++17"
                intelliSenseMode = "windows-msvc-x64"
            }
        )
    }
}

# Save with 2-space indentation
$cppJson | ConvertTo-Json -Depth 5 | Set-Content $cppPropsPath -Encoding UTF8
Write-Host "✅ Updated $cppPropsPath"
