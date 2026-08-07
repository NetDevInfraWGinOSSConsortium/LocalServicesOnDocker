<#
.SYNOPSIS
    LocalServicesOnDocker の指定したコンテナだけを再起動する（WSL2 上の Docker 版）。

.DESCRIPTION
    コマンドラインで指定したサービスだけを WSL2 上の Docker で再起動し、そのサービスが
    再び接続可能になるまで待機する。サービス名を 1 つも指定しなかった場合は、使い方
    （指定できるサービス名の一覧）を表示して終了する。

    準備完了の判定方法・WSL 実行ヘルパ・キープアライブ等は Start-Services_wsl2.ps1 と
    共通のものを使う（同フォルダの Start-Services_wsl2.ps1 を -AsLibrary でドットソース
    して再利用しているため、定義が二重管理にならない）。
    再起動の前にキープアライブを確認・起動するので、WSL2 の VM がアイドル停止していても
    そのまま実行できる。

    既定は docker compose restart（データは保持される）。restart しても復旧しない
    破損状態には -Recreate を使うと、匿名ボリュームごと破棄して作り直す
    （本 compose は永続ボリューム未使用のため作り直しは無害）。

.PARAMETER Service
    再起動するサービス名。スペース区切りで複数指定できる。all を指定すると全サービス。
    大文字小文字は区別しない。省略した場合は使い方を表示して終了する。

.PARAMETER Distro
    使用する WSL ディストリビューション名。省略時は既定のディストリビューションを使用する。

.PARAMETER Recreate
    restart ではなく、コンテナを匿名ボリュームごと削除してから作り直す。
    公式 mysql/mssql イメージは data を匿名ボリュームに持つため、破損データを
    確実に捨てたい場合はこちらを使う。

.PARAMETER NoWait
    再起動後の準備完了待ちを行わない（再起動の指示のみ）。

.PARAMETER NoPause
    完了時のキー入力待ち（pause 相当）を行わない。
    入力がリダイレクトされている非対話実行では、指定しなくても自動的に待たない。

.EXAMPLE
    .\Reboot-Services_wsl2.ps1
    指定できるサービス名と使い方を表示する。

.EXAMPLE
    .\Reboot-Services_wsl2.ps1 mysql
    mysql だけを再起動し、接続可能になるまで待つ。

.EXAMPLE
    .\Reboot-Services_wsl2.ps1 mysql redis
    mysql と redis を再起動する。

.EXAMPLE
    .\Reboot-Services_wsl2.ps1 mysql -Recreate
    mysql を匿名ボリュームごと作り直す（データ破損からの復旧用）。

.EXAMPLE
    .\Reboot-Services_wsl2.ps1 all -Distro Ubuntu-22.04
    指定ディストリビューション上の全サービスを再起動する。
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
    [string[]]$Service,

    [string]$Distro,

    [switch]$Recreate,

    [switch]$NoWait,

    [switch]$NoPause
)

# 設定テーブル（$ServicePorts / $ReadyChecks / $ReadyTimeouts / $NetworkName）と
# 関数（Write-Line / Wait-ForKey / Invoke-Wsl / Invoke-WslQuiet / Start-KeepAlive /
# Wait-DockerDaemon / Resolve-Targets / Ensure-Service / Test-WindowsPort など）を
# Start-Services_wsl2.ps1 から取り込む。-AsLibrary により本処理は走らない。
# $Distro は WSL 実行ヘルパ（$wslBaseArgs / $wslPath）の組み立てに必要なので必ず渡す。
# 注: ドットソースは相手の param 変数も呼び出し元スコープへ持ち込むため、$Service /
#     $NoWait / $NoPause は同じ値を明示的に渡して、自分の指定が上書きされないようにする。
$libArgs = @{ AsLibrary = $true; Service = $Service; NoWait = $NoWait; NoPause = $NoPause }
if ($PSBoundParameters.ContainsKey('Distro')) { $libArgs['Distro'] = $Distro }
. "$PSScriptRoot\Start-Services_wsl2.ps1" @libArgs

function Show-Usage {
    Write-Line ""
    Write-Line "使い方: .\Reboot-Services_wsl2.ps1 <サービス名> [<サービス名> ...] [-Distro <名前>] [-Recreate] [-NoWait] [-NoPause]" -Color Cyan
    Write-Line ""
    Write-Line "  再起動するサービスをコマンドラインで指定します。"
    Write-Line "  サービス名を指定しない場合は、このヘルプを表示して終了します。"
    Write-Line ""
    Show-ServiceList
    Write-Line ""
    Write-Line "オプション:" -Color Cyan
    Write-Line "  -Distro     使用する WSL ディストリビューション名（省略時は既定）。"
    Write-Line "  -Recreate   restart ではなく、匿名ボリュームごと削除して作り直す（破損復旧用）。"
    Write-Line "  -NoWait     再起動後の準備完了待ちを行わない。"
    Write-Line "  -NoPause    終了時のキー入力待ちを行わない。"
    Write-Line ""
    Write-Line "例:" -Color Cyan
    Write-Line "  .\Reboot-Services_wsl2.ps1 mysql"
    Write-Line "  .\Reboot-Services_wsl2.ps1 mysql redis"
    Write-Line "  .\Reboot-Services_wsl2.ps1 mysql -Recreate"
    Write-Line "  .\Reboot-Services_wsl2.ps1 all -Distro Ubuntu-22.04"
    Write-Line ""
    Write-Line "詳細は Get-Help .\Reboot-Services_wsl2.ps1 -Full で参照できます。" -Color DarkGray
}

