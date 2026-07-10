<#
.SYNOPSIS
    LocalServicesOnDocker のコンテナ群を WSL2 上の Docker で起動・停止する。

.DESCRIPTION
    README.md の手順（common_link ネットワーク作成 → docker compose up -d / down）を
    Windows の PowerShell から WSL2 経由で実行する。
    Docker は WSL2 内にインストールされている前提。

.PARAMETER Action
    up    : common_link を（無ければ）作成し、docker compose up -d でコンテナを起動する（既定）。
    down  : docker compose down でコンテナを停止する。
    ps    : コンテナの稼働状況を表示する。
    logs  : コンテナのログを表示する（Ctrl+C で終了）。

.PARAMETER Distro
    使用する WSL ディストリビューション名。省略時は WSL の既定ディストリビューションを使用する。

.EXAMPLE
    .\Start-Services.ps1
    コンテナを起動する。

.EXAMPLE
    .\Start-Services.ps1 down
    コンテナを停止する。

.EXAMPLE
    .\Start-Services.ps1 up -Distro Ubuntu-22.04
    ディストリビューションを指定して起動する。
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('up', 'down', 'ps', 'logs')]
    [string]$Action = 'up',

    [string]$Distro
)

$ErrorActionPreference = 'Stop'
$NetworkName = 'common_link'

# --- WSL 実行ヘルパ ---------------------------------------------------------
# 指定ディストリビューションと、このスクリプトのあるフォルダを作業ディレクトリにして
# WSL 内でコマンドを実行する。
$wslBaseArgs = @()
if ($Distro) {
    $wslBaseArgs += @('-d', $Distro)
}

# スクリプト配置フォルダ（＝docker-compose.yml のある場所）を WSL パスへ変換する。
# wsl.exe へ引数を渡すとバックスラッシュが失われるため、PowerShell 側で /mnt/x/... へ変換する。
$scriptDir = $PSScriptRoot
if ($scriptDir -notmatch '^([A-Za-z]):\\(.*)$') {
    throw "WSL パスへ変換できないパス形式です: $scriptDir"
}
$drive = $Matches[1].ToLower()
$rest = $Matches[2] -replace '\\', '/'
$wslPath = "/mnt/$drive/$rest"

function Invoke-Wsl {
    param([Parameter(Mandatory)][string[]]$CommandArgs)
    # --cd で compose ファイルのあるフォルダに移動してから実行する。
    # Docker の出力はそのままコンソールへ流し、終了コードはスクリプト変数に退避する
    # （return 値をパイプラインに乗せると表示出力に混ざるため）。
    & wsl @wslBaseArgs --cd $wslPath @CommandArgs
    $script:LastWslExit = $LASTEXITCODE
}

# --- Docker の存在確認 ------------------------------------------------------
& wsl @wslBaseArgs docker version --format '{{.Server.Version}}' > $null 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "WSL2 上で Docker に接続できません。WSL 内で Docker(デーモン) が起動しているか確認してください。"
}

Write-Host "対象: $scriptDir" -ForegroundColor DarkGray
Write-Host "WSL パス: $wslPath" -ForegroundColor DarkGray

switch ($Action) {
    'up' {
        # common_link ネットワークが無ければ作成する（初回対応・冪等）。
        & wsl @wslBaseArgs docker network inspect $NetworkName > $null 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ネットワーク '$NetworkName' を作成します..." -ForegroundColor Cyan
            Invoke-Wsl @('docker', 'network', 'create', '--driver', 'bridge', $NetworkName)
            if ($script:LastWslExit -ne 0) { throw "ネットワーク '$NetworkName' の作成に失敗しました。" }
        }
        else {
            Write-Host "ネットワーク '$NetworkName' は既に存在します。" -ForegroundColor DarkGray
        }

        Write-Host "コンテナを起動します (docker compose up -d)..." -ForegroundColor Cyan
        Invoke-Wsl @('docker', 'compose', 'up', '-d')
        if ($script:LastWslExit -ne 0) { throw "docker compose up に失敗しました。" }

        Write-Host "`n起動しました。稼働状況:" -ForegroundColor Green
        Invoke-Wsl @('docker', 'compose', 'ps')
    }
    'down' {
        Write-Host "コンテナを停止します (docker compose down)..." -ForegroundColor Cyan
        Invoke-Wsl @('docker', 'compose', 'down')
        if ($script:LastWslExit -ne 0) { throw "docker compose down に失敗しました。" }
        Write-Host "停止しました。" -ForegroundColor Green
    }
    'ps' {
        Invoke-Wsl @('docker', 'compose', 'ps')
    }
    'logs' {
        Invoke-Wsl @('docker', 'compose', 'logs', '-f')
    }
}
