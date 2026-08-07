# 回帰テストケース

`Start-Services*.ps1` / `Stop-Services*.ps1` / `Reboot-Services*.ps1` / `*.bat` と、
`test/` 配下のクライアントを対象とした回帰テストの一覧。
スクリプトを変更したら、変更箇所に対応するグループを実行する。

全ケースを通すと **およそ 25〜35 分**（Oracle の初回起動と 150 秒タイムアウト待ちが大半）。
時間がないときは A / B / F を通せば、引数解釈と主要経路の回帰は押さえられる。

## 前提と実行の作法

- Rancher Desktop（または WSL2 内の dockerd）が起動していること。
- **Windows PowerShell 5.1 で実行する**（`powershell -NoProfile -File ...`）。
  スクリプトは BOM 付き UTF-8 前提で、BOM が落ちると 5.1 だけが構文エラーになる。
  `pwsh`（7.x）だけで確認すると、この退行を見逃す。
- 非対話で流すため `-NoPause` を付ける。`.bat` は `pause` を含むので
  `cmd /c "... < NUL"` の形で標準入力を空にする。
- 状態を壊すケースがあるので、**実行後は環境を戻す**（末尾の「後片付け」参照）。

## A. 引数解釈（コンテナ状態を変えない）

事前状態: 問わない。実行後もコンテナ数が変わらないことを毎回確認する。

| # | コマンド | 期待 |
|---|---|---|
| A01 | `Start-Services.ps1 help -NoPause` | exit 0・使い方表示・**コンテナ数が変わらない** |
| A02 | `Start-Services.ps1 bogus -NoPause` | exit 1・`不明なアクション名／サービス名です: bogus`・**何も起動しない** |
| A03 | `Start-Services.ps1 mysql down -NoPause`（順序取り違え） | exit 1・`不明な…: down`・**コンテナを作らない** |
| A04 | `Start-Services.ps1 "" -NoWait -NoPause` | exit 0・**引数なしと同じ全サービス up**（無言の no-op にならない） |
| A05 | `Start-Services.ps1 " " -NoWait -NoPause` | A04 と同じ |
| A06 | `help` / `--help` / `/?` / `?` / `-Help` の 5 形態 | すべて exit 0・**出力行数が一致**（実測 28 行） |
| A07 | `Reboot-Services.ps1 -NoPause`（引数なし） | exit 0・ヘルプ |
| A08 | `Reboot-Services.ps1 bogus -NoPause` | exit 1 |
| A09 | `Stop-Services.ps1 bogus` | exit 1・**既存コンテナを巻き込まない** |

## B. 起動・停止・再起動（Rancher Desktop）

| # | 事前 | コマンド | 期待 |
|---|---|---|---|
| B01 | コンテナ 0 | `Start-Services.ps1 redis mysql -NoPause` | exit 0・**作成されるのは redis と mysql だけ**・両方が準備完了＋到達 OK（実測 23 秒） |
| B02 | B01 の後 | `Start-Services.ps1 ps redis` | redis の 1 行だけ表示 |
| B03 | B01 の後 | `Stop-Services.ps1 mysql -NoPause` | mysql のみ削除・**redis は残る** |
| B04 | 任意 | `Start-Services.ps1 -NoPause`（引数なし） | exit 0・6 サービスすべて準備完了＋到達 OK（実測 110〜165 秒） |
| B05 | 全稼働 | `Reboot-Services.ps1 mysql -NoPause` | exit 0・**コンテナ ID が変わらない**（restart）・他 5 つのコンテナ集合も不変（実測 10 秒） |
| B06 | 全稼働 | `Reboot-Services.ps1 MySQL redis -NoPause` | 大小混在を正規化して 2 つ再起動 |
| B07 | 全稼働 | `Reboot-Services.ps1 postgres -Recreate -NoPause` | exit 0・**コンテナ ID が変わる** |
| B08 | `docker compose down postgres` 済 | `Reboot-Services.ps1 postgres -NoPause` | **10 秒未満**で `コンテナが未作成のため起動します` → 復旧。<br>150 秒のタイムアウト待ちが発生しないこと（**所要時間そのものがアサーション**） |
| B09 | 全稼働 | `Stop-Services.ps1 -NoPause` | 残存 0・`common_link` は external なので**残る** |
| B10 | 任意 | `Start-Services.ps1 mysql -NoWait -NoPause` | **2 秒程度**で復帰・準備待ち／到達確認を出力しない・コンテナは作成済み |
| B11 | 任意 | `Start-Services.ps1 all -NoWait -NoPause` | 6 個作成・`対象サービス:` を表示しない（compose にサービス名を渡さない全体扱い） |
| B12 | 任意 | `Reboot-Services.ps1 all -NoWait -NoPause` | 対象が 6 サービスすべて |
| B13 | 任意 | `Stop-Services.ps1 all -NoPause` | 残存 0 |
| B14 | 稼働中 | `Start-Services.ps1 mysql redis -NoPause` を 2 回連続 | 2 回目も exit 0・**コンテナ ID 集合が不変**（作り直さない） |
| B15 | 稼働中 | `Stop-Services.ps1 -NoPause` を 2 回連続 | 2 回目も exit 0 |
| B16 | `common_link` を削除 | `Start-Services.ps1 redis -NoPause` | `ネットワーク 'common_link' を作成します...` を通り、ネットワークが生成される（初回ユーザー経路） |
| B17 | 全稼働 | `Start-Services.ps1 logs redis`（`-f` なので数秒で打ち切る） | **redis の行だけ**が流れる |
| B18 | コンテナ 0 | `Start-Services.ps1 oracle -NoPause` | oracle だけ起動・準備完了（実測 56 秒。`$ReadyTimeouts` は 300 秒） |

