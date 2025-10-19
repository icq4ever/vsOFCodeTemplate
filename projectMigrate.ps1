$ErrorActionPreference = "Stop"

Write-Host "🔄 Project Migration Tool" -ForegroundColor Cyan
Write-Host "This will import template configuration files into your existing project"
Write-Host ""

# Get current project directory
$ProjectDir = Get-Location
$ProjectName = Split-Path -Leaf $ProjectDir

# Auto-detect template directory
$TemplateName = "vsOFCodeTemplate"
$TemplateDir = $null

# Try to find template in same category first
$CategoryDir = Split-Path -Parent $ProjectDir
$CandidatePath = Join-Path $CategoryDir $TemplateName
if (Test-Path $CandidatePath) {
    $TemplateDir = $CandidatePath
}

# Try to find in myApps category
if (-not $TemplateDir) {
    $AppsDir = Split-Path -Parent $CategoryDir
    $CandidatePath = Join-Path $AppsDir "myApps\$TemplateName"
    if (Test-Path $CandidatePath) {
        $TemplateDir = $CandidatePath
    }
}

# If still not found, ask user
if (-not $TemplateDir -or -not (Test-Path $TemplateDir)) {
    Write-Host "❌ Template directory not found automatically." -ForegroundColor Red
    $TemplateDir = Read-Host "Please specify the template directory path"
    if (-not (Test-Path $TemplateDir)) {
        Write-Host "❌ Directory does not exist: $TemplateDir" -ForegroundColor Red
        exit 1
    }
}

Write-Host "📂 Template found: $TemplateDir" -ForegroundColor Green
Write-Host "📂 Target project: $ProjectDir" -ForegroundColor Green
Write-Host ""

# Check if already in template directory
if ($ProjectDir.Path -eq (Resolve-Path $TemplateDir).Path) {
    Write-Host "❌ You are already in the template directory!" -ForegroundColor Red
    exit 1
}

# Warn about existing content
if (Test-Path ".git") {
    Write-Host "⚠️  Existing git repository detected. It will be preserved." -ForegroundColor Yellow
}

if (Test-Path "src") {
    Write-Host "✓ Existing src/ directory will be preserved." -ForegroundColor Green
}

if (Test-Path "addons.make") {
    Write-Host "✓ Existing addons.make will be preserved." -ForegroundColor Green
}

if ((Test-Path "README.md") -or (Test-Path "readme.md")) {
    Write-Host "✓ Existing README will be preserved." -ForegroundColor Green
}

Write-Host ""
$response = Read-Host "Continue with migration? [y/N]"
if ($response -notmatch "^[Yy]$") {
    Write-Host "❌ Migration cancelled." -ForegroundColor Red
    exit 0
}

Write-Host ""
Write-Host "🚀 Starting migration..." -ForegroundColor Cyan

# 1. Copy script files
Write-Host "📝 Copying update scripts..." -ForegroundColor Cyan
$scripts = @("addonUpdate.sh", "projectUpdate.sh", "addonUpdate.ps1", "projectUpdate.ps1")
foreach ($script in $scripts) {
    $sourcePath = Join-Path $TemplateDir $script
    if (Test-Path $sourcePath) {
        Copy-Item $sourcePath -Destination $ProjectDir -Force
        Write-Host "  ✓ $script" -ForegroundColor Green
    }
}

# 2. Copy Makefile and config.make if they don't exist
Write-Host "📝 Copying build files..." -ForegroundColor Cyan
if (-not (Test-Path "Makefile")) {
    $makefilePath = Join-Path $TemplateDir "Makefile"
    if (Test-Path $makefilePath) {
        Copy-Item $makefilePath -Destination $ProjectDir -Force
        Write-Host "  ✓ Makefile" -ForegroundColor Green
    }
} else {
    Write-Host "  ⊘ Makefile (already exists, skipped)" -ForegroundColor Gray
}

if (-not (Test-Path "config.make")) {
    $configMakePath = Join-Path $TemplateDir "config.make"
    if (Test-Path $configMakePath) {
        Copy-Item $configMakePath -Destination $ProjectDir -Force
        Write-Host "  ✓ config.make" -ForegroundColor Green
    }
}

