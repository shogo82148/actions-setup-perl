# bundle OpenSSL for better reproducibility.

$RUNNER_TEMP = $env:RUNNER_TEMP
if ($null -eq $RUNNER_TEMP) {
    $RUNNER_TEMP = Join-Path $ROOT "working"
}
$RUNNER_TOOL_CACHE = $env:RUNNER_TOOL_CACHE
if ($null -eq $RUNNER_TOOL_CACHE) {
    $RUNNER_TOOL_CACHE = Join-Path $RUNNER_TEMP "dist"
}
$PERL_DIR = $env:PERL_VERSION
if ($null -eq $env:PERL_MULTI_THREAD) {
    $PERL_DIR = "$PERL_DIR-thr"
}
$PREFIX = Join-Path $RUNNER_TOOL_CACHE "perl" $PERL_DIR "x64"


# NASM is required by OpenSSL
Write-Host "::group::Set up NASM"
choco install nasm
Set-Item -Path "env:PATH" "C:\Program Files\NASM;$env:PATH"
Write-Host "::endgroup::"

# pre-installed SSL/TLS library on Windows is not development build.
# we need developement to compile XS modules.
Write-Host "::group::fetch OpenSSL source"
Set-Location "$RUNNER_TEMP"
Write-Host "Downloading zip archive..."
Invoke-WebRequest "https://github.com/openssl/openssl/archive/OpenSSL_$OPENSSL_VERSION.zip" -OutFile "openssl.zip"
Write-Host "Unzipping..."
Expand-Archive -Path "openssl.zip" -DestinationPath .
Remove-Item -Path "openssl.zip"
Write-Host "::endgroup::"

Write-Host "::group::build OpenSSL"
Set-Location "$RUNNER_TEMP"
Set-Location "openssl-OpenSSL_$OPENSSL_VERSION"
C:\strawberry\perl\bin\perl.exe Configure --prefix="$PREFIX" mingw64
make -j2
make install_sw install_ssldirs
Set-Location "$RUNNER_TEMP"
Remove-Item -Path "openssl-OpenSSL_$OPENSSL_VERSION" -Recurse -Force

# remove debug information
Get-ChildItem "$PREFIX" -Include *.pdb -Recurse | Remove-Item

Write-Host "::endgroup::"

# configure for building Net::SSLeay
Write-Output OPENSSL_PREFIX=$PREFIX | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
Write-Output (Join-Path $PREFIX "bin") | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
