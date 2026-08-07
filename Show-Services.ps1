<#
.SYNOPSIS
    LocalServicesOnDocker の稼働状況を表示する（Rancher Desktop のネイティブ docker 版）。

.DESCRIPTION
    コンテナの状態・DB の準備完了・localhost からの到達可否をまとめて表示する。
    起動・停止・再起動・作り直しは一切行わない（読み取り専用）。

    docker compose ps だけでは「コンテナは動いているが DB はまだ初期化中」を
    見分けられないため、Start-Services.ps1 と同じ判定テーブル（$ReadyChecks）で
    コンテナ内へ疎通確認を行い、その結果も併せて表示する。
    ただし Start-Services.ps1 と違い、準備できていなくても待たず、作り直しもしない。

    設定と判定処理は Start-Services.ps1 を -AsLibrary でドットソースして再利用する。

.PARAMETER Service
    表示するサービス名。スペース区切りで複数指定できる。all を指定すると全サービス。
    大文字小文字は区別しない。省略した場合は全サービスを表示する。

.PARAMETER Quick
    コンテナ内への準備完了判定を省略し、コンテナの状態と localhost 到達確認だけを行う。
    Oracle など判定に数秒かかるものを飛ばしたいときに使う。

.PARAMETER Help
    使い方（指定できるサービス名の一覧）を表示して終了する。
    引数なしは「全サービスを表示」なので、ヘルプは help / -Help で明示的に要求する。

.PARAMETER NoPause
    完了時のキー入力待ち（pause 相当）を行わない。
    入力がリダイレクトされている非対話実行では、指定しなくても自動的に待たない。

.EXAMPLE
    .\Show-Services.ps1
    全サービスの状態を表示する。

.EXAMPLE
    .\Show-Services.ps1 mysql redis
    mysql と redis の状態だけを表示する。

.EXAMPLE
    .\Show-Services.ps1 -Quick
    準備完了判定を省いて手早く表示する。

.NOTES
    終了コードは、対象サービスがすべて利用可能なら 0、そうでなければ 1。
    テストの前置きに使える（例: .\Show-Services.ps1 -NoPause && npm test）。
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Service,

    [switch]$Quick,

    [switch]$Help,

    [switch]$NoPause
)

# 設定テーブルと関数を Start-Services.ps1 から取り込む（-AsLibrary なので本処理は走らない）。
# 注: ドットソースは相手の param 変数も呼び出し元スコープへ持ち込むため、$Service /
#     $Help / $NoPause は同じ値を明示的に渡して、自分の指定が上書きされないようにする。
. "$PSScriptRoot\Start-Services.ps1" -AsLibrary -Service $Service -Help:$Help -NoPause:$NoPause

function Show-Usage {
    Write-Line ""
    Write-Line "使い方: .\Show-Services.ps1 [<サービス名> ...] [-Quick] [-NoPause]" -Color Cyan
    Write-Line ""
    Write-Line "  コンテナの状態・DB の準備完了・localhost 到達可否を表示します。"
    Write-Line "  起動・停止・再起動は行いません（読み取り専用）。"
    Write-Line "  サービス名を省略すると全サービスが対象になります。"
    Write-Line ""
    Show-ServiceList -AllNote '上記すべて（省略時と同じ）'
    Write-Line ""
    Write-Line "オプション:" -Color Cyan
    Write-Line "  -Quick      準備完了判定を省略し、コンテナ状態と到達確認だけ行う。"
    Write-Line "  -NoPause    終了時のキー入力待ちを行わない。"
    Write-Line "  -Help       この使い方を表示する（help でも可）。"
    Write-Line ""
    Write-Line "例:" -Color Cyan
    Write-Line "  .\Show-Services.ps1"
    Write-Line "  .\Show-Services.ps1 mysql redis"
    Write-Line "  .\Show-Services.ps1 -Quick"
    Write-Line ""
    Write-Line "終了コード: 対象がすべて利用可能なら 0、そうでなければ 1。" -Color DarkGray
    Write-Line "詳細は Get-Help .\Show-Services.ps1 -Full で参照できます。" -Color DarkGray
}

# --- 引数の解釈 -------------------------------------------------------------
if ($Help -or (Test-HelpRequested -Names $Service)) {
    Show-Usage
    Wait-ForKey
    exit 0
}