## C. `.bat`（アサーションはサービス名まで見る）

件数だけの確認では別サービスが混ざっても通ってしまうため、**名前の完全一致**で判定する。
期待値: `mongo,mysql,oracle,postgres,redis,sqlserver`

| # | コマンド | 期待 |
|---|---|---|
| C01 | `Start-Services.bat` | exit 0・6 サービスの**名前が完全一致**・`Started.` を出力（準備完了待ちはしない） |
| C02 | `Start-Services.bat up`（稼働中に再実行） | exit 0・**コンテナ ID 集合が不変** |
| C03 | `Start-Services.bat ps` | 表示されるサービス名が完全一致 |
| C04 | `Start-Services.bat down` | exit 0・残存 0・`Stopped` |
| C05 | `Stop-Services.bat` | exit 0・残存 0（`Start-Services.bat down` への委譲） |
| C06 | `Start-Services.bat bogus` | exit 1・`Unknown action` |
| C07 | `oretoku-set.bat` | exit 0・`SERVICES` に書いたサービスだけが起動 |
| C08 | `SERVICES` を空にした `oretoku-set.bat` | exit 1・`SERVICES is empty. Edit this file...` |
| C09 | リポジトリ外から `oretoku-set.bat` をフルパス実行 | exit 0（`%~dp0` が効いている） |
| C10 | `.bat` 4 本の**非 ASCII バイト数** | すべて 0（`chcp 65001` で cmd.exe がパースに失敗するため） |

## D. WSL2 版

WSL2 内の dockerd が必要。**Rancher Desktop 側を停止してから**実行する（公開ポートが同じ）。

| # | コマンド | 期待 |
|---|---|---|
| D01 | `Start-Services_wsl2.ps1 help -NoPause` | 専用の使い方（`.\Start-Services_wsl2.ps1 ...`） |
| D02 | `Start-Services_wsl2.ps1 ps -NoPause` | `WSL パス: /mnt/d/...` へ変換されている・一覧が出る |
| D03 | `Start-Services_wsl2.ps1 bogus -NoPause` | exit 1 |
| D04 | `Reboot-Services_wsl2.ps1 redis -NoPause` | キープアライブ起動 → ID 不変で再起動 → `localhost:6379` 到達 OK |
| D05 | `Stop-Services_wsl2.ps1 redis -NoPause` | 対象のみ停止・**キープアライブは維持**（`pgrep -f '[2]147483647'` が 1） |
| D06 | `Start-Services_wsl2.ps1 redis -NoPause` | 復帰 |
| D07 | `Stop-Services_wsl2.ps1 -NoPause`（全停止） | 残存 0・**キープアライブ解除**（`pgrep` が 0）・**他プロジェクトのコンテナに影響なし** |
| D08 | `Start-Services_wsl2.ps1 redis -Distro <名前> -NoPause` | 指定ディストリビューションで起動 |
| D09 | `Reboot-Services_wsl2.ps1 redis -Recreate -Distro <名前> -NoPause` | コンテナ ID が変わる |

## E. クライアント疎通（`test/`）

事前状態: 6 サービスすべて準備完了。

| # | コマンド | 期待 |
|---|---|---|
| E01 | `test\python\start.bat` | exit 0・Summary が **6/6 OK**（実測 8 秒） |
| E02 | `test\nodejs2\start.bat` | exit 0・**6/6 OK**（実測 15 秒） |
| E03 | `test\dotnet\start.bat` | exit 0・**6/6 OK**（実測 14 秒） |

### E-T. 接続タイムアウト（3 秒）

サービス停止中の `localhost` は即 ECONNREFUSED になりタイムアウトの検証にならない。
**到達不能アドレス**（RFC5737 の `192.0.2.1`）を指定して、SYN が返らない状態の待ち時間を測る。

```
> set DB_HOST=192.0.2.1
> （各テストを実行して所要時間を測る）
```

| # | 対象 | 期待 |
|---|---|---|
| E-T1 | 3 言語 × 6 DB = 18 通り | すべて **約 3 秒**で失敗（プロセス起動込みで 3.1〜4.0 秒） |
| E-T2 | `DB_CONNECT_TIMEOUT=1` を設定 | すべて **約 1 秒**に変わる（設定値に追従している証拠） |

退行しやすい点（過去に踏んだもの）:

