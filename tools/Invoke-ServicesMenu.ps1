<#
.SYNOPSIS
    Start / Stop / Reboot / Show-Services を対話形式で実行するメニュー。

.DESCRIPTION
    次の流れで、同フォルダの各 *.ps1 を組み立てて実行する。
      1. コマンド選択   : 実行エンジン（Windows Docker / WSL2）と、コマンド
                          （Start / Stop / Reboot / Show）を選ぶ。
      2. オプション選択 : 対象サービスと、コマンドごとのオプションを選ぶ。
      3. 確認           : 実行するコマンドラインを表示する。
      4. GO / NOGO      : GO と入力したときだけ実行する。それ以外は実行しない。
    実行後はコマンド選択へ戻る。途中で q を入力すると終了する（b で 1 つ前へ戻る）。

.EXAMPLE
    .\Invoke-ServicesMenu.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# 指定できるサービス名（Services.Common.ps1 と同じ定義を使う）。
. (Join-Path $PSScriptRoot 'Services.Common.ps1')
$AllServices = @($ServicePorts.Keys)

# --- 入出力ヘルパ ---------------------------------------------------------------

function Say([string]$Text = '', [string]$Color = 'Gray') {
    Write-Host $Text -ForegroundColor $Color
}

function Read-Input([string]$Prompt) {
    $v = Read-Host $Prompt
    if ($null -eq $v) { return '' }
    $v = $v.Trim()
    if ($v -ieq 'q') { throw [System.OperationCanceledException]::new('quit') }
    return $v
}

# 1 つ選ぶ。戻り値: 選んだ項目の位置（0 始まり）、b なら -1（戻る）。
function Select-One([string]$Title, [object[]]$Items, [int]$Default = 1) {
    while ($true) {
        Say ''
        Say $Title -Color Cyan
        for ($i = 0; $i -lt $Items.Count; $i++) {
            Say ("  {0}) {1}" -f ($i + 1), $Items[$i].Label)
        }
        Say '  (b: 戻る / q: 終了)' -Color DarkGray
        $s = Read-Input ("番号 [{0}]" -f $Default)
        if ($s -ieq 'b') { return -1 }
        if ($s -eq '') { $s = "$Default" }
        $n = 0
        if ([int]::TryParse($s, [ref]$n) -and $n -ge 1 -and $n -le $Items.Count) {
            return ($n - 1)
        }
        Say '番号が正しくありません。' -Color Yellow
    }
}

# Yes/No。既定値つき。
function Read-YesNo([string]$Prompt, [bool]$Default = $false) {
    $hint = if ($Default) { 'Y/n' } else { 'y/N' }
    while ($true) {
        $s = Read-Input ("{0} [{1}]" -f $Prompt, $hint)
        if ($s -eq '') { return $Default }
        if ($s -match '^(y|yes)$') { return $true }
        if ($s -match '^(n|no)$') { return $false }
        Say 'y か n で答えてください。' -Color Yellow
    }
}

# サービス選択。空 = 全サービス（Reboot は必須）。戻り値: 配列（空配列は全サービス）。
function Read-Services([bool]$Required) {
    while ($true) {
        Say ''
        Say ("対象サービス: {0}" -f ($AllServices -join ' ')) -Color Cyan
        $hint = if ($Required) { '必須' } else { '空 Enter = 全サービス' }
        Say ("  スペース区切りで名前または番号を入力（{0} / all = 全サービス / b: 戻る）" -f $hint) -Color DarkGray
        for ($i = 0; $i -lt $AllServices.Count; $i++) {
            Say ("    {0}: {1}" -f ($i + 1), $AllServices[$i]) -Color DarkGray
        }
        $s = Read-Input 'サービス'
        if ($s -ieq 'b') { return $null }
        if ($s -eq '') {
            if ($Required) { Say 'このコマンドはサービスの指定が必須です。' -Color Yellow; continue }
            return , @()
        }
        if ($s -ieq 'all') { return , @($AllServices) }

        $picked = New-Object System.Collections.Generic.List[string]
        $bad = @()
        foreach ($tok in ($s -split '[\s,]+' | Where-Object { $_ })) {
            $n = 0
            if ([int]::TryParse($tok, [ref]$n) -and $n -ge 1 -and $n -le $AllServices.Count) {
                $name = $AllServices[$n - 1]
            }
            elseif ($AllServices -contains $tok.ToLower()) {
                $name = $tok.ToLower()
            }
            else { $bad += $tok; continue }
            if (-not $picked.Contains($name)) { $picked.Add($name) }
        }
        if ($bad.Count -gt 0) {
            Say ("不明なサービス: {0}" -f ($bad -join ', ')) -Color Yellow
            continue
        }
        return , @($picked)
    }
}

function Read-BufferPoolMB {
    while ($true) {
        $s = Read-Input 'DB バッファプール MB（128 以上 / 空 Enter = 指定しない）'
        if ($s -eq '') { return 0 }
        $n = 0
        if ([int]::TryParse($s, [ref]$n) -and $n -ge 128) { return $n }
        Say '128 以上の整数を入力してください。' -Color Yellow
    }
}

# --- 各コマンドのオプション選択 ----------------------------------------------------
# 戻り値: @{ Positional = @(...); Named = @{...}; Display = '...' }。戻る場合は $null。

