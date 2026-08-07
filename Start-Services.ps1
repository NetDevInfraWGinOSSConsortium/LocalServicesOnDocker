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
    help  : 使い方（指定できるサービス名の一覧）を表示して終了する。
    省略できる（既定 up）。先頭の引数が上記以外ならサービス名とみなす。

.PARAMETER Service
    対象とするサービス名。スペース区切りで複数指定できる。大文字小文字は区別しない。
    all を指定すると全サービス。**省略した場合は全サービスが対象**（従来どおりの動作）。

.PARAMETER Help
    使い方（指定できるサービス名の一覧）を表示して終了する。
    引数なしは「全サービスを up」なので、ヘルプは help / -Help で明示的に要求する。

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

.EXAMPLE
    .\Start-Services.ps1 mysql redis
    mysql と redis だけを起動し、準備完了まで待つ（アクション省略＝up）。

.EXAMPLE
    .\Start-Services.ps1 down oracle
    oracle だけを停止・削除する。

.EXAMPLE
    .\Start-Services.ps1 logs mysql
    mysql のログだけを表示する。

.EXAMPLE
    .\Start-Services.ps1 help
    使い方と指定できるサービス名の一覧を表示する（-Help でも同じ）。
#>
[CmdletBinding()]
param(
    # アクション名以外も受け取れるよう ValidateSet は付けず、本処理側で判定する
    # （先頭がアクション名でなければサービス名とみなすため）。
    [Parameter(Position = 0)]
    [string]$Action = 'up',

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Service,

    [switch]$Help,

    [switch]$NoWait,

    [switch]$NoPause,

    [switch]$AsLibrary
)

# native docker はプログレス等を stderr に書き、また意図的に非ゼロ終了する場面
# （ネットワーク未作成の inspect など）がある。EAP=Stop だとそれだけで停止して
# しまうため Continue とし、成否は $LASTEXITCODE で明示的に判定する。
# 致命的な失敗は throw で止める（throw は EAP に関係なく終了する）。
$ErrorActionPreference = 'Continue'

# --- 共通部品の読み込み -----------------------------------------------------
# エンジンに依存しない設定（$NetworkName / $ServicePorts / $ReadyChecks /
# $ReadyTimeouts / $HelpTokens）と関数（Write-Line / Wait-ForKey / Wait-Service /
# Ensure-Service / Test-WindowsPort / Show-ServiceList / Test-HelpRequested /
# Resolve-Targets）は Services.Common.ps1 に集約してある。
# ドットソースなので、本スクリプトを -AsLibrary で読み込む Stop / Reboot 系にも
# そのまま引き継がれる。
$commonPath = Join-Path $PSScriptRoot 'Services.Common.ps1'
if (-not (Test-Path -LiteralPath $commonPath)) {
    throw "共通部品が見つかりません: $commonPath"
}
. $commonPath

