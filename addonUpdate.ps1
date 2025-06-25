$ErrorActionPreference = "Stop"

# 1. project locations
$projectDir = Get-Location
$projectName = Split-Path $projectDir -Leaf
$vcxprojPath = "$projectDir\$projectName.vcxproj"
$filtersPath = "$projectDir\$projectName.vcxproj.filters"
$addonFile = "$projectDir\addon.make"
$addonDest = "$projectDir\addons"

# ✅ 2. openFrameworks relative root location
$oFRoot = Resolve-Path "$projectDir\..\..\.."  

# 3. copy addons by addon.make
if (Test-Path $addonFile) {
    $addons = Get-Content $addonFile | Where-Object { $_ -and -not $_.StartsWith("#") }
    foreach ($addon in $addons) {
        $src = Join-Path "$oFRoot\addons" $addon
        $dst = Join-Path $addonDest (Split-Path $addon -Leaf)
        if (-Not (Test-Path $dst)) {
            Write-Output "📦 Copying addon: $addon"
            Copy-Item -Recurse -Force $src $dst
        }
    }
}

# 4. update .vcxproj 
[xml]$proj = Get-Content $vcxprojPath
$ns = @{ "msb" = "http://schemas.microsoft.com/developer/msbuild/2003" }
$projRoot = $proj.Project

function Add-ItemGroupEntry($itemType, $relativePath) {
    $itemGroup = $proj.CreateElement("ItemGroup", $projRoot.NamespaceURI)
    $fileNode = $proj.CreateElement($itemType, $projRoot.NamespaceURI)
    $fileNode.SetAttribute("Include", $relativePath)
    $itemGroup.AppendChild($fileNode) | Out-Null
    $projRoot.AppendChild($itemGroup) | Out-Null
}

$existingIncludes = $proj.SelectNodes("//msb:ClInclude", $ns) | ForEach-Object { $_.Include }
$existingCompiles = $proj.SelectNodes("//msb:ClCompile", $ns) | ForEach-Object { $_.Include }

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
Write-Output "✅ Updated $vcxprojPath"

# 5. generate .filters 
$filtersXml = @"
<Project ToolsVersion="4.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup>
"@

function Make-Filter($path) {
    $parts = $path -split '[\\/]', 0, 'SimpleMatch'
    if ($parts.Length -gt 1) {
        return ($parts[0..($parts.Length - 2)] -join '\')
    } else {
        return ""
    }
}

$filterMap = @{}
$files = Get-ChildItem -Recurse -Include *.h,*.hpp,*.cpp,*.c -Path "$projectDir\src", "$projectDir\addons"

foreach ($file in $files) {
    $relPath = $file.FullName.Replace("$projectDir\", "").Replace("\", "/")
    $filter = Make-Filter($relPath)
    $type = if ($file.Extension -match "\.h|\.hpp") { "ClInclude" } else { "ClCompile" }
    $escapedPath = $relPath -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'

    $filtersXml += "    <$type Include=`"$escapedPath`">`n"
    if ($filter -ne "") {
        $filtersXml += "      <Filter>$filter</Filter>`n"
        $filterMap[$filter] = $true
    }
    $filtersXml += "    </$type>`n"
}

$filtersXml += "  </ItemGroup>`n<ItemGroup>`n"
foreach ($f in $filterMap.Keys) {
    $filtersXml += "    <Filter Include=`"$f`">`n"
    $filtersXml += "      <UniqueIdentifier>{$(New-Guid).ToString()}</UniqueIdentifier>`n"
    $filtersXml += "    </Filter>`n"
}
$filtersXml += "  </ItemGroup>`n</Project>"

Set-Content -Path $filtersPath -Value $filtersXml -Encoding UTF8
Write-Output "✅ Generated $filtersPath"
