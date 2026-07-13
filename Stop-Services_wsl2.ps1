<#
.SYNOPSIS
    LocalServicesOnDocker のコンテナ群を停止する（Start-Services.ps1 down のショートカット）。

.DESCRIPTION
    Stop-Services.bat の PowerShell 版。内部で同フォルダの Start-Services.ps1 を
    down アクションで呼び出し、コンテナ停止とキープアライブ解除を行う。
    $PSScriptRoot を基準にするため、どのフォルダから実行しても動作する。

.PARAMETER Distro
    使用する WSL ディストリビューション名。Start-Services.ps1 にそのまま渡される。

.EXAMPLE
    .\Stop-Services.ps1
    コンテナを停止する。

.EXAMPLE
    .\Stop-Services.ps1 -Distro Ubuntu-22.04
    指定ディストリビューション上のコンテナを停止する。
#>
[CmdletBinding()]
param(
    [string]$Distro
)

$ErrorActionPreference = 'Stop'

# down 以外の引数（-Distro 等）はそのまま Start-Services.ps1 へ転送する。
$forward = @{}
if ($PSBoundParameters.ContainsKey('Distro')) { $forward['Distro'] = $Distro }

& "$PSScriptRoot\Start-Services_wsl2.ps1" down @forward
