# guessing current folder name
$NewName = Split-Path -Leaf (Get-Location)

# guessing vcxproj filename 
$OldProj = Get-ChildItem -Filter *.vcxproj | Select-Object -First 1
if (-not $OldProj) {
    Write-Host "❌ .vcxproj file does not exist." -ForegroundColor Red
    exit 1
}
$OldName = [System.IO.Path]::GetFileNameWithoutExtension($OldProj.Name)

if ($OldName -eq $NewName) {
    Write-Host "✅ already proper project name. no need to change."
    exit 0
}

Write-Host "🔁 rename project name : '$OldName' → '$NewName'"

$Extensions = @(".vcxproj", ".vcxproj.filters", ".vcxproj.user")

# rename project files
foreach ($Ext in $Extensions) {
    $OldFile = ".\$OldName$Ext"
    $NewFile = ".\$NewName$Ext"
    if (Test-Path $OldFile) {
        Rename-Item $OldFile $NewFile -Force
        Write-Host "✔️ rename file name : $OldFile → $NewFile"
    }
}

# internal replace
foreach ($Ext in $Extensions) {
    $Target = ".\$NewName$Ext"
    if (Test-Path $Target) {
        (Get-Content $Target) -replace $OldName, $NewName | Set-Content $Target
        Write-Host "📝 replace internal successfully : $Target"
    }
}
