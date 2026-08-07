<#
.SYNOPSIS
    LocalServicesOnDocker のコンテナ群を WSL2 上の Docker で起動・停止する。

.DESCRIPTION
    README.md の手順（common_link ネットワーク作成 → docker compose up -d / down）を
    Windows の PowerShell から WSL2 経由で実行する。
    Docker は WSL2 内にインストールされている前提。

    この環境では次の 2 点が問題になるため、スクリプト側で対処している。
      ① WSL2 の VM がアイドルで自動停止し、DB(MySQL/SQL Server) の書き込みが
         中断されてデータが破損する（→ クラッシュループ）。
      ② VM が停止すると Windows の localhost からコンテナの公開ポートへ到達できない。
    どちらも根本原因は「VM のアイドル停止」なので、WSL 内に常駐プロセス
    （キープアライブ）を立てて VM を起動したままにすることで両方を防ぐ。
    加えて各 DB が接続可能になるまで待機し、破損等で準備できないコンテナは
    自動で作り直す（本 compose は永続ボリューム未使用のため作り直しは無害）。

.PARAMETER Action
    up    : common_link を作成し起動、各 DB の準備完了まで待機する（既定）。
    down  : docker compose down で停止し、キープアライブも解除する。
    ps    : コンテナの稼働状況を表示する。
    logs  : コンテナのログを表示する（Ctrl+C で終了）。
    help  : 使い方（指定できるサービス名の一覧）を表示して終了する。
    省略できる（既定 up）。先頭の引数が上記以外ならサービス名とみなす。

.PARAMETER Service
    対象とするサービス名。スペース区切りで複数指定できる。大文字小文字は区別しない。
    all を指定すると全サービス。**省略した場合は全サービスが対象**（従来どおりの動作）。
    down でサービスを指定した場合は、残りのコンテナのためキープアライブを解除しない。

.PARAMETER Distro
    使用する WSL ディストリビューション名。省略時は既定のディストリビューションを使用する。

.PARAMETER Help
    使い方（指定できるサービス名の一覧）を表示して終了する。
    引数なしは「全サービスを up」なので、ヘルプは help / -Help で明示的に要求する。

.PARAMETER NoWait
    up 時に DB の準備完了待ちを行わない。

.PARAMETER NoPause
    完了時のキー入力待ち（Start-Services.bat の pause 相当）を行わない。
    入力がリダイレクトされている非対話実行では、指定しなくても自動的に待たない。

.PARAMETER AsLibrary
    定義（設定テーブルと関数）だけを読み込み、up/down 等の本処理は実行せずに戻る。
    Reboot-Services_wsl2.ps1 がドットソースで再利用するための内部用スイッチ。

.EXAMPLE
    .\Start-Services.ps1
    コンテナを起動し、全 DB が接続可能になるまで待つ。

.EXAMPLE
    .\Start-Services.ps1 down
    コンテナを停止する。

.EXAMPLE
    .\Start-Services_wsl2.ps1 mysql redis
    mysql と redis だけを起動し、準備完了まで待つ（アクション省略＝up）。

.EXAMPLE
    .\Start-Services_wsl2.ps1 down oracle
    oracle だけを停止・削除する（キープアライブは維持）。

.EXAMPLE
    .\Start-Services_wsl2.ps1 help
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

    [string]$Distro,

    [switch]$Help,

    [switch]$NoWait,

    [switch]$NoPause,

    [switch]$AsLibrary
)

$ErrorActionPreference = 'Stop'
$NetworkName = 'common_link'
# キープアライブ: Windows 側に常駐する wsl.exe が sleep を保持する。
# 特徴的な秒数（約68年）を識別子に使う。
$KeepAliveSleep = '2147483647'
# pgrep -f 用パターン。先頭文字を [x] で囲むことで pgrep 自身の
# コマンドライン（パターン文字列を含む）への自己マッチを防ぐ。
$KeepAlivePat = '[2]147483647'

