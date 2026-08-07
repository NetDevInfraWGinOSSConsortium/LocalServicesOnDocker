<#
.SYNOPSIS
    LocalServicesOnDocker のスクリプト群が共有する設定と関数（ドットソース専用）。

.DESCRIPTION
    Docker エンジン（Rancher Desktop のネイティブ docker / WSL2 内の dockerd）に
    依存しない部分だけをここへ集約する。Start-Services.ps1 と Start-Services_wsl2.ps1 が
    冒頭でドットソースし、Stop-Services*.ps1 / Reboot-Services*.ps1 は Start-Services*.ps1 を
    -AsLibrary でドットソースすることで、間接的に同じ定義を共有する。

        Services.Common.ps1
          ├─ Start-Services.ps1       ← Stop-Services.ps1 / Reboot-Services.ps1
          └─ Start-Services_wsl2.ps1  ← Stop-Services_wsl2.ps1 / Reboot-Services_wsl2.ps1

    このファイル自体は定義しか行わないため、直接実行しても何も起きない。

    エンジン依存のため、ここには置かないもの:
      ・$ErrorActionPreference（native は Continue、WSL2 版は Stop）
      ・Invoke-ComposeQuiet（下記の Wait-Service / Ensure-Service が呼ぶ差し替え点）
      ・Wait-DockerDaemon / Show-Usage / WSL 実行ヘルパ / キープアライブ

.NOTES
    ここの関数は、compose コマンドの実行を次の 2 つに委ねている。
    各 Start-Services*.ps1 は、これらを自分のエンジン向けに定義すること。

        function Invoke-ComposeQuiet {
            # docker compose の後ろに付く引数を受け取り、出力を捨てて終了コードを返す。
            param([Parameter(Mandatory)][string[]]$CommandArgs)
            ...
        }

        function Invoke-ComposeCapture {
            # 同上。ただし標準出力を文字列で返す（終了コードは捨てる）。
            param([Parameter(Mandatory)][string[]]$CommandArgs)
            ...
        }
#>

# 外部ネットワーク名（docker-compose.yml の networks: common_link: external: true）。
$NetworkName = 'common_link'

# 公開ポート（localhost 到達確認用）。
# 指定できるサービス名の一覧としても使うため、docker-compose.yml のサービス名と揃えること。
$ServicePorts = [ordered]@{
    redis     = 6379
    mongo     = 27017
    mysql     = 3306
    postgres  = 5432
    sqlserver = 1433
    oracle    = 1521
}