# Resolve-Targets（サービス名の解決）は Start-Services_wsl2.ps1 から取り込んだものを使う。

# --- 引数の解釈（本処理前に済ませ、問題があればヘルプを出して終了）--------------
# 引数なしのほか、help / -Help でもヘルプを表示する（Start-Services_wsl2.ps1 と揃える）。
if (-not $Service -or @($Service).Count -eq 0 -or (Test-HelpRequested -Names $Service)) {
    Show-Usage
    Wait-ForKey
    exit 0
}

$targets = @(Resolve-Targets -Names $Service)

if ($script:UnknownNames.Count -gt 0) {
    Write-Line ("不明なサービス名です: {0}" -f ($script:UnknownNames -join ', ')) -Color Red
    Show-Usage
    Wait-ForKey
    exit 1
}

if ($targets.Count -eq 0) {
    Show-Usage
    Wait-ForKey
    exit 1
}

# ===========================================================================
try {
    Write-Line "対象: $scriptDir" -Color DarkGray
    Write-Line "WSL パス: $wslPath" -Color DarkGray
    Write-Line ("再起動するサービス: {0}" -f ($targets -join ', ')) -Color Cyan

    # VM がアイドル停止していると docker も localhost 転送も使えないため、先に起こす。
    Start-KeepAlive
    Wait-DockerDaemon

    # 作り直し・up を伴う場合に備え、common_link が無ければ作成する（冪等）。
    & wsl @wslBaseArgs docker network inspect $NetworkName > $null 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Line "ネットワーク '$NetworkName' を作成します..." -Color Cyan
        Invoke-Wsl @('docker', 'network', 'create', '--driver', 'bridge', $NetworkName)
        if ($script:LastWslExit -ne 0) { throw "ネットワーク '$NetworkName' の作成に失敗しました。" }
    }

    if ($Recreate) {
        Write-Line "コンテナを作り直します (docker compose rm -sfv → up -d)..." -Color Cyan
        Invoke-WslQuiet (@('docker', 'compose', 'rm', '-sfv') + $targets) | Out-Null
        Invoke-Wsl (@('docker', 'compose', 'up', '-d') + $targets)
        if ($script:LastWslExit -ne 0) { throw "docker compose up に失敗しました。" }
    }
    else {
        # docker compose restart は対象コンテナが未作成でも「何もせず成功」してしまう。
        # そのまま待つと準備完了待ちがタイムアウトするまで気付けないため、先に存在を
        # 確認し、未作成のものだけ up -d で作成する（-aq なので停止中も既存扱い＝
        # restart で起動できる）。
        $existing = @()
        $missing = @()
        foreach ($svc in $targets) {
            $id = (& wsl @wslBaseArgs --cd $wslPath docker compose ps -aq $svc 2>$null) -join ''
            if ([string]::IsNullOrWhiteSpace($id)) { $missing += $svc } else { $existing += $svc }
        }

        if ($existing.Count -gt 0) {
            Write-Line "コンテナを再起動します (docker compose restart)..." -Color Cyan
            Invoke-Wsl (@('docker', 'compose', 'restart') + $existing)
            if ($script:LastWslExit -ne 0) { throw "docker compose restart に失敗しました。" }
        }
        if ($missing.Count -gt 0) {
            Write-Line ("コンテナが未作成のため起動します (docker compose up -d): {0}" -f ($missing -join ', ')) -Color Yellow
            Invoke-Wsl (@('docker', 'compose', 'up', '-d') + $missing)
            if ($script:LastWslExit -ne 0) { throw "docker compose up に失敗しました。" }
        }
    }

    if (-not $NoWait) {
        Write-Line ""
        Write-Line "準備完了を待機します（応答しない場合は作り直します）:" -Color Cyan
        $failed = @()
        foreach ($svc in $targets) {
            $timeout = if ($ReadyTimeouts.ContainsKey($svc)) { $ReadyTimeouts[$svc] } else { $DefaultReadyTimeoutSec }
            if (-not (Ensure-Service -Service $svc -Check $ReadyChecks[$svc] -TimeoutSec $timeout)) {
                $failed += $svc
            }
        }

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
    Write-Line "再起動しました。稼働状況:" -Color Green
    Invoke-Wsl (@('docker', 'compose', 'ps') + $targets)
}
finally {
    Wait-ForKey
}
