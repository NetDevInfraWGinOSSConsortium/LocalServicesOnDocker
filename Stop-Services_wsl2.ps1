<#
.SYNOPSIS
    LocalServicesOnDocker のコンテナ群を停止する（Start-Services.ps1 down のショートカット）。

.DESCRIPTION
    Stop-Services.bat の PowerShell 版。内部で同フォルダの Start-Services.ps1 を
    down アクションで呼び出し、コンテナ停止とキープアライブ解除を行う。
    $PSScriptRoot を基準にするため、どのフォルダから実行しても動作する。

.PARAMETER Service
    停止するサービス名。スペース区切りで複数指定でき、大文字小文字は区別しない。
    all を指定すると全サービス。省略した場合は全サービスを停止する（従来どおりの動作）。
    サービスを指定した場合は、残るコンテナのためキープアライブを解除しない。

.PARAMETER Distro
    使用する WSL ディストリビューション名。Start-Services.ps1 にそのまま渡される。

.PARAMETER Help
    使い方（指定できるサービス名の一覧）を表示して終了する。
    引数なしは「全サービスを停止」なので、ヘルプは help / -Help で明示的に要求する。

.PARAMETER NoPause
    完了時のキー入力待ち（pause 相当）を行わない。Start-Services_wsl2.ps1 に転送される。

.EXAMPLE
    .\Stop-Services_wsl2.ps1
    全コンテナを停止し、キープアライブも解除する。

.EXAMPLE
    .\Stop-Services_wsl2.ps1 mysql redis
    mysql と redis だけを停止する（キープアライブは維持）。

.EXAMPLE
    .\Stop-Services_wsl2.ps1 -Distro Ubuntu-22.04
    指定ディストリビューション上のコンテナを停止する。

.EXAMPLE
    .\Stop-Services_wsl2.ps1 help
    使い方と指定できるサービス名の一覧を表示する（-Help でも同じ）。
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Service,

    [string]$Distro,

    [switch]$Help,

    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'

# ヘルプ表示に使う共通部品（Write-Line / Wait-ForKey / Show-ServiceList /
# Test-HelpRequested）を読み込む。停止処理そのものは Start-Services_wsl2.ps1 へ委譲する。
$commonPath = Join-Path $PSScriptRoot 'Services.Common.ps1'
if (-not (Test-Path -LiteralPath $commonPath)) {
    throw "共通部品が見つかりません: $commonPath"
}
. $commonPath

# --- ヘルプ（引数なしは全サービス停止なので、help / -Help で明示的に要求する）----
if ($Help -or (Test-HelpRequested -Names $Service)) {
    Write-Line ""
    Write-Line "使い方: .\Stop-Services_wsl2.ps1 [<サービス名> ...] [-Distro <名前>] [-NoPause]" -Color Cyan
    Write-Line ""
    Write-Line "  Start-Services_wsl2.ps1 down のショートカットです。"
    Write-Line "  サービス名を省略すると全サービスを停止し、キープアライブも解除します。"
    Write-Line "  サービス名を指定した場合は、残るコンテナのためキープアライブを維持します。"
    Write-Line ""
    Show-ServiceList -AllNote '上記すべて（省略時と同じ）'
    Write-Line ""
    Write-Line "オプション:" -Color Cyan
    Write-Line "  -Distro     使用する WSL ディストリビューション名（省略時は既定）。"
    Write-Line "  -NoPause    終了時のキー入力待ちを行わない。"
    Write-Line "  -Help       この使い方を表示する（help でも可）。"
    Write-Line ""
    Write-Line "例:" -Color Cyan
    Write-Line "  .\Stop-Services_wsl2.ps1"
    Write-Line "  .\Stop-Services_wsl2.ps1 mysql redis"
    Write-Line "  .\Stop-Services_wsl2.ps1 -Distro Ubuntu-22.04"
    Write-Line ""
    Write-Line "詳細は Get-Help .\Stop-Services_wsl2.ps1 -Full で参照できます。" -Color DarkGray
    Wait-ForKey
    exit 0
}

# down 以外の引数（サービス名・-Distro 等）はそのまま Start-Services_wsl2.ps1 へ転送する。
# サービス名の妥当性検査も Start-Services_wsl2.ps1 側に任せる。
$forward = @{}
if ($Service) { $forward['Service'] = $Service }
if ($PSBoundParameters.ContainsKey('Distro')) { $forward['Distro'] = $Distro }
if ($NoPause) { $forward['NoPause'] = $true }

& "$PSScriptRoot\Start-Services_wsl2.ps1" down @forward

# 不明なサービス名などで Start-Services_wsl2.ps1 が exit 1 しても、呼び出し元の
# 終了コードは 0 のままになるため、明示的に引き継ぐ。
exit $LASTEXITCODE
