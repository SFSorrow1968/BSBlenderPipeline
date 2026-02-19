param(
    [string]$Owner = "SFSorrow1968",
    [string]$RepoName = "BSBlenderPipeline",
    [switch]$Private
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $repoRoot

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) is required for remote setup."
}

if (-not (Test-Path ".git")) {
    git init | Out-Host
}

$remoteUrl = $null
try {
    $remoteUrl = (git remote get-url origin 2>$null)
}
catch {
    $remoteUrl = $null
}

if ($remoteUrl) {
    Write-Host "Origin already configured: $remoteUrl"
    exit 0
}

$fullRepo = "$Owner/$RepoName"
$sshUrl = "git@github.com:$fullRepo.git"

$repoExists = $false
cmd /c "gh repo view $fullRepo --json name,url >nul 2>nul"
if ($LASTEXITCODE -eq 0) {
    $repoExists = $true
}

if ($repoExists) {
    git remote add origin $sshUrl
    Write-Host "Attached existing remote: $sshUrl"
}
else {
    $visibility = if ($Private) { "--private" } else { "--public" }
    gh repo create $fullRepo $visibility --source . --remote origin --description "Blade and Sorcery Blender + Unity death animation pipeline" | Out-Host
    Write-Host "Created and attached remote: $sshUrl"
}

$branch = (git branch --show-current)
if (-not $branch) {
    git checkout -b main | Out-Host
    $branch = "main"
}

git push -u origin $branch | Out-Host
Write-Host "Remote configuration complete."