# 公開ポート（Windows 側の到達確認用）。
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
    # mongosh は --eval 実行前にサーバへ接続するため、括弧・引用符を含まない
    # 単純な式 '1' で十分（接続失敗時は非ゼロ終了）。特殊文字を避けることで
    # Windows PowerShell 5.1 の引数渡しでも壊れない。
    mongo     = @('mongosh', '--quiet', '--eval', '1')
    mysql     = @('mysqladmin', 'ping', '-h', '127.0.0.1', '-uroot', '-pseigi@123', '--silent')
    postgres  = @('pg_isready', '-h', '127.0.0.1', '-U', 'postgres')
    # bash -lc に複雑な文字列を渡すと wsl.exe 経由で引用符が壊れるため、
    # sqlcmd を直接・トークン配列で呼ぶ（各要素が個別の引数として渡る）。
    # start-up.sh は Northwind を完全ロードした後にセンチネル表 __NorthwindReady を作る。
    # -b を付けて、その表がまだ無い（＝データ未ロード）間はエラー＝未準備とみなす。
    # クエリは空白のみで特殊文字を含まないため PowerShell 5.1 でも壊れない。
    sqlserver = @('/opt/mssql-tools18/bin/sqlcmd', '-S', 'localhost', '-U', 'SA',
        '-P', 'seigi@123', '-C', '-b', '-d', 'Northwind', '-Q', 'SELECT ok FROM __NorthwindReady')
    # oracle/init/01_setup.sql は Shippers 表を作った「後」に別名サービス XE を作る。
    # そのため「XE 経由で SCOTT に接続でき、かつ Shippers が 3 行ある」ことを
    # /ready/ready.sql で確認すれば、データ準備完了と判定できる。
    # -L はログイン失敗時に再試行せず非ゼロ終了する。引数はいずれも空白・引用符を
    # 含まないため wsl.exe 経由でも壊れない。
    oracle    = @('sqlplus', '-s', '-L', 'SCOTT/tiger@localhost/XE', '@/ready/ready.sql')
}

# 準備完了待ちの上限（秒）。Oracle は初回起動が長いため個別に延長する。
$DefaultReadyTimeoutSec = 150
$ReadyTimeouts = @{ oracle = 300 }

# --- 出力ヘルパ -------------------------------------------------------------
# wsl.exe を実行すると、以降 PowerShell の改行が行頭復帰(CR)を伴わなくなり、
# 出力が階段状にずれることがある（特に Windows Terminal + Windows PowerShell 5.1）。
# そこで Write-Host は使わず、[Console]::Out へ明示的に CR+LF を書き込むことで、
# ターミナルの状態に依存せず必ず行頭へ戻す。色は [Console]::ForegroundColor で付ける。
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

# --- WSL 実行ヘルパ ---------------------------------------------------------
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
    # 出力をコンソールへ流し、終了コードを $script:LastWslExit に退避する。
    param([Parameter(Mandatory)][string[]]$CommandArgs)
    & wsl @wslBaseArgs --cd $wslPath @CommandArgs
    $script:LastWslExit = $LASTEXITCODE
}

function Invoke-WslQuiet {
    # 出力を捨てて終了コードだけ返す（判定用）。
    # native コマンドが stderr に出力すると、$ErrorActionPreference='Stop' の
    # Windows PowerShell 5.1 では終了エラー扱いになるため、一時的に Continue にし、
    # 全ストリームを *> $null で破棄する（例: mysqladmin の警告で停止しないように）。
    param([Parameter(Mandatory)][string[]]$CommandArgs)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & wsl @wslBaseArgs --cd $wslPath @CommandArgs *> $null
    }
    finally {
        $ErrorActionPreference = $prev
    }
    return $LASTEXITCODE
}

