$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  openFrameworks Project Update Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# 1. Get project info and paths
# ============================================================================
$projectDir = Get-Location
$projectName = Split-Path $projectDir -Leaf
$oFRoot = Resolve-Path "$projectDir\..\..\.."

$vcxprojPath = Join-Path $projectDir "$projectName.vcxproj"
$filtersPath = Join-Path $projectDir "$projectName.vcxproj.filters"
$slnPath = Join-Path $projectDir "$projectName.sln"
$addonFile = Join-Path $projectDir "addons.make"

Write-Host "📁 Project: $projectName" -ForegroundColor Green
Write-Host "📁 Location: $projectDir" -ForegroundColor Green
Write-Host "📁 OF Root: $oFRoot" -ForegroundColor Green
Write-Host ""

# ============================================================================
# 2. Remove old template project files if they exist
# ============================================================================
$oldFiles = @(
    "vsOFCodeTemplate.vcxproj",
    "vsOFCodeTemplate.vcxproj.filters",
    "vsOFCodeTemplate.vcxproj.user",
    "vsOFCodeTemplate.sln"
)

foreach ($oldFile in $oldFiles) {
    $oldPath = Join-Path $projectDir $oldFile
    if ((Test-Path $oldPath) -and ($oldFile -ne "$projectName.vcxproj") -and ($oldFile -ne "$projectName.vcxproj.filters") -and ($oldFile -ne "$projectName.sln")) {
        Remove-Item $oldPath -Force
        Write-Host "🗑️  Removed old file: $oldFile" -ForegroundColor Yellow
    }
}

# ============================================================================
# 3. Find template files from emptyExample
# ============================================================================
$emptyExampleDir = Join-Path $oFRoot "apps\myApps\emptyExample"
$vcxprojTemplate = Join-Path $emptyExampleDir "emptyExample.vcxproj"
$filtersTemplate = Join-Path $emptyExampleDir "emptyExample.vcxproj.filters"
$slnTemplate = Join-Path $emptyExampleDir "emptyExample.sln"

if (-not (Test-Path $vcxprojTemplate)) {
    Write-Host "❌ Template file not found: $vcxprojTemplate" -ForegroundColor Red
    Write-Host "   Make sure emptyExample exists at: $emptyExampleDir" -ForegroundColor Red
    exit 1
}

# ============================================================================
# 4. Read addons from addons.make
# ============================================================================
$addons = @()
if (Test-Path $addonFile) {
    $addons = Get-Content $addonFile | Where-Object { $_ -and -not $_.StartsWith("#") }
    if ($addons.Count -gt 0) {
        Write-Host "📦 Found addons:" -ForegroundColor Yellow
        foreach ($addon in $addons) {
            Write-Host "   - $addon" -ForegroundColor Yellow
        }
        Write-Host ""
    }
}

# ============================================================================
# 4. Collect source files
# ============================================================================
Write-Host "🔍 Scanning for source files..." -ForegroundColor Cyan

$allSourceFiles = @()

# Scan src/ directory
if (Test-Path "$projectDir\src") {
    $srcFiles = Get-ChildItem -Recurse -Include *.h,*.hpp,*.cpp,*.c -Path "$projectDir\src"
    $allSourceFiles += $srcFiles
    Write-Host "   ✓ Found $($srcFiles.Count) files in src/" -ForegroundColor Green
}

# Scan addon directories
$addonIncludeDirs = @()
$addonProjectRefs = @()

