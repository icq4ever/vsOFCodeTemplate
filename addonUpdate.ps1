$ErrorActionPreference = "Stop"

# Get current project info
$projectDir = Get-Location
$projectName = Split-Path $projectDir -Leaf
$vcxprojPath = Join-Path $projectDir "$projectName.vcxproj"
$filtersPath = Join-Path $projectDir "$projectName.vcxproj.filters"
$addonFile = Join-Path $projectDir "addons.make"
$addonDest = Join-Path $projectDir "addons"
$cppPropsPath = Join-Path $projectDir ".vscode\c_cpp_properties.json"

# Determine openFrameworks root
$oFRoot = Resolve-Path "$projectDir\..\..\.."

# 0. Clean up outdated addons
if (Test-Path $addonDest) {
    $existingAddons = Get-ChildItem -Directory $addonDest | Select-Object -ExpandProperty Name
    $usedAddons = Get-Content $addonFile | Where-Object { $_ -and -not $_.StartsWith("#") } | ForEach-Object { Split-Path $_ -Leaf }

    $addonsToRemove = $existingAddons | Where-Object { $_ -notin $usedAddons }
    foreach ($unused in $addonsToRemove) {
        $unusedPath = Join-Path $addonDest $unused
        Write-Host "🧹 Removing unused addon: $unused"
        Remove-Item -Recurse -Force $unusedPath
    }
}

# 1. Copy addons (exclude example, test, sample, demo folders)
if (Test-Path $addonFile) {
    $addons = Get-Content $addonFile | Where-Object { $_ -and -not $_.StartsWith("#") }
    foreach ($addon in $addons) {
        $src = Join-Path $oFRoot "addons\$addon"
        $dst = Join-Path $addonDest (Split-Path $addon -Leaf)
        if (-not (Test-Path $dst)) {
            Write-Host "📦 Copying addon: $addon"

            # Create destination folder
            New-Item -ItemType Directory -Force -Path $dst | Out-Null

            # Copy all items except example/test/sample/demo folders
            Get-ChildItem -Path $src | Where-Object {
                -not ($_.Name -match '^(example|test|sample|demo)')
            } | ForEach-Object {
                Copy-Item -Recurse -Force $_.FullName (Join-Path $dst $_.Name)
            }
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

# Collect source files from src/ and specific addon folders only (whitelist approach)
$srcPaths = @("$projectDir\src")

# Add addon src, include, and libs folders only
if (Test-Path "$projectDir\addons") {
    Get-ChildItem -Directory "$projectDir\addons" | ForEach-Object {
        $addonPath = $_.FullName
        # Include src, include, and libs folders from each addon
        @("src", "include", "libs") | ForEach-Object {
            $subFolder = Join-Path $addonPath $_
            if (Test-Path $subFolder) {
                $srcPaths += $subFolder
            }
        }
    }
}

$srcFiles = Get-ChildItem -Recurse -Include *.h,*.hpp,*.cpp,*.c -Path $srcPaths

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
    "`${workspaceFolder}/src/**",
    "`${workspaceFolder}/addons/*/src",
    "`${workspaceFolder}/addons/*/include",
    "`${workspaceFolder}/addons/*/libs/**",
    "`${workspaceFolder}/../../../libs/openFrameworks/**",
    "`${workspaceFolder}/../../../libs/**/include"
)

# Load existing c_cpp_properties.json if it exists
if (Test-Path $cppPropsPath) {
    $existingJson = Get-Content $cppPropsPath -Raw | ConvertFrom-Json

    # Find Windows configuration (Win64, Win32, Windows, etc.)
    $winConfig = $existingJson.configurations | Where-Object { $_.name -match "Win" }

    if ($winConfig) {
        # Update only Windows configuration
        $winConfig.includePath = $includePaths
        Write-Host "✅ Updated $cppPropsPath (Win64 configuration only)"
    } else {
        # Add new Windows configuration if not exists
        $newWinConfig = @{
            name = "Win64"
            includePath = $includePaths
            defines = @()
            compilerPath = "C:/Program Files/Microsoft Visual Studio/2022/Community/VC/Tools/MSVC/*/bin/Hostx64/x64/cl.exe"
            cStandard = "c17"
            cppStandard = "c++17"
            intelliSenseMode = "windows-msvc-x64"
        }
        $existingJson.configurations += $newWinConfig
        Write-Host "✅ Added Win64 configuration to $cppPropsPath"
    }

    $existingJson | ConvertTo-Json -Depth 5 | Set-Content $cppPropsPath -Encoding UTF8
} else {
    # Create new file if it doesn't exist
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
    Write-Host "✅ Created $cppPropsPath"
}
