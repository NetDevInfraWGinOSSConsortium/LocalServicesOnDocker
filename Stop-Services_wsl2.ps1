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

.EXAMPLE
    .\Stop-Services_wsl2.ps1
    全コンテナを停止し、キープアライブも解除する。

.EXAMPLE
    .\Stop-Services_wsl2.ps1 mysql redis
    mysql と redis だけを停止する（キープアライブは維持）。

.EXAMPLE
    .\Stop-Services_wsl2.ps1 -Distro Ubuntu-22.04
    指定ディストリビューション上のコンテナを停止する。
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Service,

    [string]$Distro
)

$ErrorActionPreference = 'Stop'

# down 以外の引数（サービス名・-Distro 等）はそのまま Start-Services_wsl2.ps1 へ転送する。
# サービス名の妥当性検査・ヘルプ表示も Start-Services_wsl2.ps1 側に任せる。
$forward = @{}
if ($Service) { $forward['Service'] = $Service }
if ($PSBoundParameters.ContainsKey('Distro')) { $forward['Distro'] = $Distro }

& "$PSScriptRoot\Start-Services_wsl2.ps1" down @forward

# 不明なサービス名などで Start-Services_wsl2.ps1 が exit 1 しても、呼び出し元の
# 終了コードは 0 のままになるため、明示的に引き継ぐ。
exit $LASTEXITCODE