# --- キープアライブ（VM のアイドル停止を防ぐ）------------------------------
function Start-KeepAlive {
    # Windows 側に常駐する wsl.exe プロセス（sleep）を 1 つ起動する。
    #  ・VM のアイドル停止を防ぐ（問題①）。
    #  ・Windows↔WSL の localhost 転送は「Windows 側に生きた wsl セッションがある間」
    #    だけ維持される。VM 内の sleep だけでは不十分なので、Windows 側で wsl.exe を
    #    保持する（問題②）。
    # 注: Start-Process にスペースを含む単一引数を渡すとクォートされず壊れるため、
    #     引数はすべてスペースなしのトークンにする（-e sleep <秒> 方式）。
    & wsl @wslBaseArgs bash -c "pgrep -f '$KeepAlivePat' >/dev/null 2>&1"
    if ($LASTEXITCODE -eq 0) {
        Write-Line "キープアライブは既に稼働中。" -Color DarkGray
        return
    }
    $kaArgs = @()
    if ($Distro) { $kaArgs += @('-d', $Distro) }
    $kaArgs += @('-e', 'sleep', $KeepAliveSleep)
    Start-Process -FilePath 'wsl' -ArgumentList $kaArgs -WindowStyle Hidden | Out-Null
    Start-Sleep -Milliseconds 1500
    & wsl @wslBaseArgs bash -c "pgrep -f '$KeepAlivePat' >/dev/null 2>&1"
    if ($LASTEXITCODE -eq 0) {
        Write-Line "キープアライブ稼働中（VM とlocalhost転送を維持）。" -Color DarkGray
    }
    else {
        Write-Line "警告: キープアライブの起動を確認できませんでした。" -Color Yellow
    }
}

function Stop-KeepAlive {
    # 常駐 sleep を止めると、それを保持していた wsl.exe セッションも終了する。
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try { & wsl @wslBaseArgs bash -c "pkill -f '$KeepAliveSleep'" *> $null }
    finally { $ErrorActionPreference = $prev }
}

# --- Docker デーモンの準備待ち（コールドブート直後対応）---------------------
function Wait-DockerDaemon {
    for ($i = 0; $i -lt 30; $i++) {
        & wsl @wslBaseArgs docker version --format '{{.Server.Version}}' > $null 2>&1
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Seconds 2
    }
    throw "WSL2 上で Docker に接続できません。WSL 内で Docker(デーモン) が起動しているか確認してください。"
}