# 3. Merge .gitignore
Write-Host "📝 Merging .gitignore..." -ForegroundColor Cyan
$templateGitignore = Join-Path $TemplateDir ".gitignore"
if (Test-Path $templateGitignore) {
    if (Test-Path ".gitignore") {
        # Backup existing
        Copy-Item ".gitignore" -Destination ".gitignore.backup" -Force
        Write-Host "  ⚠️  Backed up existing .gitignore to .gitignore.backup" -ForegroundColor Yellow

        # Merge (append template, remove duplicates)
        $existing = Get-Content ".gitignore"
        $template = Get-Content $templateGitignore
        $merged = $existing + $template | Select-Object -Unique
        $merged | Set-Content ".gitignore"
        Write-Host "  ✓ .gitignore (merged)" -ForegroundColor Green
    } else {
        Copy-Item $templateGitignore -Destination $ProjectDir -Force
        Write-Host "  ✓ .gitignore (new)" -ForegroundColor Green
    }
}

# 4. Copy .gitattributes
Write-Host "📝 Copying .gitattributes..." -ForegroundColor Cyan
$templateGitattributes = Join-Path $TemplateDir ".gitattributes"
if (Test-Path $templateGitattributes) {
    if (Test-Path ".gitattributes") {
        Copy-Item ".gitattributes" -Destination ".gitattributes.backup" -Force
        Write-Host "  ⚠️  Backed up existing .gitattributes" -ForegroundColor Yellow
    }
    Copy-Item $templateGitattributes -Destination $ProjectDir -Force
    Write-Host "  ✓ .gitattributes" -ForegroundColor Green
}

# 5. Merge .vscode directory
Write-Host "📝 Merging .vscode configuration..." -ForegroundColor Cyan
if (-not (Test-Path ".vscode")) {
    New-Item -ItemType Directory -Path ".vscode" | Out-Null
}

# Copy VSCode config files (tasks, launch, c_cpp_properties)
$vscodeFiles = @("tasks.json", "launch.json", "c_cpp_properties.json")
foreach ($file in $vscodeFiles) {
    $sourcePath = Join-Path $TemplateDir ".vscode\$file"
    if (Test-Path $sourcePath) {
        $destPath = ".vscode\$file"
        if (Test-Path $destPath) {
            Copy-Item $destPath -Destination ".vscode\$file.backup" -Force
            Write-Host "  ⚠️  Backed up existing $file" -ForegroundColor Yellow
        }
        Copy-Item $sourcePath -Destination $destPath -Force
        Write-Host "  ✓ $file" -ForegroundColor Green
    }
}

# Don't copy settings.json (user-specific) unless it doesn't exist
$settingsPath = Join-Path $TemplateDir ".vscode\settings.json"
if ((Test-Path $settingsPath) -and -not (Test-Path ".vscode\settings.json")) {
    Copy-Item $settingsPath -Destination ".vscode\settings.json" -Force
    Write-Host "  ✓ settings.json (new)" -ForegroundColor Green
}

# 6. Create addons.make if it doesn't exist
if (-not (Test-Path "addons.make")) {
    New-Item -ItemType File -Path "addons.make" -Force | Out-Null
    Write-Host "  ✓ Created empty addons.make" -ForegroundColor Green
}

# 7. Fix line endings for all scripts
Write-Host "🔧 Fixing line endings..." -ForegroundColor Cyan
$allScripts = @("addonUpdate.sh", "projectUpdate.sh", "projectMigrate.sh", "addonUpdate.ps1", "projectUpdate.ps1")
foreach ($script in $allScripts) {
    if (Test-Path $script) {
        $content = Get-Content $script -Raw
        $content = $content -replace "`r`n", "`n"
        [System.IO.File]::WriteAllText((Join-Path $ProjectDir $script), $content)
    }
}

Write-Host ""
Write-Host "✅ Migration complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Summary:" -ForegroundColor Cyan
Write-Host "  • Update scripts installed"
Write-Host "  • Build configuration copied"
Write-Host "  • .gitignore and .gitattributes updated"
Write-Host "  • .vscode/ configuration merged"
Write-Host "  • Your source code and addons.make preserved"
Write-Host ""
Write-Host "📝 Next steps:" -ForegroundColor Cyan
Write-Host "  1. Review .gitignore.backup if it exists"
Write-Host "  2. Review .vscode/*.backup files if they exist"
Write-Host "  3. Run .\projectUpdate.ps1 to update project files"
Write-Host "  4. Run .\addonUpdate.ps1 if you have addons in addons.make"
Write-Host ""
