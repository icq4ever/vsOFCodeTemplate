$ErrorActionPreference = "Stop"

# Get current project info
$projectDir = Get-Location
$projectName = Split-Path $projectDir -Leaf
$vcxprojPath = Join-Path $projectDir "$projectName.vcxproj"
$filtersPath = Join-Path $projectDir "$projectName.vcxproj.filters"
$addonFile = Join-Path $projectDir "addon.make"
$addonDest = Join-Path $projectDir "addons"
$cppPropsPath = Join-Path $projectDir ".vscode\c_cpp_properties.json"

# Determine openFrameworks root
$oFRoot = Resolve-Path "$projectDir\..\..\.."

# 1. Copy addons
if (Test-Path $addonFile) {
    $addons = Get-Content $addonFile | Where-Object { $_ -and -not $_.StartsWith("#") }
    foreach ($addon in $addons) {
        $src = Join-Path $oFRoot "addons\$addon"
        $dst = Join-Path $addonDest (Split-Path $addon -Leaf)
        if (-not (Test-Path $dst)) {
            Write-Host "📦 Copying addon: $addon"
            Copy-Item -Recurse -Force $src $dst
        }
    }
}

# 2. Update .vcxproj (remove old, add new)
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

$srcFiles = Get-ChildItem -Recurse -Include *.h,*.hpp,*.cpp,*.c -Path "$projectDir\src", "$projectDir\addons"
foreach ($file in $srcFiles) {
    $relPath = $file.FullName.Replace("$projectDir\", "").Replace("\", "/")
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

# 4. Update c_cpp_properties.json for includePath
$includePaths = @(
    "src",
    "addons/*/src",
    "../../libs/**/include",
    "../../addons/**/src"
)

$cppJson = @{
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
    version = 4
}

$cppJson | ConvertTo-Json -Depth 5 | Set-Content $cppPropsPath -Encoding UTF8
Write-Host "✅ Updated $cppPropsPath"