# --- サービス準備完了待ち＋自動復旧 ----------------------------------------
function Wait-Service {
    param(
        [Parameter(Mandatory)][string]$Service,
        [Parameter(Mandatory)][string[]]$Check,
        [int]$TimeoutSec = 150
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        $code = Invoke-WslQuiet (@('docker', 'compose', 'exec', '-T', $Service) + $Check)
        if ($code -eq 0) { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

function Ensure-Service {
    # 準備完了を待ち、駄目なら 1 度だけ作り直して再度待つ。
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
    # 破損データを完全に破棄するため、コンテナと匿名ボリュームを削除してから作り直す。
    # 公式 mysql/mssql イメージは data ディレクトリを匿名ボリュームに持つため、
    # --force-recreate では破損データが再利用されてしまう。rm -sfv で匿名ボリュームごと
    # 削除し、up で作り直すとイメージから正しく初期化される。
    Invoke-WslQuiet @('docker', 'compose', 'rm', '-sfv', $Service) | Out-Null
    Invoke-WslQuiet @('docker', 'compose', 'up', '-d', $Service) | Out-Null
    Write-Line ("  - {0,-10} 再準備待ち..." -f $Service) -NoNewline
    if (Wait-Service -Service $Service -Check $Check -TimeoutSec $TimeoutSec) {
        Write-Line " OK" -Color Green
        return $true
    }
    Write-Line " NG" -Color Red
    return $false
}

# --- Windows 側からの到達確認 ----------------------------------------------
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

# --- ヘルプ部品 -------------------------------------------------------------
function Show-ServiceList {
    # 指定できるサービス名の一覧。Stop-Services_wsl2.ps1 / Reboot-Services_wsl2.ps1 の
    # ヘルプからも同じものを使う（一覧が二重管理にならないようにするため）。
    param([string]$AllNote = '上記すべて')
    Write-Line "指定できるサービス名:" -Color Cyan
    foreach ($name in $ServicePorts.Keys) {
        Write-Line ("  {0,-10} localhost:{1}" -f $name, $ServicePorts[$name])
    }
    Write-Line ("  {0,-10} {1}" -f 'all', $AllNote)
}

# ヘルプ表示を要求する引数。-Help スイッチでも同じ。
$HelpTokens = @('help', '--help', '/?', '?')

function Test-HelpRequested {
    # 引数のどこかにヘルプ要求のトークンがあれば $true。
    param([string[]]$Names)
    return (@($Names | Where-Object { $HelpTokens -contains $_ }).Count -gt 0)
}

# --- サービス名の解決 -------------------------------------------------------
function Resolve-Targets {
    # 指定名を正規のサービス名へ解決する。all は全サービスへ展開し、重複は取り除く。
    # 未知の名前は $script:UnknownNames へ集める（呼び出し側で確認する）。
    # Reboot-Services_wsl2.ps1 からもドットソースで再利用する。
    param([string[]]$Names)
    $known = @($ServicePorts.Keys)
    $resolved = @()
    $script:UnknownNames = @()
    foreach ($name in $Names) {
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($name -eq 'all') {
            foreach ($k in $known) { if ($resolved -notcontains $k) { $resolved += $k } }
            continue
        }
        # -eq は既定で大文字小文字を区別しないため、入力の表記ゆれを正規名へ寄せられる。
        $match = @($known | Where-Object { $_ -eq $name })
        if ($match.Count -gt 0) {
            if ($resolved -notcontains $match[0]) { $resolved += $match[0] }
        }
        else {
            $script:UnknownNames += $name
        }
    }
    return $resolved
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

# ===========================================================================
# ドットソース（. Start-Services_wsl2.ps1 -AsLibrary）で読み込まれた場合は、上の定義
# だけを呼び出し元のスコープへ提供し、本処理は行わずに戻る。
if ($AsLibrary) { return }

# 以降はドットソース時には実行されない（Show-Usage も呼び出し元へは渡らないため、
# Reboot-Services_wsl2.ps1 が自前の Show-Usage を定義しても衝突しない）。
function Show-Usage {
    Write-Line ""
    Write-Line "使い方: .\Start-Services_wsl2.ps1 [up|down|ps|logs|help] [<サービス名> ...] [-Distro <名前>] [-NoWait] [-NoPause]" -Color Cyan
    Write-Line ""
    Write-Line "  アクションを省略すると up、サービス名を省略すると全サービスが対象になります。"
    Write-Line ""
    Write-Line "アクション:" -Color Cyan
    Write-Line "  up          起動し、DB の準備完了まで待つ（既定）"
    Write-Line "  down        停止する（全サービスのときはキープアライブも解除）"
    Write-Line "  ps          稼働状況を表示する"
    Write-Line "  logs        ログを表示する（Ctrl+C で終了）"
    Write-Line "  help        この使い方を表示する（-Help でも可）"
    Write-Line ""
    Show-ServiceList -AllNote '上記すべて（省略時と同じ）'
    Write-Line ""
    Write-Line "例:" -Color Cyan
    Write-Line "  .\Start-Services_wsl2.ps1"
    Write-Line "  .\Start-Services_wsl2.ps1 mysql redis"
    Write-Line "  .\Start-Services_wsl2.ps1 down oracle"
    Write-Line "  .\Start-Services_wsl2.ps1 help"
    Write-Line ""
    Write-Line "詳細は Get-Help .\Start-Services_wsl2.ps1 -Full で参照できます。" -Color DarkGray
}

# --- 引数の解釈（本処理前に済ませ、問題があればヘルプを出して終了）--------------
# 引数なしは「全サービスを up」なので、ヘルプは help / -Help で明示的に要求する。
if ($Help -or (Test-HelpRequested -Names (@($Action) + @($Service)))) {
    Show-Usage
    Wait-ForKey
    exit 0
}

# 先頭の引数がアクション名でなければサービス名とみなし、アクションは既定の up にする
# （例: .\Start-Services_wsl2.ps1 mysql redis）。
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
# 注: if 式の結果を代入すると 1 要素の配列が文字列へ潰れてしまうため、配列のまま代入する。
[string[]]$composeTargets = @()
if (-not $isAllServices) { $composeTargets = @($targets) }

try {
Write-Line "対象: $scriptDir" -Color DarkGray
Write-Line "WSL パス: $wslPath" -Color DarkGray
if (-not $isAllServices) {
    Write-Line ("対象サービス: {0}" -f ($targets -join ', ')) -Color Cyan
}

switch ($Action) {
    'up' {
        # ①②対策: まず VM を起こしっぱなしにする。
        Start-KeepAlive
        Wait-DockerDaemon

        # common_link ネットワークが無ければ作成する（初回対応・冪等）。
        & wsl @wslBaseArgs docker network inspect $NetworkName > $null 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Line "ネットワーク '$NetworkName' を作成します..." -Color Cyan
            Invoke-Wsl @('docker', 'network', 'create', '--driver', 'bridge', $NetworkName)
            if ($script:LastWslExit -ne 0) { throw "ネットワーク '$NetworkName' の作成に失敗しました。" }
        }
        else {
            Write-Line "ネットワーク '$NetworkName' は既に存在します。" -Color DarkGray
        }

        Write-Line "コンテナを起動します (docker compose up -d)..." -Color Cyan
        Invoke-Wsl (@('docker', 'compose', 'up', '-d') + $composeTargets)
        if ($script:LastWslExit -ne 0) { throw "docker compose up に失敗しました。" }

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

            # Windows 側からの到達確認（問題②の検証）。
            Write-Line ""
            Write-Line "Windows(localhost) からの到達確認:" -Color Cyan
            $unreachable = @()
            foreach ($svc in $targets) {
                $port = $ServicePorts[$svc]
                if (Test-WindowsPort -Port $port) {
                    Write-Line ("  - {0,-10} localhost:{1} 到達 OK" -f $svc, $port) -Color Green
                }
                else {
                    Write-Line ("  - {0,-10} localhost:{1} 到達 NG" -f $svc, $port) -Color Red
                    $unreachable += $svc
                }
            }

            if ($unreachable.Count -gt 0) {
                $ip = (& wsl @wslBaseArgs hostname -I).Trim().Split(' ')[0]
                Write-Line ""
                Write-Line "警告: Windows の localhost から到達できないサービスがあります。" -Color Yellow
                Write-Line "      WSL2 の localhost 転送が無効な可能性があります。" -Color Yellow
                Write-Line ("      回避策: 接続先ホストに WSL2 の IP [{0}] を指定してください。" -f $ip) -Color Yellow
                Write-Line ("      例: > `$env:DB_HOST='{0}'; npm test" -f $ip) -Color Yellow
            }

            if ($failed.Count -gt 0) {
                throw ("次のサービスが準備完了になりませんでした: {0}" -f ($failed -join ', '))
            }
        }

        Write-Line ""
        Write-Line "起動しました。稼働状況:" -Color Green
        Invoke-Wsl (@('docker', 'compose', 'ps') + $composeTargets)
    }
    'down' {
        Write-Line "コンテナを停止します (docker compose down)..." -Color Cyan
        Invoke-Wsl (@('docker', 'compose', 'down') + $composeTargets)
        if ($script:LastWslExit -ne 0) { throw "docker compose down に失敗しました。" }
        if ($isAllServices) {
            Stop-KeepAlive
            Write-Line "停止しました（キープアライブも解除）。" -Color Green
        }
        else {
            # 一部だけ停止する場合は、残るコンテナのために VM を起こしたままにする。
            Write-Line "停止しました（他のコンテナが残るためキープアライブは維持）。" -Color Green
        }
    }
    'ps' {
        Invoke-Wsl (@('docker', 'compose', 'ps') + $composeTargets)
    }
    'logs' {
        Invoke-Wsl (@('docker', 'compose', 'logs', '-f') + $composeTargets)
    }
}
}
finally {
    Wait-ForKey
}