# 各サービスの「準備完了」判定コマンド（docker compose exec -T <svc> で実行）。
# 引数はトークン配列で渡す。wsl.exe 経由でも壊れないよう、空白・引用符・括弧を含む
# 複雑な文字列は避け、各要素が個別の引数として渡るようにしている。
$ReadyChecks = [ordered]@{
    redis     = @('redis-cli', 'ping')
    # mongosh は --eval 実行前にサーバへ接続するため、括弧・引用符を含まない
    # 単純な式 '1' で十分（接続失敗時は非ゼロ終了）。
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

# ヘルプ表示を要求する引数。各スクリプトの -Help スイッチでも同じ動作にする。
$HelpTokens = @('help', '--help', '/?', '?')

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

# --- pause（Start-Services.bat の pause 相当）-------------------------------
function Wait-ForKey {
    # ダブルクリック起動時にウィンドウが即閉じせず、出力やエラーを読めるよう、
    # 最後にキー入力を待つ。ただし入力がリダイレクトされている非対話実行
    # （Stop-Services.ps1 からの呼び出し・パイプ・CI など）では待たずに抜ける
    # （キー入力を受け取れずハングするのを防ぐ）。-NoPause でも抑止できる。
    # 注: $NoPause は呼び出し元スクリプトの param を参照する（ドットソース前提）。
    if ($NoPause) { return }
    try { if ([Console]::IsInputRedirected) { return } } catch { return }
    Write-Line ""
    Write-Line "続行するには何かキーを押してください . . ." -NoNewline
    try { [void][Console]::ReadKey($true) }
    catch { try { $null = Read-Host } catch { } }
    Write-Line ""
}

# --- サービス準備完了待ち＋自動復旧 ----------------------------------------
function Wait-Service {
    # 準備完了判定コマンドが成功するまで待つ。TimeoutSec を過ぎたら $false。
    param(
        [Parameter(Mandatory)][string]$Service,
        [Parameter(Mandatory)][string[]]$Check,
        [int]$TimeoutSec = 150
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        if ((Invoke-ComposeQuiet -CommandArgs (@('exec', '-T', $Service) + $Check)) -eq 0) { return $true }
        Start-Sleep -Seconds 3
    }
    return $false
}

function Ensure-Service {
    # 準備完了を待ち、駄目なら 1 度だけ作り直して再度待つ。
    # 破損データを完全に破棄するため、コンテナと匿名ボリュームを削除してから作り直す。
    # 公式 mysql/mssql イメージは data ディレクトリを匿名ボリュームに持つため、
    # --force-recreate では破損データが再利用されてしまう。rm -sfv で匿名ボリュームごと
    # 削除し、up で作り直すとイメージから正しく初期化される
    # （本 compose は永続ボリューム未使用のため作り直しは無害）。
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
    Invoke-ComposeQuiet -CommandArgs @('rm', '-sfv', $Service) | Out-Null
    Invoke-ComposeQuiet -CommandArgs @('up', '-d', $Service) | Out-Null
    Write-Line ("  - {0,-10} 再準備待ち..." -f $Service) -NoNewline
    if (Wait-Service -Service $Service -Check $Check -TimeoutSec $TimeoutSec) {
        Write-Line " OK" -Color Green
        return $true
    }
    Write-Line " NG" -Color Red
    return $false
}

# --- up 失敗時の案内と後片付け ----------------------------------------------
function Resolve-ComposeUpFailure {
    # docker compose up が失敗したときに呼ぶ。
    #  ① 公開ポートが既に埋まっていれば、その旨と原因の候補を示す。
    #     Rancher Desktop の docker と WSL2 内の dockerd は同じ公開ポートを使うため、
    #     もう一方が起動しているとポート競合で必ず失敗する（生の Docker エラーだけでは
    #     原因が読み取れないので、ここで補足する）。
    #  ② 起動できずに created のまま残ったコンテナを削除する。残しておくと稼働中でも
    #     停止中でもない中途半端な状態が次回まで持ち越されるため。
    param([Parameter(Mandatory)][string[]]$Targets)

    $busy = @()
    foreach ($svc in $Targets) {
        if (-not $ServicePorts.Contains($svc)) { continue }
        if (Test-WindowsPort -Port $ServicePorts[$svc] -TimeoutMs 500) {
            $busy += ("{0}({1})" -f $svc, $ServicePorts[$svc])
        }
    }
    if ($busy.Count -gt 0) {
        Write-Line ""
        Write-Line ("ヒント: 次のポートは既に使用されています: {0}" -f ($busy -join ', ')) -Color Yellow
        Write-Line "        Rancher Desktop 版と WSL2 版は同じ公開ポートを使うため、同時には起動できません。" -Color Yellow
        Write-Line "        もう一方を停止してから再実行してください（Stop-Services.ps1 / Stop-Services_wsl2.ps1）。" -Color Yellow
    }

    $out = Invoke-ComposeCapture -CommandArgs @('ps', '-a', '--status', 'created', '--format', '{{.Service}}')
    $created = @($out -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and ($Targets -contains $_) })
    if ($created.Count -gt 0) {
        Write-Line ("起動できなかったコンテナを片付けます: {0}" -f ($created -join ', ')) -Color DarkGray
        Invoke-ComposeQuiet -CommandArgs (@('rm', '-sf') + $created) | Out-Null
    }
}

# --- Windows(localhost) からの到達確認 --------------------------------------
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
    # 指定できるサービス名の一覧。全スクリプトのヘルプがこれを使う
    # （一覧が二重管理にならないようにするため）。
    param([string]$AllNote = '上記すべて')
    Write-Line "指定できるサービス名:" -Color Cyan
    foreach ($name in $ServicePorts.Keys) {
        Write-Line ("  {0,-10} localhost:{1}" -f $name, $ServicePorts[$name])
    }
    Write-Line ("  {0,-10} {1}" -f 'all', $AllNote)
}

function Test-HelpRequested {
    # 引数のどこかにヘルプ要求のトークンがあれば $true。
    param([string[]]$Names)
    return (@($Names | Where-Object { $HelpTokens -contains $_ }).Count -gt 0)
}

# --- サービス名の解決 -------------------------------------------------------
function Resolve-Targets {
    # 指定名を正規のサービス名へ解決する。all は全サービスへ展開し、重複は取り除く。
    # 未知の名前は $script:UnknownNames へ集める（呼び出し側で確認する）。
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
