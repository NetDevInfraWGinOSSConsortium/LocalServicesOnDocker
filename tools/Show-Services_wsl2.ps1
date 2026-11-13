<#
.SYNOPSIS
    LocalServicesOnDocker の稼働状況を表示する（WSL2 上の Docker 版）。

.DESCRIPTION
    コンテナの状態・DB の準備完了・Windows(localhost) からの到達可否・キープアライブの
    有無をまとめて表示する。起動・停止・再起動・作り直しは一切行わない（読み取り専用）。

    WSL2 の VM が停止している場合は、その旨だけを表示して終了する。
    wsl.exe でコマンドを実行すると VM が起動してしまい、前回のコンテナまで復帰して
    Rancher Desktop 版とポート競合しかねないため、状態確認では VM を起こさない。

    設定と判定処理は Start-Services_wsl2.ps1 を -AsLibrary でドットソースして再利用する。

.PARAMETER Service
    表示するサービス名。スペース区切りで複数指定できる。all を指定すると全サービス。
    大文字小文字は区別しない。省略した場合は全サービスを表示する。

.PARAMETER Distro
    使用する WSL ディストリビューション名。省略時は既定のディストリビューションを使用する。

.PARAMETER Quick
    コンテナ内への準備完了判定を省略し、コンテナの状態と到達確認だけを行う。

.PARAMETER Help
    使い方（指定できるサービス名の一覧）を表示して終了する。

.PARAMETER NoPause
    完了時のキー入力待ち（pause 相当）を行わない。

.EXAMPLE
    .\Show-Services_wsl2.ps1
    全サービスの状態を表示する。

.EXAMPLE
    .\Show-Services_wsl2.ps1 mysql -Distro Ubuntu-22.04
    指定ディストリビューション上の mysql の状態だけを表示する。

.NOTES
    終了コードは、対象サービスがすべて利用可能なら 0、そうでなければ 1。
    VM が停止している場合も 1。
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Service,

    [string]$Distro,

    [switch]$Quick,

    [switch]$Help,

    [switch]$NoPause
)

# 設定テーブルと関数を Start-Services_wsl2.ps1 から取り込む（-AsLibrary なので本処理は
# 走らない）。$Distro は WSL 実行ヘルパの組み立てに必要なので必ず渡す。
# 注: ドットソースは相手の param 変数も持ち込むため、自分の指定値を明示的に渡す。
$libArgs = @{ AsLibrary = $true; Service = $Service; Help = $Help; NoPause = $NoPause }
if ($PSBoundParameters.ContainsKey('Distro')) { $libArgs['Distro'] = $Distro }
. "$PSScriptRoot\Start-Services_wsl2.ps1" @libArgs

