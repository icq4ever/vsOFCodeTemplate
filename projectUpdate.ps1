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

# Delete old solution file if exists (VS will recreate it)
$OldSln = ".\$OldName.sln"
if (Test-Path $OldSln) {
    Remove-Item $OldSln -Force
    Write-Host "🗑️ Deleted old solution file: $OldSln"
}

Write-Host "✅ Project rename complete."
