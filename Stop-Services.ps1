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

.PARAMETER Help
    使い方（指定できるサービス名の一覧）を表示して終了する。
    引数なしは「全サービスを停止」なので、ヘルプは help / -Help で明示的に要求する。

.PARAMETER NoPause
    完了時のキー入力待ち（pause 相当）を行わない。Start-Services.ps1 に転送される。

.EXAMPLE
    .\Stop-Services.ps1
    全コンテナを停止する。

.EXAMPLE
    .\Stop-Services.ps1 mysql redis
    mysql と redis だけを停止する。

.EXAMPLE
    .\Stop-Services.ps1 help
    使い方と指定できるサービス名の一覧を表示する（-Help でも同じ）。
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Service,

    [switch]$Help,

    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

# ヘルプ表示に使う共通部品（Write-Line / Wait-ForKey / Show-ServiceList /
# Test-HelpRequested）を読み込む。停止処理そのものは Start-Services.ps1 へ委譲する。
$commonPath = Join-Path $PSScriptRoot 'Services.Common.ps1'
if (-not (Test-Path -LiteralPath $commonPath)) {
    throw "共通部品が見つかりません: $commonPath"
}
. $commonPath

# --- ヘルプ（引数なしは全サービス停止なので、help / -Help で明示的に要求する）----
if ($Help -or (Test-HelpRequested -Names $Service)) {
    Write-Line ""
    Write-Line "使い方: .\Stop-Services.ps1 [<サービス名> ...] [-NoPause]" -Color Cyan
    Write-Line ""
    Write-Line "  Start-Services.ps1 down のショートカットです。"
    Write-Line "  サービス名を省略すると全サービスを停止します。"
    Write-Line ""
    Show-ServiceList -AllNote '上記すべて（省略時と同じ）'
    Write-Line ""
    Write-Line "オプション:" -Color Cyan
    Write-Line "  -NoPause    終了時のキー入力待ちを行わない。"
    Write-Line "  -Help       この使い方を表示する（help でも可）。"
    Write-Line ""
    Write-Line "例:" -Color Cyan
    Write-Line "  .\Stop-Services.ps1"
    Write-Line "  .\Stop-Services.ps1 mysql redis"
    Write-Line ""
    Write-Line "詳細は Get-Help .\Stop-Services.ps1 -Full で参照できます。" -Color DarkGray
    Wait-ForKey
    exit 0
}

# サービス名と -NoPause はそのまま Start-Services.ps1 へ転送する。
# サービス名の妥当性検査も Start-Services.ps1 側に任せる。
$forward = @{}
if ($Service) { $forward['Service'] = $Service }
if ($NoPause) { $forward['NoPause'] = $true }

& "$PSScriptRoot\Start-Services.ps1" down @forward

# 不明なサービス名などで Start-Services.ps1 が exit 1 しても、呼び出し元の
# 終了コードは 0 のままになるため、明示的に引き継ぐ。
exit $LASTEXITCODE
