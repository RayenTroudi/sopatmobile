# Builds the Android release APK and uploads it to Firebase App Distribution.
#
# Usage:
#   .\scripts\distribute.ps1 -Testers "someone@example.com,other@example.com"
#   .\scripts\distribute.ps1 -Groups "qa-team"
#   .\scripts\distribute.ps1 -Notes "Fixed OCR crash on Android 14"

param(
    [string]$Testers = "",
    [string]$Groups = "",
    [string]$Notes = "Automated build from local distribute script."
)

$AppId = "1:1056701373497:android:38c81331a8d12f75a741e8"

Write-Host "Building release APK..."
flutter build apk --release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$ApkPath = "build\app\outputs\flutter-apk\app-release.apk"

$distArgs = @(
    "-y", "firebase-tools@latest",
    "appdistribution:distribute", $ApkPath,
    "--app", $AppId,
    "--release-notes", $Notes
)

if ($Testers -ne "") { $distArgs += @("--testers", $Testers) }
if ($Groups -ne "")  { $distArgs += @("--groups", $Groups) }

Write-Host "Uploading to Firebase App Distribution..."
npx @distArgs
