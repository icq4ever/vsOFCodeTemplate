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

if ($OldName -eq $NewName) {
    Write-Host "✅ Project name already matches folder name. No update needed."
    exit 0
}

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