function Get-CommandPlan([string]$Command, [bool]$Wsl2) {
    $plan = @{ Positional = @(); Named = @{} }

    # Reboot 以外は引数なし＝全サービス。Reboot は指定必須。
    $services = Read-Services -Required:($Command -eq 'Reboot')
    if ($null -eq $services) { return $null }

    Say ''
    Say 'オプション' -Color Cyan

    switch ($Command) {
        'Start' {
            $plan.Positional += 'up'
            if (Read-YesNo '  準備完了を待たない (-NoWait)' $false) { $plan.Named['NoWait'] = $true }
            $mb = Read-BufferPoolMB
            if ($mb -gt 0) { $plan.Named['BufferPoolMB'] = $mb }
        }
        'Stop' {
            Say '  （Stop のオプションはありません。コンテナを停止して削除します）' -Color DarkGray
        }
        'Reboot' {
            if (Read-YesNo '  コンテナを作り直す (-Recreate / データ初期化の可能性あり)' $false) { $plan.Named['Recreate'] = $true }
            if (Read-YesNo '  準備完了を待たない (-NoWait)' $false) { $plan.Named['NoWait'] = $true }
            $mb = Read-BufferPoolMB
            if ($mb -gt 0) { $plan.Named['BufferPoolMB'] = $mb }
        }
        'Show' {
            if (Read-YesNo '  ポート確認のみで準備完了判定を省く (-Quick)' $false) { $plan.Named['Quick'] = $true }
        }
    }

    if ($Wsl2) {
        $d = Read-Input '  WSL ディストリビューション名 (-Distro / 空 Enter = 既定)'
        if ($d -ne '') { $plan.Named['Distro'] = $d }
    }

    # 対話実行なので、スクリプト側の「キー入力待ち」は付けない。
    $plan.Named['NoPause'] = $true

    $plan.Positional += $services
    return $plan
}

function Format-CommandLine([string]$ScriptName, $Plan) {
    $parts = @(".\tools\$ScriptName")
    foreach ($p in $Plan.Positional) { $parts += $p }
    foreach ($k in ($Plan.Named.Keys | Sort-Object)) {
        $v = $Plan.Named[$k]
        if ($v -is [bool] -and $v) { $parts += "-$k" }
        else { $parts += "-$k"; $parts += "$v" }
    }
    return ($parts -join ' ')
}

# --- メインループ ---------------------------------------------------------------

$commands = @(
    @{ Label = 'Start  : サービスを起動する (docker compose up -d)';      Value = 'Start' },
    @{ Label = 'Stop   : サービスを停止してコンテナを削除する (down)';    Value = 'Stop' },
    @{ Label = 'Reboot : サービスを再起動 / 作り直す';                    Value = 'Reboot' },
    @{ Label = 'Show   : サービスの状態を表示する（読み取り専用）';       Value = 'Show' }
)
$engines = @(
    @{ Label = 'Windows 上の Docker';  Value = $false },
    @{ Label = 'WSL2 内の Docker (*_wsl2.ps1)'; Value = $true }
)

Say '==== Services 対話メニュー ====' -Color Green
Say '流れ: コマンド選択 → オプション選択 → 確認 → GO / NOGO' -Color DarkGray

try {
    while ($true) {
        # 1. コマンド選択
        $idx = Select-One '[1/4] 実行エンジンを選んでください' $engines 1
        if ($idx -lt 0) { Say '先頭のため戻れません。' -Color Yellow; continue }
        $wsl2 = [bool]$engines[$idx].Value

        $idx = Select-One '[1/4] コマンドを選んでください' $commands 4
        if ($idx -lt 0) { continue }
        $cmd = [string]$commands[$idx].Value

        # 2. オプション選択
        Say ''
        Say '[2/4] 対象サービスとオプションを選んでください' -Color Cyan
        $plan = Get-CommandPlan $cmd $wsl2
        if ($null -eq $plan) { continue }

        $suffix = if ($wsl2) { '_wsl2' } else { '' }
        $scriptName = "{0}-Services{1}.ps1" -f $cmd, $suffix
        $scriptPath = Join-Path $PSScriptRoot $scriptName

        # 3. 確認
        Say ''
        Say '[3/4] 確認' -Color Cyan
        Say ("  エンジン : {0}" -f $(if ($wsl2) { 'WSL2' } else { 'Windows Docker' }))
        Say ("  コマンド : {0}" -f $cmd)
        $svcText = if (@($plan.Positional | Where-Object { $_ -in $AllServices }).Count -gt 0) {
            ($plan.Positional | Where-Object { $_ -in $AllServices }) -join ' '
        } else { '（全サービス）' }
        Say ("  サービス : {0}" -f $svcText)
        Say ("  実行内容 : {0}" -f (Format-CommandLine $scriptName $plan)) -Color White
        if ($cmd -eq 'Stop' -or ($cmd -eq 'Reboot' -and $plan.Named['Recreate'])) {
            Say '  ※ コンテナを削除します。実行前に内容をよく確認してください。' -Color Yellow
        }

        # 4. GO / NOGO
        Say ''
        Say '[4/4] 実行しますか？  GO と入力すると実行 / それ以外は NOGO（実行せずメニューへ戻る）' -Color Cyan
        $answer = Read-Input 'GO / NOGO'
        if ($answer -cne 'GO') {
            Say 'NOGO: 実行しませんでした。' -Color Yellow
            continue
        }

        Say ''
        Say '--- 実行開始 ---' -Color Green
        try {
            $posArgs = @($plan.Positional)
            $namedArgs = $plan.Named
            & $scriptPath @posArgs @namedArgs
            $code = if ($null -ne $LASTEXITCODE) { $LASTEXITCODE } else { 0 }
            Say ("--- 実行終了 (終了コード: {0}) ---" -f $code) -Color $(if ($code -eq 0) { 'Green' } else { 'Red' })
        }
        catch {
            Say ("--- 実行エラー: {0}" -f $_.Exception.Message) -Color Red
        }

        Say ''
        if (-not (Read-YesNo '続けて別のコマンドを実行しますか' $true)) { break }
    }
}
catch [System.OperationCanceledException] {
    # q で終了
}

Say ''
Say '終了します。' -Color DarkGray
