<#
.SYNOPSIS
    LocalServicesOnDocker のコンテナ群を停止する（Start-Services.ps1 down のショートカット）。

.DESCRIPTION
    Stop-Services.bat の PowerShell 版。内部で同フォルダの Start-Services.ps1 を
    down アクションで呼び出し、コンテナを停止する。
    $PSScriptRoot を基準にするため、どのフォルダから実行しても動作する。

.PARAMETER Service
    停止するサービス名。スペース区切りで複数指定でき、大文字小文字は区別しない。
    all を指定すると全サービス。省略した場合は全サービスを停止する（従来どおりの動作）。
    指定できるサービス名は Start-Services.ps1 と共通（redis / mongo / mysql /
    postgres / sqlserver / oracle）。

.PARAMETER NoPause
    完了時のキー入力待ち（pause 相当）を行わない。Start-Services.ps1 に転送される。

.EXAMPLE
    .\Stop-Services.ps1
    全コンテナを停止する。

.EXAMPLE
    .\Stop-Services.ps1 mysql redis
    mysql と redis だけを停止する。
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Service,

    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

# サービス名と -NoPause はそのまま Start-Services.ps1 へ転送する。
# サービス名の妥当性検査・ヘルプ表示も Start-Services.ps1 側に任せる。
$forward = @{}
if ($Service) { $forward['Service'] = $Service }
if ($NoPause) { $forward['NoPause'] = $true }

& "$PSScriptRoot\Start-Services.ps1" down @forward

# 不明なサービス名などで Start-Services.ps1 が exit 1 しても、呼び出し元の
# 終了コードは 0 のままになるため、明示的に引き継ぐ。
exit $LASTEXITCODE
