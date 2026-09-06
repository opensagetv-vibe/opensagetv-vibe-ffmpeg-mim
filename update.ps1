[CmdletBinding()] param()
$ErrorActionPreference='Stop'; $root=Split-Path -Parent $MyInvocation.MyCommand.Path
$buildEnv=if($env:OPENSAGETV_VIBE_BUILD_ENV_ROOT){$env:OPENSAGETV_VIBE_BUILD_ENV_ROOT}else{Join-Path (Split-Path -Parent $root) 'opensagetv-vibe-build-env'}
function Convert-ToWslPath([string]$Path){$full=[IO.Path]::GetFullPath($Path);if($full -notmatch '^([A-Za-z]):\\(.*)$'){throw "Cannot convert path to WSL form: $full"};'/mnt/'+$Matches[1].ToLowerInvariant()+'/'+$Matches[2].Replace('\','/')}
if(-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)){throw 'WSL is required on Windows.'}
$linuxRoot=Convert-ToWslPath $root; $linuxBuildEnv=Convert-ToWslPath $buildEnv
& wsl.exe env "OPENSAGETV_VIBE_BUILD_ENV_ROOT=$linuxBuildEnv" bash "$linuxRoot/update.sh"; exit $LASTEXITCODE