function Show-Usage {
    Write-Line ""
    Write-Line "使い方: .\Show-Services_wsl2.ps1 [<サービス名> ...] [-Distro <名前>] [-Quick] [-NoPause]" -Color Cyan
    Write-Line ""
    Write-Line "  コンテナの状態・DB の準備完了・localhost 到達可否を表示します。"
    Write-Line "  起動・停止・再起動は行いません（読み取り専用）。"
    Write-Line "  WSL2 の VM が停止している場合は、起こさずにその旨だけを表示します。"
    Write-Line "  サービス名を省略すると全サービスが対象になります。"
    Write-Line ""
    Show-ServiceList -AllNote '上記すべて（省略時と同じ）'
    Write-Line ""
    Write-Line "オプション:" -Color Cyan
    Write-Line "  -Distro     使用する WSL ディストリビューション名（省略時は既定）。"
    Write-Line "  -Quick      準備完了判定を省略し、コンテナ状態と到達確認だけ行う。"
    Write-Line "  -NoPause    終了時のキー入力待ちを行わない。"
    Write-Line "  -Help       この使い方を表示する（help でも可）。"
    Write-Line ""
    Write-Line "例:" -Color Cyan
    Write-Line "  .\Show-Services_wsl2.ps1"
    Write-Line "  .\Show-Services_wsl2.ps1 mysql redis"
    Write-Line "  .\Show-Services_wsl2.ps1 -Quick"
    Write-Line ""
    Write-Line "終了コード: 対象がすべて利用可能なら 0、そうでなければ 1。" -Color DarkGray
    Write-Line "詳細は Get-Help .\Show-Services_wsl2.ps1 -Full で参照できます。" -Color DarkGray
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
    Write-Line "対象: $scriptDir" -Color DarkGray
    Write-Line "WSL パス: $wslPath" -Color DarkGray

    # wsl -l -v は一覧を返すだけで VM を起動しない。出力は UTF-16LE なので、
    # PowerShell 側に混ざる NUL を落としてから解析する。
    #   例: "* Ubuntu-24.04    Running    2" / "  rancher-desktop  Stopped  2"
    # 注: 「稼働中のディストロが 1 つでもあるか」で判定してはいけない。
    #     Rancher Desktop は自前の rancher-desktop ディストロを常時動かしているため、
    #     それを数えると必ず「稼働中」になってしまう。見るのは対象ディストロだけ。
    $wanted = $Distro
    $state = $null
    foreach ($line in ((& wsl.exe -l -v) -replace "`0", '')) {
        if ($line -notmatch '^(\*?)\s*(\S+)\s+(\S+)\s+(\d+)\s*$') { continue }
        $isDefault = ($Matches[1] -eq '*')
        $name = $Matches[2]
        if ($wanted) { if ($name -eq $wanted) { $state = $Matches[3]; break } }
        elseif ($isDefault) { $wanted = $name; $state = $Matches[3]; break }
    }
    $isUp = ($state -eq 'Running')

    if (-not $isUp) {
        Write-Line ""
        if (-not $state) { Write-Line ("WSL2 のディストリビューション '{0}' が見つかりません。" -f $Distro) -Color Yellow }
        else { Write-Line ("WSL2 のディストリビューション '{0}' は停止しています（{1}）。" -f $wanted, $state) -Color Yellow }
        Write-Line "  状態確認のために VM を起動することはしません（起動すると前回のコンテナが" -Color DarkGray
        Write-Line "  復帰し、Rancher Desktop 版とポート競合する可能性があるため）。" -Color DarkGray
        Write-Line "  起動するには: .\Start-Services_wsl2.ps1" -Color DarkGray
        $exitCode = 1
    }
    else {
        # 注: try の中で return すると exit $exitCode に到達しないため throw する。
        & wsl @wslBaseArgs docker version --format '{{.Server.Version}}' > $null 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "WSL2 上で Docker に接続できません。WSL 内で Docker(デーモン) が起動しているか確認してください。"
        }

        & wsl @wslBaseArgs docker network inspect $NetworkName > $null 2>&1
        if ($LASTEXITCODE -eq 0) { Write-Line "ネットワーク '$NetworkName': あり" -Color DarkGray }
        else { Write-Line "ネットワーク '$NetworkName': なし（起動時に自動作成されます）" -Color Yellow }

        & wsl @wslBaseArgs bash -c "pgrep -f '$KeepAlivePat' >/dev/null 2>&1"
        if ($LASTEXITCODE -eq 0) { Write-Line "キープアライブ: 稼働中" -Color DarkGray }
        else { Write-Line "キープアライブ: なし（VM がアイドル停止する可能性があります）" -Color Yellow }

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
            Write-Line ("  起動するには: .\Start-Services_wsl2.ps1 {0}" -f ($notAvailable -join ' ')) -Color DarkGray
            Write-Line ("  作り直すには: .\Reboot-Services_wsl2.ps1 {0} -Recreate" -f ($notAvailable -join ' ')) -Color DarkGray
            $exitCode = 1
        }
    }
}
catch {
    Write-Line ""
    Write-Line ("エラー: {0}" -f $_.Exception.Message) -Color Red
    $exitCode = 1
}
finally {
    Wait-ForKey
}

exit $exitCode
