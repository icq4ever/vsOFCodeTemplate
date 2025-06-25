$ErrorActionPreference = "Stop"

# Project information
$projectDir = Get-Location
$projectName = Split-Path $projectDir -Leaf
$vcxprojPath = "$projectDir\$projectName.vcxproj"
$filtersPath = "$projectDir\$projectName.vcxproj.filters"
$addonFile = "$projectDir\addon.make"
$addonDest = "$projectDir\addons"
$cppPropsPath = "$projectDir\.vscode\c_cpp_properties.json"

# Find openFrameworks root relative to this project
$oFRoot = Resolve-Path "$projectDir\..\..\.."

# Step 1: Copy addons
if (Test-Path $addonFile) {
    $addons = Get-Content $addonFile | Where-Object { $_ -and -not $_.StartsWith("#") }
    foreach ($addon in $addons) {
        $src = Join-Path "$oFRoot\addons" $addon
        $dst = Join-Path $addonDest (Split-Path $addon -Leaf)
        if (-not (Test-Path $dst)) {
            Write-Host "📦 Copying addon: $addon"
            Copy-Item -Recurse -Force $src $dst
        }
    }
}

# Step 2: Update .vcxproj with ClInclude / ClCompile
[xml]$proj = Get-Content $vcxprojPath
$projRoot = $proj.Project
$nsMgr = New-Object System.Xml.XmlNamespaceManager($proj.NameTable)
$nsMgr.AddNamespace("ns", $proj.DocumentElement.NamespaceURI)

function Add-ItemGroupEntry {
    param ($itemType, $relativePath)
    $itemGroup = $proj.CreateElement("ItemGroup", $proj.DocumentElement.NamespaceURI)
    $node = $proj.CreateElement($itemType, $proj.DocumentElement.NamespaceURI)
    $node.SetAttribute("Include", $relativePath)
    $itemGroup.AppendChild($node) | Out-Null
    $projRoot.AppendChild($itemGroup) | Out-Null
}

$existingIncludes = $projRoot.SelectNodes("//ns:ClInclude", $nsMgr) | ForEach-Object { $_.Include }
$existingCompiles = $projRoot.SelectNodes("//ns:ClCompile", $nsMgr) | ForEach-Object { $_.Include }

$allFiles = Get-ChildItem -Recurse -Include *.h,*.hpp,*.cpp,*.c -Path "$projectDir\src", "$projectDir\addons"

foreach ($file in $allFiles) {
    $relPath = $file.FullName.Replace("$projectDir\", "").Replace("\", "/")
    if ($file.Extension -match "\.h|\.hpp") {
        if (-not $existingIncludes.Contains($relPath)) {
            Add-ItemGroupEntry "ClInclude" $relPath
        }
    } elseif ($file.Extension -match "\.cpp|\.c") {
        if (-not $existingCompiles.Contains($relPath)) {
            Add-ItemGroupEntry "ClCompile" $relPath
        }
    }
}

$proj.Save($vcxprojPath)
Write-Host "✅ Updated $vcxprojPath"

# Step 3: Generate .filters
function Make-Filter($path) {
    $parts = $path -split "[\\/]"
    if ($parts.Length -gt 1) {
        return ($parts[0..($parts.Length - 2)] -join '\')
    } else {
        return ""
    }
}

$filtersXml = @()
$filtersXml += '<?xml version="1.0" encoding="utf-8"?>'
$filtersXml += '<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">'
$filtersXml += '  <ItemGroup>'

$filterMap = @{}
foreach ($file in $allFiles) {
    $relPath = $file.FullName.Replace("$projectDir\", "").Replace("\", "/")
    $filter = Make-Filter $relPath
    $type = if ($file.Extension -match "\.h|\.hpp") { "ClInclude" } else { "ClCompile" }
    $filtersXml += "    <$type Include='" + $relPath + "'>"
    if ($filter -ne "") {
        $filtersXml += "      <Filter>" + $filter + "</Filter>"
        $filterMap[$filter] = $true
    }
    $filtersXml += "    </$type>"
}

$filtersXml += '  </ItemGroup>'
$filtersXml += '  <ItemGroup>'

foreach ($f in $filterMap.Keys) {
    $guid = [guid]::NewGuid().ToString()
    $filtersXml += "    <Filter Include='" + $f + "'>"
    $filtersXml += "      <UniqueIdentifier>{" + $guid + "}</UniqueIdentifier>"
    $filtersXml += "    </Filter>"
}

$filtersXml += '  </ItemGroup>'
$filtersXml += '</Project>'

$filtersXml -join "`r`n" | Set-Content -Encoding UTF8 $filtersPath
Write-Host "✅ Generated $filtersPath"

# Step 4: Update c_cpp_properties.json for IntelliSense
$includePaths = @(
    "$oFRoot/libs/openFrameworks/**",
    "$projectDir/src",
    "$projectDir/addons/**"
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