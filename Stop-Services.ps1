<#
.SYNOPSIS
    LocalServicesOnDocker のコンテナ群を停止する（Start-Services.ps1 down のショートカット）。

.DESCRIPTION
    Stop-Services.bat の PowerShell 版。内部で同フォルダの Start-Services.ps1 を
    down アクションで呼び出し、コンテナを停止する。
    $PSScriptRoot を基準にするため、どのフォルダから実行しても動作する。

.PARAMETER NoPause
    完了時のキー入力待ち（pause 相当）を行わない。Start-Services.ps1 に転送される。

.EXAMPLE
    .\Stop-Services.ps1
    コンテナを停止する。
#>
[CmdletBinding()]
param(
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

# -NoPause はそのまま Start-Services.ps1 へ転送する。
$forward = @{}
if ($NoPause) { $forward['NoPause'] = $true }

& "$PSScriptRoot\Start-Services.ps1" down @forward