# --- compose 実行（Services.Common.ps1 の Wait-Service / Ensure-Service が使う）--
function Invoke-ComposeQuiet {
    # docker compose の後ろに付く引数を受け取り、出力を捨てて終了コードを返す。
    param([Parameter(Mandatory)][string[]]$CommandArgs)
    & docker compose @CommandArgs *> $null
    return $LASTEXITCODE
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

# ===========================================================================
# ドットソース（. Start-Services.ps1 -AsLibrary）で読み込まれた場合は、上の定義
# だけを呼び出し元のスコープへ提供し、本処理は行わずに戻る。
if ($AsLibrary) { return }

# 以降はドットソース時には実行されない（Show-Usage も呼び出し元へは渡らないため、
# Reboot-Services.ps1 が自前の Show-Usage を定義しても衝突しない）。
function Show-Usage {
    Write-Line ""
    Write-Line "使い方: .\Start-Services.ps1 [up|down|ps|logs|help] [<サービス名> ...] [-NoWait] [-NoPause]" -Color Cyan
    Write-Line ""
    Write-Line "  アクションを省略すると up、サービス名を省略すると全サービスが対象になります。"
    Write-Line ""
    Write-Line "アクション:" -Color Cyan
    Write-Line "  up          起動し、DB の準備完了まで待つ（既定）"
    Write-Line "  down        停止する"
    Write-Line "  ps          稼働状況を表示する"
    Write-Line "  logs        ログを表示する（Ctrl+C で終了）"
    Write-Line "  help        この使い方を表示する（-Help でも可）"
    Write-Line ""
    Show-ServiceList -AllNote '上記すべて（省略時と同じ）'
    Write-Line ""
    Write-Line "例:" -Color Cyan
    Write-Line "  .\Start-Services.ps1"
    Write-Line "  .\Start-Services.ps1 mysql redis"
    Write-Line "  .\Start-Services.ps1 down oracle"
    Write-Line "  .\Start-Services.ps1 help"
    Write-Line ""
    Write-Line "詳細は Get-Help .\Start-Services.ps1 -Full で参照できます。" -Color DarkGray
}

# --- 引数の解釈（本処理前に済ませ、問題があればヘルプを出して終了）--------------
# 引数なしは「全サービスを up」なので、ヘルプは help / -Help で明示的に要求する。
if ($Help -or (Test-HelpRequested -Names (@($Action) + @($Service)))) {
    Show-Usage
    Wait-ForKey
    exit 0
}

# 先頭の引数がアクション名でなければサービス名とみなし、アクションは既定の up にする
# （例: .\Start-Services.ps1 mysql redis）。
$KnownActions = @('up', 'down', 'ps', 'logs')
if ($Action -and $KnownActions -notcontains $Action) {
    $Service = @($Action) + @($Service)
    $Action = 'up'
}

if ($Service -and @($Service).Count -gt 0) {
    $targets = @(Resolve-Targets -Names $Service)
    if ($script:UnknownNames.Count -gt 0) {
        Write-Line ("不明なアクション名／サービス名です: {0}" -f ($script:UnknownNames -join ', ')) -Color Red
        Show-Usage
        Wait-ForKey
        exit 1
    }
    if ($targets.Count -eq 0) {
        Show-Usage
        Wait-ForKey
        exit 1
    }
}
else {
    # サービス名の指定なし＝全サービスが対象（従来どおりの動作）。
    $targets = @($ServicePorts.Keys)
}
$isAllServices = ($targets.Count -eq $ServicePorts.Count)
# 全サービスが対象なら compose にサービス名を渡さず、従来とまったく同じコマンドにする。
#  ・down はサービスを指定するとプロジェクトのネットワークが削除されない。
#  ・compose ファイルにここで管理していないサービスが増えても取りこぼさない。
# 注: if 式の結果を代入すると 1 要素の配列が文字列へ潰れ、スプラッティングで 1 文字ずつ
#     引数化されてしまうため、配列のまま代入する。
[string[]]$composeTargets = @()
if (-not $isAllServices) { $composeTargets = @($targets) }

try {
    # docker-compose.yml のあるフォルダ（＝本スクリプトの場所）で実行する。
    Push-Location -LiteralPath $PSScriptRoot
    Write-Line "対象: $PSScriptRoot" -Color DarkGray
    if (-not $isAllServices) {
        Write-Line ("対象サービス: {0}" -f ($targets -join ', ')) -Color Cyan
    }

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
            & docker compose up -d @composeTargets
            if ($LASTEXITCODE -ne 0) { throw "docker compose up に失敗しました。" }

            if (-not $NoWait) {
                Write-Line ""
                Write-Line "各 DB の準備完了を待機します（初回や破損時は作り直します）:" -Color Cyan
                $failed = @()
                foreach ($svc in $targets) {
                    $timeout = if ($ReadyTimeouts.ContainsKey($svc)) { $ReadyTimeouts[$svc] } else { $DefaultReadyTimeoutSec }
                    if (-not (Ensure-Service -Service $svc -Check $ReadyChecks[$svc] -TimeoutSec $timeout)) {
                        $failed += $svc
                    }
                }

                Write-Line ""
                Write-Line "localhost からの到達確認:" -Color Cyan
                foreach ($svc in $targets) {
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
            & docker compose ps @composeTargets
        }
        'down' {
            Write-Line "コンテナを停止します (docker compose down)..." -Color Cyan
            & docker compose down @composeTargets
            if ($LASTEXITCODE -ne 0) { throw "docker compose down に失敗しました。" }
            Write-Line "停止しました。" -Color Green
        }
        'ps' {
            & docker compose ps @composeTargets
        }
        'logs' {
            & docker compose logs -f @composeTargets
        }
    }
}
finally {
    Pop-Location -ErrorAction SilentlyContinue
    Wait-ForKey
}
