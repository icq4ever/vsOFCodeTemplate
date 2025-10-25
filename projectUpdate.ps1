$ErrorActionPreference = "Stop"

# Get current folder and intended project name
$NewName = Split-Path -Leaf (Get-Location)

# Detect current .vcxproj
$OldProj = Get-ChildItem -Filter *.vcxproj | Select-Object -First 1
if (-not $OldProj) {
    Write-Host "❌ .vcxproj file does not exist." -ForegroundColor Red
    exit 1
}
$OldName = [System.IO.Path]::GetFileNameWithoutExtension($OldProj.Name)

if ($OldName -ne $NewName) {

Write-Host "🔁 Renaming project: '$OldName' → '$NewName'"

# File extensions to rename and patch
$Extensions = @(".vcxproj", ".vcxproj.filters", ".vcxproj.user")

# Rename files
foreach ($Ext in $Extensions) {
    $OldFile = ".\$OldName$Ext"
    $NewFile = ".\$NewName$Ext"
    if (Test-Path $OldFile) {
        Rename-Item $OldFile $NewFile -Force
        Write-Host "✔️ Renamed: $OldFile → $NewFile"
    }
}

# Update internal contents
foreach ($Ext in $Extensions) {
    $Target = ".\$NewName$Ext"
    if (Test-Path $Target) {
        (Get-Content $Target) -replace $OldName, $NewName | Set-Content $Target
        Write-Host "📝 Updated references inside: $Target"
    }
}

# Rename and update solution file
$OldSln = ".\$OldName.sln"
$NewSln = ".\$NewName.sln"
if (Test-Path $OldSln) {
    Rename-Item $OldSln $NewSln -Force
    Write-Host "✔️ Renamed: $OldSln → $NewSln"

    # Update references inside .sln
    (Get-Content $NewSln) -replace $OldName, $NewName | Set-Content $NewSln
    Write-Host "📝 Updated references inside: $NewSln"
} else {
    # Create new .sln file if it doesn't exist
    $vcxprojGuid = "{7FD42DF7-442E-479A-BA76-D0022F99702A}"

    # Try to extract GUID from existing vcxproj
    $vcxprojContent = Get-Content ".\$NewName.vcxproj" -Raw
    if ($vcxprojContent -match '<ProjectGuid>\{([^}]+)\}</ProjectGuid>') {
        $vcxprojGuid = "{$($matches[1])}"
    }

    $slnContent = @"

Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
VisualStudioVersion = 17.0.31903.59
MinimumVisualStudioVersion = 10.0.40219.1
Project("{8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942}") = "$NewName", "$NewName.vcxproj", "$vcxprojGuid"
EndProject
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
		Debug|x64 = Debug|x64
		Release|x64 = Release|x64
	EndGlobalSection
	GlobalSection(ProjectConfigurationPlatforms) = postSolution
		$vcxprojGuid.Debug|x64.ActiveCfg = Debug|x64
		$vcxprojGuid.Debug|x64.Build.0 = Debug|x64
		$vcxprojGuid.Release|x64.ActiveCfg = Release|x64
		$vcxprojGuid.Release|x64.Build.0 = Release|x64
	EndGlobalSection
	GlobalSection(SolutionProperties) = preSolution
		HideSolutionNode = FALSE
	EndGlobalSection
	GlobalSection(ExtensibilityGlobals) = postSolution
		SolutionGuid = {A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
	EndGlobalSection
EndGlobal
"@

    Set-Content $NewSln $slnContent
    Write-Host "✅ Created new solution file: $NewSln"
}

Write-Host ""
Write-Host "✅ Project rename complete."
Write-Host "   Old name: $OldName"
Write-Host "   New name: $NewName"
Write-Host ""
}

# ============================================================================
# Auto-update vcxproj with source files from src/ folder
# ============================================================================

Write-Host "🔍 Scanning src/ folder for source files..."

$vcxprojPath = ".\$NewName.vcxproj"
if (-not (Test-Path $vcxprojPath)) {
    Write-Host "⚠️  vcxproj file not found. Skipping auto-update."
    exit 0
}

# Scan for .cpp and .h files in src/ folder (recursively)
$cppFiles = Get-ChildItem -Path "src" -Filter "*.cpp" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Replace((Get-Location).Path + "\", "").Replace("\", "/") }
$hFiles = Get-ChildItem -Path "src" -Filter "*.h" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Replace((Get-Location).Path + "\", "").Replace("\", "/") }

if ($cppFiles.Count -eq 0 -and $hFiles.Count -eq 0) {
    Write-Host "⚠️  No source files found in src/ folder."
    exit 0
}

# Load vcxproj as XML
[xml]$vcxproj = Get-Content $vcxprojPath

# Find or create ItemGroup for ClCompile
$compileGroup = $vcxproj.Project.ItemGroup | Where-Object { $_.ClCompile -ne $null } | Select-Object -First 1
if (-not $compileGroup) {
    $compileGroup = $vcxproj.CreateElement("ItemGroup", $vcxproj.Project.NamespaceURI)
    $vcxproj.Project.AppendChild($compileGroup) | Out-Null
}

# Find or create ItemGroup for ClInclude
$includeGroup = $vcxproj.Project.ItemGroup | Where-Object { $_.ClInclude -ne $null } | Select-Object -First 1
if (-not $includeGroup) {
    $includeGroup = $vcxproj.CreateElement("ItemGroup", $vcxproj.Project.NamespaceURI)
    $vcxproj.Project.AppendChild($includeGroup) | Out-Null
}

# Get existing files in vcxproj (from ALL ItemGroups)
$allItemGroups = $vcxproj.Project.ItemGroup
$existingCppFiles = @($allItemGroups | ForEach-Object { $_.ClCompile } | ForEach-Object { $_.Include })
$existingHFiles = @($allItemGroups | ForEach-Object { $_.ClInclude } | ForEach-Object { $_.Include })

# Add new .cpp files
$addedCpp = 0
foreach ($file in $cppFiles) {
    if ($existingCppFiles -notcontains $file) {
        $newNode = $vcxproj.CreateElement("ClCompile", $vcxproj.Project.NamespaceURI)
        $newNode.SetAttribute("Include", $file)
        $compileGroup.AppendChild($newNode) | Out-Null
        Write-Host "  ✔️ Added: $file"
        $addedCpp++
    }
}

# Add new .h files
$addedH = 0
foreach ($file in $hFiles) {
    if ($existingHFiles -notcontains $file) {
        $newNode = $vcxproj.CreateElement("ClInclude", $vcxproj.Project.NamespaceURI)
        $newNode.SetAttribute("Include", $file)
        $includeGroup.AppendChild($newNode) | Out-Null
        Write-Host "  ✔️ Added: $file"
        $addedH++
    }
}

# Save if changes were made
if ($addedCpp -gt 0 -or $addedH -gt 0) {
    $vcxproj.Save($vcxprojPath)
    Write-Host ""
    Write-Host "✅ vcxproj updated: $addedCpp .cpp files, $addedH .h files added."
} else {
    Write-Host "✅ All source files already in vcxproj. No changes needed."
}