foreach ($addon in $addons) {
    $addonPath = Join-Path $oFRoot "addons\$addon"
    if (Test-Path $addonPath) {
        # Collect addon include directories
        $addonIncludeDirs += "..\..\..\addons\$addon\src"
        
        $includeDir = Join-Path $addonPath "include"
        if (Test-Path $includeDir) {
            $addonIncludeDirs += "..\..\..\addons\$addon\include"
        }
        
        $libsDir = Join-Path $addonPath "libs"
        if (Test-Path $libsDir) {
            $libSubDirs = Get-ChildItem -Directory -Path $libsDir -Recurse | Where-Object { $_.Name -match "^(include|src)$" }
            foreach ($subDir in $libSubDirs) {
                $relPath = $subDir.FullName.Replace("$oFRoot\", "..\..\..\").Replace("\", "\")
                $addonIncludeDirs += $relPath
            }
        }

        # Find addon source files (only from src, include, libs)
        $allowedDirs = @("src", "include", "libs")
        foreach ($dir in $allowedDirs) {
            $targetPath = Join-Path $addonPath $dir
            if (Test-Path $targetPath) {
                $addonFiles = Get-ChildItem -Recurse -Include *.h,*.hpp,*.cpp,*.c -Path $targetPath
                $allSourceFiles += $addonFiles
            }
        }

        # Find addon .vcxproj files for ProjectReference
        $addonVcxprojs = Get-ChildItem -Path $addonPath -Filter "*.vcxproj" -Recurse | Where-Object {
            $_.FullName -notmatch '\\(example|examples|test|tests|sample|samples|demo|demos)\\'
        }
        
        foreach ($vcxproj in $addonVcxprojs) {
            $vcxprojContent = Get-Content $vcxproj.FullName -Raw
            if ($vcxprojContent -match '<ProjectGuid>\{([^}]+)\}</ProjectGuid>') {
                $guid = "{$($matches[1])}"
                $relPath = $vcxproj.FullName.Replace("$oFRoot\", "..\..\..\").Replace("\", "\")
                $addonProjectRefs += @{
                    Guid = $guid
                    Path = $relPath
                }
            }
        }
    }
}

Write-Host "   ✓ Total source files: $($allSourceFiles.Count)" -ForegroundColor Green
Write-Host ""

# ============================================================================
# 6. Generate vcxproj from template
# ============================================================================
Write-Host "📝 Generating $projectName.vcxproj..." -ForegroundColor Cyan

# Load template
[xml]$vcxproj = Get-Content $vcxprojTemplate
$ns = $vcxproj.Project.NamespaceURI

# Update project name
$rootNsNode = $vcxproj.Project.PropertyGroup | Where-Object { $_.RootNamespace } | Select-Object -First 1
if ($rootNsNode -and $rootNsNode.RootNamespace) {
    $rootNsNode.RootNamespace = [string]$projectName
}

# Remove existing ClCompile and ClInclude ItemGroups
$itemGroupsToRemove = $vcxproj.Project.ItemGroup | Where-Object { 
    $_.ClCompile -or $_.ClInclude 
}
foreach ($ig in $itemGroupsToRemove) {
    $vcxproj.Project.RemoveChild($ig) | Out-Null
}

# Create new ItemGroups
$compileGroup = $vcxproj.CreateElement("ItemGroup", $ns)
$includeGroup = $vcxproj.CreateElement("ItemGroup", $ns)

# Add source files with deduplication
$addedFiles = @{}
foreach ($file in $allSourceFiles) {
    if ($file.FullName.StartsWith("$projectDir\")) {
        $relPath = $file.FullName.Replace("$projectDir\", "").Replace("\", "\")
    } else {
        $relPath = $file.FullName.Replace("$oFRoot\", "..\..\..\").Replace("\", "\")
    }

    if ($addedFiles.ContainsKey($relPath)) { continue }
    $addedFiles[$relPath] = $true

    if ($file.Extension -match "\.(h|hpp)$") {
        $item = $vcxproj.CreateElement("ClInclude", $ns)
        $item.SetAttribute("Include", $relPath)
        $includeGroup.AppendChild($item) | Out-Null
    } else {
        $item = $vcxproj.CreateElement("ClCompile", $ns)
        $item.SetAttribute("Include", $relPath)
        $compileGroup.AppendChild($item) | Out-Null
    }
}

# Find insertion point (before first Import or at end)
$firstImport = $vcxproj.Project.Import | Select-Object -First 1
if ($firstImport) {
    $vcxproj.Project.InsertBefore($compileGroup, $firstImport) | Out-Null
    $vcxproj.Project.InsertBefore($includeGroup, $firstImport) | Out-Null
} else {
    $vcxproj.Project.AppendChild($compileGroup) | Out-Null
    $vcxproj.Project.AppendChild($includeGroup) | Out-Null
}

# Add addon include directories to AdditionalIncludeDirectories
if ($addonIncludeDirs.Count -gt 0) {
    $xpath = "//msbuild:ClCompile/msbuild:AdditionalIncludeDirectories"
    $nsmgr = New-Object System.Xml.XmlNamespaceManager($vcxproj.NameTable)
    $nsmgr.AddNamespace("msbuild", $ns)
    
    $includeNodes = $vcxproj.SelectNodes($xpath, $nsmgr)
    foreach ($node in $includeNodes) {
        $currentValue = $node.InnerText
        $addonDirs = $addonIncludeDirs -join ";"
        $node.InnerText = "$currentValue;$addonDirs"
    }
}

# Add ProjectReferences for openframeworksLib and addons
$projRefGroup = $vcxproj.CreateElement("ItemGroup", $ns)

# openframeworksLib reference
$ofLibRef = $vcxproj.CreateElement("ProjectReference", $ns)
$ofLibRef.SetAttribute("Include", "`$(OF_ROOT)\libs\openFrameworksCompiled\project\vs\openframeworksLib.vcxproj")
$ofLibProj = $vcxproj.CreateElement("Project", $ns)
$ofLibProj.InnerText = "{5837595d-aca9-485c-8e76-729040ce4b0b}"
$ofLibRef.AppendChild($ofLibProj) | Out-Null
$projRefGroup.AppendChild($ofLibRef) | Out-Null

# Addon project references
foreach ($ref in $addonProjectRefs) {
    $addonRef = $vcxproj.CreateElement("ProjectReference", $ns)
    $addonRef.SetAttribute("Include", $ref.Path)
    $addonProj = $vcxproj.CreateElement("Project", $ns)
    $addonProj.InnerText = $ref.Guid
    $addonRef.AppendChild($addonProj) | Out-Null
    $projRefGroup.AppendChild($addonRef) | Out-Null
}

if ($firstImport) {
    $vcxproj.Project.InsertBefore($projRefGroup, $firstImport) | Out-Null
} else {
    $vcxproj.Project.AppendChild($projRefGroup) | Out-Null
}

# Save vcxproj
$vcxproj.Save($vcxprojPath)
Write-Host "   ✓ Saved $projectName.vcxproj" -ForegroundColor Green

# ============================================================================
# 7. Generate filters file
# ============================================================================
Write-Host "📝 Generating $projectName.vcxproj.filters..." -ForegroundColor Cyan

function Get-FilterPath {
    param($path)
    $parts = $path -split '[\\/]'
    if ($parts.Length -gt 1) {
        return ($parts[0..($parts.Length - 2)] -join '\')
    }
    return ""
}

[xml]$filters = $vcxproj.Clone()
$filters.LoadXml("<?xml version=`"1.0`" encoding=`"utf-8`"?><Project ToolsVersion=`"4.0`" xmlns=`"http://schemas.microsoft.com/developer/msbuild/2003`"></Project>")

$filterItemGroup = $filters.CreateElement("ItemGroup", $ns)
$filterDefGroup = $filters.CreateElement("ItemGroup", $ns)
$filterMap = @{}

foreach ($file in $allSourceFiles) {
    if ($file.FullName.StartsWith("$projectDir\")) {
        $relPath = $file.FullName.Replace("$projectDir\", "").Replace("\", "\")
    } else {
        $relPath = $file.FullName.Replace("$oFRoot\", "..\..\..\").Replace("\", "\")
    }

    if ($addedFiles.ContainsKey($relPath)) {
        $filterPath = Get-FilterPath $relPath
        $itemType = if ($file.Extension -match "\.(h|hpp)$") { "ClInclude" } else { "ClCompile" }
        
        $item = $filters.CreateElement($itemType, $ns)
        $item.SetAttribute("Include", $relPath)
        
        if ($filterPath) {
            $filterEl = $filters.CreateElement("Filter", $ns)
            $filterEl.InnerText = $filterPath
            $item.AppendChild($filterEl) | Out-Null
            $filterMap[$filterPath] = $true
        }
        
        $filterItemGroup.AppendChild($item) | Out-Null
    }
}

foreach ($filterPath in $filterMap.Keys) {
    $filter = $filters.CreateElement("Filter", $ns)
    $filter.SetAttribute("Include", $filterPath)
    $uuid = $filters.CreateElement("UniqueIdentifier", $ns)
    $uuid.InnerText = "{$([guid]::NewGuid().ToString())}"
    $filter.AppendChild($uuid) | Out-Null
    $filterDefGroup.AppendChild($filter) | Out-Null
}

$filters.Project.AppendChild($filterItemGroup) | Out-Null
$filters.Project.AppendChild($filterDefGroup) | Out-Null

$filters.Save($filtersPath)
Write-Host "   ✓ Saved $projectName.vcxproj.filters" -ForegroundColor Green

# ============================================================================
# 8. Generate solution file
# ============================================================================
Write-Host "📝 Generating $projectName.sln..." -ForegroundColor Cyan

$slnContent = Get-Content $slnTemplate -Raw
$slnContent = $slnContent -replace "emptyExample", $projectName

# Add addon projects to solution
if ($addonProjectRefs.Count -gt 0) {
    $projectSection = ""
    foreach ($ref in $addonProjectRefs) {
        $projName = [System.IO.Path]::GetFileNameWithoutExtension($ref.Path)
        $projectSection += "Project(`"{8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942}`") = `"$projName`", `"$($ref.Path)`", `"$($ref.Guid)`"`r`nEndProject`r`n"
    }
    
    # Insert after openframeworksLib project
    $slnContent = $slnContent -replace "(openframeworksLib.*?EndProject)", "`$1`r`n$projectSection"
    
    # Add build configurations
    $configSection = ""
    foreach ($ref in $addonProjectRefs) {
        $guid = $ref.Guid
        $configSection += "`t`t$guid.Debug|x64.ActiveCfg = Debug|x64`r`n"
        $configSection += "`t`t$guid.Debug|x64.Build.0 = Debug|x64`r`n"
        $configSection += "`t`t$guid.Release|x64.ActiveCfg = Release|x64`r`n"
        $configSection += "`t`t$guid.Release|x64.Build.0 = Release|x64`r`n"
    }
    
    $slnContent = $slnContent -replace "(GlobalSection\(SolutionProperties\))", "$configSection`t`$1"
}

Set-Content -Path $slnPath -Value $slnContent -Encoding UTF8
Write-Host "   ✓ Saved $projectName.sln" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ✅ Project update complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Summary:" -ForegroundColor Cyan
Write-Host "  - Project: $projectName" -ForegroundColor White
Write-Host "  - Source files: $($allSourceFiles.Count)" -ForegroundColor White
Write-Host "  - Addons: $($addons.Count)" -ForegroundColor White
Write-Host "  - Addon projects: $($addonProjectRefs.Count)" -ForegroundColor White
Write-Host ""
