<#
.SYNOPSIS
    LocalServicesOnDocker のコンテナ群を Docker(Rancher Desktop) で起動・停止する。

.DESCRIPTION
    Rancher Desktop により Windows ネイティブで使える docker コマンドを用いて、
    README の手順（common_link ネットワーク作成 → docker compose up -d / down）を実行する。
    加えて各 DB が接続可能になるまで待機し、破損等で準備できないコンテナは自動で作り直す
    （本 compose は永続ボリューム未使用のため作り直しは無害）。

    以前の WSL 経由版にあった VM キープアライブ・localhost 転送対策・WSL パス変換は、
    Rancher Desktop のネイティブ docker では不要になったため廃止した。

.PARAMETER Action
    up    : common_link を作成し起動、各 DB の準備完了まで待機する（既定）。
    down  : docker compose down で停止する。
    ps    : コンテナの稼働状況を表示する。
    logs  : コンテナのログを表示する（Ctrl+C で終了）。

.PARAMETER NoWait
    up 時に DB の準備完了待ちを行わない（起動のみ）。

.PARAMETER NoPause
    完了時のキー入力待ち（Start-Services.bat の pause 相当）を行わない。
    入力がリダイレクトされている非対話実行では、指定しなくても自動的に待たない。

.PARAMETER AsLibrary
    定義（設定テーブルと関数）だけを読み込み、up/down 等の本処理は実行せずに戻る。
    Reboot-Services.ps1 がドットソースで再利用するための内部用スイッチ。

.EXAMPLE
    .\Start-Services.ps1
    コンテナを起動し、全 DB が接続可能になるまで待つ。

.EXAMPLE
    .\Start-Services.ps1 down
    コンテナを停止する。
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('up', 'down', 'ps', 'logs')]
    [string]$Action = 'up',

    [switch]$NoWait,

    [switch]$NoPause,

    [switch]$AsLibrary
)

# native docker はプログレス等を stderr に書き、また意図的に非ゼロ終了する場面
# （ネットワーク未作成の inspect など）がある。EAP=Stop だとそれだけで停止して
# しまうため Continue とし、成否は $LASTEXITCODE で明示的に判定する。
# 致命的な失敗は throw で止める（throw は EAP に関係なく終了する）。
$ErrorActionPreference = 'Continue'
$NetworkName = 'common_link'

# 公開ポート（localhost 到達確認用）。
$ServicePorts = [ordered]@{
    redis     = 6379
    mongo     = 27017
    mysql     = 3306
    postgres  = 5432
    sqlserver = 1433
    oracle    = 1521
}

# 各サービスの「準備完了」判定コマンド（docker compose exec -T <svc> で実行）。
$ReadyChecks = [ordered]@{
    redis     = @('redis-cli', 'ping')
    mongo     = @('mongosh', '--quiet', '--eval', '1')
    mysql     = @('mysqladmin', 'ping', '-h', '127.0.0.1', '-uroot', '-pseigi@123', '--silent')
    postgres  = @('pg_isready', '-h', '127.0.0.1', '-U', 'postgres')
    # start-up.sh は Northwind を完全ロードした後にセンチネル表 __NorthwindReady を作る。
    # -b を付けて、その表がまだ無い（＝データ未ロード）間はエラー＝未準備とみなす。
    sqlserver = @('/opt/mssql-tools18/bin/sqlcmd', '-S', 'localhost', '-U', 'SA',
        '-P', 'seigi@123', '-C', '-b', '-d', 'Northwind', '-Q', 'SELECT ok FROM __NorthwindReady')
    # oracle/init/01_setup.sql は Shippers 表を作った「後」に別名サービス XE を作る。
    # そのため「XE 経由で SCOTT に接続でき、かつ Shippers が 3 行ある」ことを
    # /ready/ready.sql で確認すれば、データ準備完了と判定できる。
    # -L はログイン失敗時に再試行せず非ゼロ終了する。
    oracle    = @('sqlplus', '-s', '-L', 'SCOTT/tiger@localhost/XE', '@/ready/ready.sql')
}

# 準備完了待ちの上限（秒）。Oracle は初回起動が長いため個別に延長する。
$DefaultReadyTimeoutSec = 150
$ReadyTimeouts = @{ oracle = 300 }

# --- 出力ヘルパ -------------------------------------------------------------
# 色付きで確実に行頭へ戻して出力する（ターミナル状態に依存しないよう CR+LF を明示）。
function Write-Line {
    param(
        [Parameter(Position = 0)][string]$Text = '',
        [System.ConsoleColor]$Color,
        [switch]$NoNewline
    )
    $hasColor = $PSBoundParameters.ContainsKey('Color')
    if ($hasColor) {
        $prevColor = [Console]::ForegroundColor
        [Console]::ForegroundColor = $Color
    }
    try {
        if ($NoNewline) { [Console]::Out.Write($Text) }
        else { [Console]::Out.Write($Text + "`r`n") }
    }
    finally {
        if ($hasColor) { [Console]::ForegroundColor = $prevColor }
    }
}

# --- pause（Start-Services.bat の pause 相当）-------------------------------
function Wait-ForKey {
    # ダブルクリック起動時にウィンドウが即閉じせず、出力やエラーを読めるよう、
    # 最後にキー入力を待つ。ただし入力がリダイレクトされている非対話実行
    # （Stop-Services.ps1 からの呼び出し・パイプ・CI など）では待たずに抜ける
    # （キー入力を受け取れずハングするのを防ぐ）。-NoPause でも抑止できる。
    if ($NoPause) { return }
    try { if ([Console]::IsInputRedirected) { return } } catch { return }
    Write-Line ""
    Write-Line "続行するには何かキーを押してください . . ." -NoNewline
    try { [void][Console]::ReadKey($true) }
    catch { try { $null = Read-Host } catch { } }
    Write-Line ""
}

