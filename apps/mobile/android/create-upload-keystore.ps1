# Run from project root to create your Play Store upload keystore.
# You will be prompted for passwords — save them securely; you need them for every update.

$keytool = Get-Command keytool -ErrorAction SilentlyContinue
if (-not $keytool) {
  Write-Error "keytool not found. Install a JDK or Android Studio."
  exit 1
}

$keystore = Join-Path $PSScriptRoot "clivora-upload-keystore.jks"
$keyProps = Join-Path $PSScriptRoot "key.properties"

if (Test-Path $keystore) {
  Write-Host "Keystore already exists: $keystore"
  exit 0
}

Write-Host "Creating upload keystore at $keystore"
Write-Host "Use the same password for both store and key when prompted."

keytool -genkey -v `
  -keystore $keystore `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias clivora `
  -dname "CN=CLIVORA, OU=Engineering, O=CLIVORA, L=Karachi, ST=Sindh, C=PK"

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Enter the store password you just used:"
$storePass = Read-Host -AsSecureString
$storePlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePass))

@"
storePassword=$storePlain
keyPassword=$storePlain
keyAlias=clivora
storeFile=../clivora-upload-keystore.jks
"@ | Set-Content -Path $keyProps -Encoding UTF8

Write-Host "Created $keyProps"
Write-Host "Rebuild with: flutter build appbundle --release"