if ($Service -and @($Service).Count -gt 0) {
    $targets = @(Resolve-Targets -Names $Service)
    if ($script:UnknownNames.Count -gt 0) {
        Write-Line ("不明なサービス名です: {0}" -f ($script:UnknownNames -join ', ')) -Color Red
        Show-Usage
        Wait-ForKey
        exit 1
    }
}
if (-not $targets -or $targets.Count -eq 0) { $targets = @($ServicePorts.Keys) }

# ===========================================================================
$exitCode = 0

try {
    # docker-compose.yml のあるフォルダ（＝本スクリプトの場所）で実行する。
    Push-Location -LiteralPath $PSScriptRoot
    Write-Line "対象: $PSScriptRoot" -Color DarkGray

    # 状態表示なので、Wait-DockerDaemon のような待機はせず 1 回だけ確認する。
    # 注: try の中で return すると、下の exit $exitCode まで到達せず終了コードが
    #     伝わらないため、throw して catch に処理させる。
    & docker version --format '{{.Server.Version}}' > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Docker に接続できません。Rancher Desktop が起動しているか確認してください。"
    }

    & docker network inspect $NetworkName > $null 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Line "ネットワーク '$NetworkName': あり" -Color DarkGray
    }
    else {
        Write-Line "ネットワーク '$NetworkName': なし（起動時に自動作成されます）" -Color Yellow
    }

    # コンテナの状態を 1 回の問い合わせでまとめて取得する（サービス名=状態）。
    $states = @{}
    foreach ($line in (Invoke-ComposeCapture -CommandArgs @('ps', '-a', '--format', '{{.Service}}={{.State}}')) -split "`r?`n") {
        $kv = $line.Trim() -split '=', 2
        if ($kv.Count -eq 2 -and $kv[0]) { $states[$kv[0]] = $kv[1] }
    }

    # 見出しと値をすべて ASCII にそろえる（全角が混ざると桁がずれるため）。
    Write-Line ""
    Write-Line ("  {0,-10} {1,-10} {2,-6} {3,-6} {4}" -f 'SERVICE', 'CONTAINER', 'READY', 'PORT', 'LOCALHOST') -Color Cyan
    Write-Line ("  {0,-10} {1,-10} {2,-6} {3,-6} {4}" -f '-------', '---------', '-----', '----', '---------')

    $notAvailable = @()
    foreach ($svc in $targets) {
        $state = if ($states.ContainsKey($svc)) { $states[$svc] } else { '-' }
        $port = $ServicePorts[$svc]

        # 準備完了判定はコンテナ内で 1 回だけ実行する（待たない・作り直さない）。
        $ready = '-'
        if (-not $Quick) {
            if ($state -eq 'running') {
                $ready = if ((Invoke-ComposeQuiet -CommandArgs (@('exec', '-T', $svc) + $ReadyChecks[$svc])) -eq 0) { 'OK' } else { 'NG' }
            }
            else {
                $ready = 'NG'
            }
        }

        $reach = if (Test-WindowsPort -Port $port -TimeoutMs 700) { 'OK' } else { 'NG' }

        # 利用可能＝準備完了かつ到達可能。-Quick のときは判定できないので状態と到達で見る。
        $available = if ($Quick) { ($state -eq 'running') -and ($reach -eq 'OK') } else { ($ready -eq 'OK') -and ($reach -eq 'OK') }
        if (-not $available) { $notAvailable += $svc }

        $color = if ($available) { [System.ConsoleColor]::Green } elseif ($state -eq '-') { [System.ConsoleColor]::DarkGray } else { [System.ConsoleColor]::Yellow }
        Write-Line ("  {0,-10} {1,-10} {2,-6} {3,-6} {4}" -f $svc, $state, $ready, $port, $reach) -Color $color
    }

    Write-Line ""
    if ($notAvailable.Count -eq 0) {
        Write-Line ("{0} サービスすべて利用可能です。" -f $targets.Count) -Color Green
    }
    else {
        Write-Line ("利用できないサービス: {0}" -f ($notAvailable -join ', ')) -Color Yellow
        Write-Line ("  起動するには: .\Start-Services.ps1 {0}" -f ($notAvailable -join ' ')) -Color DarkGray
        Write-Line ("  作り直すには: .\Reboot-Services.ps1 {0} -Recreate" -f ($notAvailable -join ' ')) -Color DarkGray
        $exitCode = 1
    }
}
catch {
    Write-Line ""
    Write-Line ("エラー: {0}" -f $_.Exception.Message) -Color Red
    $exitCode = 1
}
finally {
    Pop-Location -ErrorAction SilentlyContinue
    Wait-ForKey
}

exit $exitCode