# --- Docker デーモンの準備待ち（コールドブート直後対応）---------------------
function Wait-DockerDaemon {
    for ($i = 0; $i -lt 30; $i++) {
        & docker version --format '{{.Server.Version}}' > $null 2>&1
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Seconds 2
    }
    throw "Docker に接続できません。Rancher Desktop が起動しているか確認してください。"
}

# --- サービス準備完了待ち＋自動復旧 ----------------------------------------
function Test-Ready {
    # 準備完了判定コマンドをコンテナ内で実行し、終了コードを返す（出力は破棄）。
    param(
        [Parameter(Mandatory)][string]$Service,
        [Parameter(Mandatory)][string[]]$Check
    )
    & docker compose exec -T $Service @Check *> $null
    return $LASTEXITCODE
}

function Wait-Service {
    param(
        [Parameter(Mandatory)][string]$Service,
        [Parameter(Mandatory)][string[]]$Check,
        [int]$TimeoutSec = 150
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if ((Test-Ready -Service $Service -Check $Check) -eq 0) { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

function Ensure-Service {
    # 準備完了を待ち、駄目なら 1 度だけ作り直して再度待つ。
    # 公式 mysql/mssql イメージは data を匿名ボリュームに持つため、rm -sfv で
    # 匿名ボリュームごと削除してから up し直すと、イメージから正しく初期化される。
    param(
        [Parameter(Mandatory)][string]$Service,
        [Parameter(Mandatory)][string[]]$Check,
        [int]$TimeoutSec = 150
    )
    Write-Line ("  - {0,-10} 準備待ち..." -f $Service) -NoNewline
    if (Wait-Service -Service $Service -Check $Check -TimeoutSec $TimeoutSec) {
        Write-Line " OK" -Color Green
        return $true
    }
    Write-Line " 応答なし → 作り直し" -Color Yellow
    & docker compose rm -sfv $Service *> $null
    & docker compose up -d $Service *> $null
    Write-Line ("  - {0,-10} 再準備待ち..." -f $Service) -NoNewline
    if (Wait-Service -Service $Service -Check $Check -TimeoutSec $TimeoutSec) {
        Write-Line " OK" -Color Green
        return $true
    }
    Write-Line " NG" -Color Red
    return $false
}

# --- localhost 到達確認 -----------------------------------------------------
function Test-WindowsPort {
    param([int]$Port, [int]$TimeoutMs = 1500)
    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne($TimeoutMs) -and $client.Connected) {
            $client.EndConnect($iar)
            return $true
        }
        return $false
    }
    catch { return $false }
    finally { $client.Close() }
}

# ===========================================================================
# ドットソース（. Start-Services.ps1 -AsLibrary）で読み込まれた場合は、上の定義
# だけを呼び出し元のスコープへ提供し、本処理は行わずに戻る。
if ($AsLibrary) { return }

try {
    # docker-compose.yml のあるフォルダ（＝本スクリプトの場所）で実行する。
    Push-Location -LiteralPath $PSScriptRoot
    Write-Line "対象: $PSScriptRoot" -Color DarkGray

    switch ($Action) {
        'up' {
            Wait-DockerDaemon

            # common_link ネットワークが無ければ作成する（初回対応・冪等）。
            & docker network inspect $NetworkName > $null 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Line "ネットワーク '$NetworkName' を作成します..." -Color Cyan
                & docker network create --driver bridge $NetworkName | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "ネットワーク '$NetworkName' の作成に失敗しました。" }
            }
            else {
                Write-Line "ネットワーク '$NetworkName' は既に存在します。" -Color DarkGray
            }

            Write-Line "コンテナを起動します (docker compose up -d)..." -Color Cyan
            & docker compose up -d
            if ($LASTEXITCODE -ne 0) { throw "docker compose up に失敗しました。" }

            if (-not $NoWait) {
                Write-Line ""
                Write-Line "各 DB の準備完了を待機します（初回や破損時は作り直します）:" -Color Cyan
                $failed = @()
                foreach ($svc in $ReadyChecks.Keys) {
                    $timeout = if ($ReadyTimeouts.ContainsKey($svc)) { $ReadyTimeouts[$svc] } else { $DefaultReadyTimeoutSec }
                    if (-not (Ensure-Service -Service $svc -Check $ReadyChecks[$svc] -TimeoutSec $timeout)) {
                        $failed += $svc
                    }
                }

                Write-Line ""
                Write-Line "localhost からの到達確認:" -Color Cyan
                foreach ($svc in $ServicePorts.Keys) {
                    $port = $ServicePorts[$svc]
                    if (Test-WindowsPort -Port $port) {
                        Write-Line ("  - {0,-10} localhost:{1} 到達 OK" -f $svc, $port) -Color Green
                    }
                    else {
                        Write-Line ("  - {0,-10} localhost:{1} 到達 NG" -f $svc, $port) -Color Red
                    }
                }

                if ($failed.Count -gt 0) {
                    throw ("次のサービスが準備完了になりませんでした: {0}" -f ($failed -join ', '))
                }
            }

            Write-Line ""
            Write-Line "起動しました。稼働状況:" -Color Green
            & docker compose ps
        }
        'down' {
            Write-Line "コンテナを停止します (docker compose down)..." -Color Cyan
            & docker compose down
            if ($LASTEXITCODE -ne 0) { throw "docker compose down に失敗しました。" }
            Write-Line "停止しました。" -Color Green
        }
        'ps' {
            & docker compose ps
        }
        'logs' {
            & docker compose logs -f
        }
    }
}
finally {
    Pop-Location -ErrorAction SilentlyContinue
    Wait-ForKey
}
