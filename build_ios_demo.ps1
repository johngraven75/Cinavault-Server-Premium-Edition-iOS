$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$desktopCandidates = @(
    (Join-Path $env:USERPROFILE "OneDrive\Documents\Desktop\John"),
    (Join-Path $env:USERPROFILE "OneDrive\Documents\Desktop"),
    ([Environment]::GetFolderPath("Desktop"))
)

$desktopRoot = $null
foreach ($candidate in $desktopCandidates) {
    if (-not $candidate) { continue }
    try {
        New-Item -ItemType Directory -Force -Path $candidate | Out-Null
        $desktopRoot = $candidate
        break
    } catch {
        continue
    }
}

if (-not $desktopRoot) { throw "Unable to resolve a writable Desktop path." }

$desktopBuilds = Join-Path $desktopRoot "cinavault ios builds"
New-Item -ItemType Directory -Force -Path $desktopBuilds | Out-Null

function Get-NextBuildNumber {
    param([string]$Folder)
    $max = 0
    $regex = [regex]"Cinavault-iOS-Demo-v(\d+)\.zip$"
    if (Test-Path $Folder) {
        Get-ChildItem -Path $Folder -File -Filter "Cinavault-iOS-Demo-v*.zip" | ForEach-Object {
            $match = $regex.Match($_.Name)
            if ($match.Success) {
                $num = [int]$match.Groups[1].Value
                if ($num -gt $max) { $max = $num }
            }
        }
    }
    return ($max + 1)
}

$buildNumber = Get-NextBuildNumber -Folder $desktopBuilds
$zipName = "Cinavault-iOS-Demo-v$buildNumber.zip"
$noteName = "Cinavault-iOS-Demo-v$buildNumber-note.md"

$demoSource = Join-Path $projectRoot "ios\demo-pwa"
if (-not (Test-Path $demoSource)) { throw "Missing demo source folder: $demoSource" }

$tmpRoot = Join-Path $env:TEMP ("cinavault-ios-demo-v" + $buildNumber + "-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tmpRoot | Out-Null
$tmpPayload = Join-Path $tmpRoot "cinavault-ios-demo"
Copy-Item -Path $demoSource -Destination $tmpPayload -Recurse -Force

$desktopZip = Join-Path $desktopBuilds $zipName
Compress-Archive -Path "$tmpPayload\*" -DestinationPath $desktopZip -Force

$repoBuilds = Join-Path $projectRoot "ios\builds"
New-Item -ItemType Directory -Force -Path $repoBuilds | Out-Null
$repoZip = Join-Path $repoBuilds $zipName
Copy-Item -LiteralPath $desktopZip -Destination $repoZip -Force

$stamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$note = @(
    "# Cinavault iOS Demo v$buildNumber"
    ""
    "- Built: $stamp"
    "- Desktop Demo Package: $desktopZip"
    "- Repo Demo Package: $repoZip"
    "- Format: Installable iPhone PWA shell (Add to Home Screen)"
    ""
    "## Install Test (iPhone, current iOS)"
    "1. Host extracted files on HTTPS (GitHub Pages or any HTTPS host)."
    "2. Open the URL in Safari on iPhone."
    "3. Tap Share -> Add to Home Screen."
    ""
    "## Notes"
    "- Native App Store source scaffold is in ios/CinavaultServerPremiumEdition."
    "- Signed IPA generation requires macOS + Apple signing credentials."
) -join "`r`n"

$desktopNote = Join-Path $desktopBuilds $noteName
Set-Content -Path $desktopNote -Value $note -Encoding UTF8
$repoNote = Join-Path $repoBuilds $noteName
Set-Content -Path $repoNote -Value $note -Encoding UTF8

Remove-Item -LiteralPath $tmpRoot -Recurse -Force

Write-Host "iOS demo package complete."
Write-Host "Desktop package: $desktopZip"
Write-Host "Desktop note: $desktopNote"
Write-Host "Repo package: $repoZip"
Write-Host "Repo note: $repoNote"