- **redis-py は既定で 10 回リトライ**するため、`socket_connect_timeout` だけでは 37 秒かかる。
  `retry=Retry(NoBackoff(), 0)` が消えていないこと。
- **StackExchange.Redis も複数回試す**ため `connectRetry=1` が必要。
- **MongoDB はサーバ選択タイムアウト（既定 30 秒）が支配的**。
  `connectTimeout` と `serverSelectionTimeout` の両方が設定されていること。

## F. 実行環境・共通部品の契約

| # | 内容 | 期待 |
|---|---|---|
| F01 | リポジトリ外のフォルダから `Start-Services.ps1` / `Reboot-Services.ps1` / `Stop-Services.bat` を実行 | すべて正常（`$PSScriptRoot` / `%~dp0`） |
| F02 | `powershell -ExecutionPolicy Bypass -File .\Start-Services.ps1 ps` | exit 0（README 記載の回避策） |
| F03 | `-NoPause` **なし**＋標準入力リダイレクト | **ハングせず終了**し、`続行するには…` を出力しない |
| F04 | `Services.Common.ps1` を直接実行 | exit 0・**出力 0 行**・副作用なし（ドットソース専用） |
| F05 | `Services.Common.ps1` を退避して 6 本を実行 | **6 本すべて** exit 1・`共通部品が見つかりません: <パス>` |
| F06 | `Get-Help` で 6 本の `-NoPause` を確認 | 6 本すべてに存在する |
| F07 | `.ps1` 7 本の構文解析と BOM | parse OK・**BOM がすべて付いている** |

## G. 準備完了判定そのものの判別力

「常に OK を返す空振り」になっていないことを確認する。
確認後は `-Recreate` で元に戻す（データが復元されることも併せて確認する）。

| # | 手順 | 期待 |
|---|---|---|
| G01 | oracle: `Shippers` を 1 行削除 → `ready.sql` を実行 | 改変前 exit 0 → **改変後 exit 1** |
| G02 | oracle: `Reboot-Services.ps1 oracle -Recreate -NoPause` | 準備完了・`Shippers` が **3 行に復元** |
| G03 | sqlserver: `__NorthwindReady` を DROP → 判定コマンドを実行 | 改変前 exit 0 → **改変後 exit 1** |
| G04 | sqlserver: `Reboot-Services.ps1 sqlserver -Recreate -NoPause` | 判定が exit 0 に戻る |

## H. 異常系・自動復旧・エンジン競合

| # | 手順 | 期待 |
|---|---|---|
| H01 | mysql の `/var/lib/mysql/ibdata1` を破壊 → `docker compose restart mysql`。<br>`RestartCount` が増えクラッシュループになったことを確認してから `Start-Services.ps1 mysql -NoPause` | `応答なし → 作り直し` → `再準備待ち... OK`（実測 185 秒）。<br>コンテナ ID が変わり、`init.sql` の **Shippers が 3 行に再初期化**される |
| H02 | Rancher 側で redis 稼働中に `Start-Services_wsl2.ps1 redis -NoPause` | exit 1・**ポート競合のヒント 3 行**を表示・`created` のまま残ったコンテナを**自動削除**・PowerShell の例外ダンプを**出さない**・**もう一方の稼働中コンテナは無傷** |

## ミューテーション確認（テスト自体の判別力を確かめる）

「全部パスした」だけでは、テストが弱いのか実装が正しいのか区別できない。
テストを大きく変えたときは、**わざと壊して落ちることを確認**する。
ファイルはバックアップしてから改変し、**必ず復元して `git status` で差分ゼロを確認**すること。

| 変異 | 落ちるべきケース | 実測 |
|---|---|---|
| `Reboot-Services.ps1` の **BOM を除去** | A07 | 5.1 で `Unexpected token` ×4・exit 1 |
| `Start-Services.ps1` の `$composeTargets` を**常に空**にする | B03 | `Stop-Services.ps1 mysql` で **6 個すべて削除**（redis が残らない） |
| `Reboot-Services.ps1` の**未作成チェックを削除**して素の `restart` にする | B08 | **7 秒 → 155 秒**・`未作成のため起動します` が消える |

## 未カバー（既知の穴）

- `logs` の対話動作（`-f` のため打ち切り確認のみ）。
- 対話実行時の `pause`（キー入力待ち）そのもの。
- `Ensure-Service` の**再作成後も失敗し続ける**経路（`NG` で終わるケース）。
- WSL2 版の全 6 サービス通し起動（`redis` 中心の確認にとどめている）。

## 後片付け

テスト後は次の状態に戻す。

```
> .\Stop-Services_wsl2.ps1 -NoPause      ← WSL2 側を使った場合
> .\Start-Services.ps1 -NoPause          ← Rancher Desktop 側を全サービス稼働へ
```

- WSL2 のキープアライブが残る場合がある（`up` が失敗したときなど）。
  `wsl -e bash -c "pkill -f '2147483647'"` で解除できる。
- ミューテーション確認をした場合は `git status` で `*.ps1` の差分がゼロであることを確認する。
