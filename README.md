# LocalServicesOnDocker

### 実行方法
このフォルダのコンテンツを実行するには、

当該リポジトリをクローンした後（Windows）、
```
>git clone https://github.com/NetDevInfraWGinOSSConsortium/LocalServicesOnDocker.git
```

#### WSL2から実行する
クローンしたフォルダに移動（WSL2）、

```
$ cd /mnt/.../LocalServicesOnDocker/
```

初回実行時は、以下のコマンドでnetworkにcommon_linkを作成する（WSL2）。
```
$docker network create --driver bridge common_link
```

以下のコマンドでコンテナを起動する（WSL2）。
```
$ docker compose up -d
```

以下のコマンドでコンテナが停止する（WSL2）。
```
$ docker compose down
```

#### Start-Services.bat から実行する
（Rancher Desktop 導入時）

Rancher Desktop を導入すると `docker` コマンドが Windows 上から使えるため、
common_link 作成 → `docker compose up -d` / `down`だけを実行する。

以下のコマンド（またはダブルクリック）でコンテナを起動する。引数なしは `up`。
初回の common_link ネットワーク作成も自動で行われる。
```
> .\Start-Services.bat
> .\Start-Services.bat up
```

以下のコマンドでコンテナが停止する。`Stop-Services.bat`（`down` のショートカット）でも同じ。
```
> .\Start-Services.bat down
> .\Stop-Services.bat
```

その他、稼働状況の確認やログ表示も可能。
```
> .\Start-Services.bat ps
> .\Start-Services.bat logs
```

補足:
- 前提として Rancher Desktop が起動していること。`docker` の実体は Rancher Desktop の bin
  （`C:\Program Files\Rancher Desktop\resources\resources\win32\bin`）がマシン PATH に登録済みで、
  新しく開いた端末では `docker` が利用できる。
- bat 内のメッセージ・コメントは ASCII（英語）のみとしている。日本語（マルチバイト）を含めると、
  コンソールが `chcp 65001`（UTF-8）のとき cmd.exe がバッチのパースに失敗するため。
- `Start-Services.ps1` のような DB 準備完了待ちは行わない（起動のみ）。SQL Server の Northwind など
  初期データのロードには起動後さらに数十秒かかるため、DB 接続テストは少し待ってから開始すると安定する。

#### 指定できるサービス名
（PowerShell 版スクリプト共通。`.bat` は対象外）

`Start-Services*.ps1` / `Stop-Services*.ps1` / `Reboot-Services*.ps1` は、対象とするサービスを
コマンドラインで指定できる。指定できるのは `docker-compose.yml` のサービス名と同じ次の 6 つ（＋ `all`）。

| サービス名 | DB | 公開ポート | イメージ |
|---|---|---|---|
| `redis` | Redis | 6379 | `redis` |
| `mongo` | MongoDB | 27017 | `mongo` |
| `mysql` | MySQL | 3306 | `mysql` |
| `postgres` | PostgreSQL | 5432 | `postgres` |
| `sqlserver` | SQL Server 2022 | 1433 | `mcr.microsoft.com/mssql/server:2022-latest` |
| `oracle` | Oracle Database 23ai Free | 1521 | `gvenzl/oracle-free:23-slim` |
| `all` | 上記すべて | — | — |

- スペース区切りで複数指定でき、大文字小文字は区別しない（`MySQL` でも可）。同じ名前を重複指定しても 1 回だけ処理される。
- **`Start-Services*.ps1` / `Stop-Services*.ps1` はサービス名を省略すると全サービスが対象**（従来どおりの動作）。
  `Reboot-Services*.ps1` だけは、省略時にヘルプを表示して終了する（再起動対象を明示させるため）。
- 存在しない名前を指定した場合は、その名前を表示したうえでヘルプを出し、何もせずに終了する
  （一部だけ正しい場合も実行しない）。
- 空文字列・空白のみの引数は**指定なしと同じ扱い**（`Start-Services.ps1 ""` は引数なしと同じく全サービス up）。
  バッチから未設定の変数（`%SERVICES%` など）がそのまま渡っても、無言で何もせず終わることはない。

##### ヘルプの表示

`Start-Services*.ps1` / `Stop-Services*.ps1` は引数なしが「全サービスが対象」なので、
ヘルプは `help`（または `-Help`）で明示的に要求する。`Reboot-Services*.ps1` は引数なしでも
ヘルプになるが、同じく `help` / `-Help` も受け付ける。
```
> .\Start-Services.ps1 help
> .\Start-Services.ps1 -Help
> .\Stop-Services.ps1 help
> .\Reboot-Services.ps1
```
`help` の代わりに `--help` / `/?` / `?` でも同じ。表示される一覧は
[共通部品](#スクリプトの構成共通部品)の `$ServicePorts` から生成しているため、常に最新の内容になる。
なお `Get-Help .\Start-Services.ps1 -Full` では、各パラメーターの詳しい説明を参照できる。

#### Start-Services.ps1 から実行する
（Rancher Desktop導入時 ＋ DB 初期化完了待ちをする場合）

`Start-Services.bat` と同じく Rancher Desktop の docker を用いるが、加えて
**各 DB が接続可能になるまで待機**してから起動完了とする。テスト前に DB が実際に使える状態を保証したい場合に使う。

リポジトリのフォルダに移動し（Windows / PowerShell）、
```
> cd ...\LocalServicesOnDocker\
```

以下のコマンド（またはダブルクリック）でコンテナを起動する。引数なしは `up`。
初回実行時の common_link ネットワーク作成も自動で行われる。
```
> .\Start-Services.ps1
> .\Start-Services.ps1 up
```

以下のコマンドでコンテナが停止する。`Stop-Services.ps1`（`Start-Services.ps1 down` のショートカット）でも同じ。
```
> .\Start-Services.ps1 down
> .\Stop-Services.ps1
```

その他、稼働状況の確認やログ表示も可能。
```
> .\Start-Services.ps1 ps
> .\Start-Services.ps1 logs
```

いずれのアクションも、後ろに[サービス名](#指定できるサービス名)を並べるとそのサービスだけが対象になる。
アクション（`up` / `down` / `ps` / `logs`）を省略した場合は `up` とみなすため、サービス名だけを渡してもよい。
```
> .\Start-Services.ps1 mysql redis      ← mysql と redis だけを起動（up 省略）
> .\Start-Services.ps1 up mysql redis   ← 同上
> .\Start-Services.ps1 down oracle      ← oracle だけを停止・削除
> .\Stop-Services.ps1 mysql redis       ← mysql と redis だけを停止
> .\Start-Services.ps1 logs mysql       ← mysql のログだけを表示
```

[ヘルプ](#ヘルプの表示)は `help` アクション（または `-Help`）で表示する。
```
> .\Start-Services.ps1 help
> .\Stop-Services.ps1 help
```

主なオプション:
- `-NoWait` : DB の初期化完了待ちを省略して起動のみ行う。
- `-NoPause`: 完了時のキー入力待ち（`Start-Services.bat` の `pause` 相当）を行わない。
  ダブルクリック起動でウィンドウが即閉じせず出力・エラーを読めるよう、既定では成功・失敗どちらでも待つ。
  ただし入力がリダイレクトされている非対話実行（`Stop-Services.ps1` からの呼び出し・パイプ・CI 等）では、
  指定しなくても自動的に待たない。
```
> .\Start-Services.ps1 up -NoWait
> .\Start-Services.ps1 up -NoPause
```

PowerShell の実行ポリシーでブロックされる場合は、以下のように実行する。
```
> powershell -ExecutionPolicy Bypass -File .\Start-Services.ps1
```

#### Start-Services_wsl2.ps1
（WSL2 内の Docker で実行 + DB 初期化完了待ちをする場合）

Rancher Desktop 導入以前の、**WSL2 内にインストールした Docker** を対象とする版。
基本的な使い方は `Start-Services.ps1` と同じ（`up` / `down` / `ps` / `logs`、[サービス名](#指定できるサービス名)の指定、
`-NoWait` / `-NoPause`）で、加えて WSL ディストリビューションを `-Distro` で指定できる。
```
> .\Start-Services_wsl2.ps1
> .\Start-Services_wsl2.ps1 up -Distro Ubuntu-22.04
> .\Start-Services_wsl2.ps1 mysql redis
> .\Stop-Services_wsl2.ps1
> .\Stop-Services_wsl2.ps1 mysql redis
```

ただしキープアライブの扱いだけは対象範囲で変わる。`down` でサービス名を指定した場合は、
**残るコンテナのためキープアライブを解除しない**（全サービスを停止したときだけ解除する）。

WSL2 版は、WSL2 特有の次の問題への対策をスクリプト側で行っている。

- **VM のアイドル停止によるデータ破損の防止**  
  WSL2 の VM はアイドルで自動停止し、その際に DB(MySQL / SQL Server) の書き込みが中断されて
  データが破損する（＝クラッシュループ）。`up` 時に Windows 側で常駐する `wsl.exe` プロセス
  （キープアライブ）を起動して VM を起動したままに保ち、これを防ぐ。`down` で自動解除される。
- **localhost 到達の維持**  
  Windows↔WSL の localhost 転送は「Windows 側に生きた `wsl` セッションがある間」だけ維持される。
  上記キープアライブがこのセッションを保持するため、Windows から `localhost:<port>` で接続できる。

#### Reboot-Services.ps1 から再起動する
（特定のサービスだけを再起動したい場合）

コマンドラインで指定したサービスだけを再起動し、そのサービスが再び接続可能になるまで待機する。
「MySQL だけ調子が悪い」「Oracle だけ入れ直したい」といった場合に、全体を停止せずに済む。
`Reboot-Services.ps1` が Rancher Desktop 版、`Reboot-Services_wsl2.ps1` が WSL2 版で、
それぞれ `Start-Services.ps1` / `Start-Services_wsl2.ps1` の設定・判定処理をそのまま再利用する。

**サービス名を指定しなかった場合は、ヘルプ（指定できるサービス名の一覧）を表示して終了する。**
`help` / `-Help` でも同じ（`Start-Services.ps1` 等と揃えてある）。
```
> .\Reboot-Services.ps1
> .\Reboot-Services.ps1 help
```

指定できるサービス名は [Start-Services.ps1 等と共通](#指定できるサービス名)。スペース区切りで複数指定でき、
大文字小文字は区別しない。`all` で全サービスを対象にする。
```
> .\Reboot-Services.ps1 mysql
> .\Reboot-Services.ps1 mysql redis
> .\Reboot-Services.ps1 all
```

主なオプション:
- `-Recreate`: `docker compose restart` ではなく、コンテナを**匿名ボリュームごと削除して作り直す**。
  公式 mysql / mssql イメージはデータを匿名ボリュームに持つため、restart では直らないデータ破損からの
  復旧に使う（本 compose は永続ボリューム未使用のため作り直しは無害）。
- `-NoWait` / `-NoPause`: `Start-Services.ps1` と同じ。
- `-Distro`: WSL2 版のみ。WSL ディストリビューションを指定する。
```
> .\Reboot-Services.ps1 mysql -Recreate
> .\Reboot-Services_wsl2.ps1 all -Distro Ubuntu-22.04
```

補足:
- 指定したサービスのコンテナがまだ作られていない場合は、`restart` ではなく `up -d` で作成する。
  `docker compose restart` は対象コンテナが存在しなくてもエラーにならず何もしないため、
  事前に存在を確認したうえで振り分けている。
- 再起動後は `Start-Services.ps1` と同じ準備完了待ち（応答しなければ 1 度だけ作り直し）と、
  `localhost:<port>` への到達確認を、指定したサービスについてのみ行う。
- WSL2 版は処理の前にキープアライブを起動するため、VM がアイドル停止していてもそのまま実行できる。

#### Show-Services.ps1 で状態だけ見る
（起動も停止もせず、今どうなっているかを確認したい場合）

コンテナの状態・DB の準備完了・`localhost` からの到達可否をまとめて表示する**読み取り専用**の
スクリプト。起動・停止・再起動・作り直しは一切行わない。
`Show-Services.ps1` が Rancher Desktop 版、`Show-Services_wsl2.ps1` が WSL2 版。

```
> .\Show-Services.ps1
> .\Show-Services.ps1 mysql redis   ← 指定したサービスだけ
> .\Show-Services.ps1 -Quick        ← 準備完了判定を省いて手早く
```

```
ネットワーク 'common_link': あり

  SERVICE    CONTAINER  READY  PORT   LOCALHOST
  -------    ---------  -----  ----   ---------
  redis      running    OK     6379   OK
  mysql      exited     NG     3306   NG
  postgres   -          NG     5432   NG

利用できないサービス: mysql, postgres
  起動するには: .\Start-Services.ps1 mysql postgres
  作り直すには: .\Reboot-Services.ps1 mysql postgres -Recreate
```

`Start-Services.ps1 ps`（＝`docker compose ps`）との違いは次のとおり。

- **READY** … `Start-Services.ps1` と同じ判定テーブル（`$ReadyChecks`）でコンテナ内へ疎通確認する。
  「コンテナは running だが DB はまだ初期化中」を見分けられる。ただし**待たないし作り直さない**
  （`Ensure-Service` ではなく 1 回だけの判定）。`-Quick` で省略できる。
- **CONTAINER** … `-` はコンテナが未作成であることを示す。
- **LOCALHOST** … Windows 側から公開ポートへ実際に接続できるかを確認する。
- 対象がすべて利用可能なら**終了コード 0**、そうでなければ 1。テストの前置きに使える。

補足:
- WSL2 版は、**VM が停止していても起こさない**。停止中はその旨だけを表示して終了する
  （状態を見るだけのつもりが VM を起動すると、前回のコンテナが復帰して Rancher Desktop 版と
  ポート競合しかねないため）。判定は既定（または `-Distro` で指定した）ディストリビューションの
  状態を見る。`rancher-desktop` は Rancher Desktop が常時動かしているので数に入れない。
- WSL2 版はキープアライブの有無も表示する。

#### oretoku-set.bat から決め打ちで起動する
（いつも同じサービスだけ使う場合）

毎回サービス名を打つ代わりに、起動するサービスを**ファイル内に書いておく**ためのショートカット。
`oretoku-set.bat` が Rancher Desktop 版、`oretoku-set_wsl2.bat` が WSL2 版で、
中身は `Start-Services*.ps1` を呼ぶだけ。ダブルクリック起動を想定している。

対象サービスは先頭付近の `SERVICES` を書き換えて選ぶ。使いたい組み合わせを行ごとに用意しておき、
**行単位でコメントアウト**して切り替えるのが安全。
```bat
rem Oracle takes the longest to boot, so it is left out by default.
set "SERVICES=sqlserver"
rem set "SERVICES=sqlserver oracle postgres mysql"
rem set "SERVICES=all"
```

`oretoku-set_wsl2.bat` では `DISTRO` も指定できる（空なら既定のディストリビューション）。
```bat
set "DISTRO=Ubuntu-22.04"
```

補足:
- **`::` は行頭でのみコメントになる。** 行の途中に書くと引数としてそのまま渡り、
  `::"oracle"` は `::oracle` というサービス名とみなされて**起動が丸ごと失敗する**。
  上記のように行単位でコメントアウトすること。
- `SERVICES` が空のまま実行した場合は、その旨を表示して終了する（意図しない全サービス起動を防ぐため）。
- `%~dp0` を使っているので、どのフォルダから実行しても動作する。
- 成功時はウィンドウを閉じ、失敗時のみ `pause` する。
- これらは他の `.bat` と同じく **ASCII のみ**で書く（`chcp 65001` のとき cmd.exe が
  マルチバイトのバッチをパースに失敗するため）。

#### スクリプトの使い分け
| スクリプト | Docker エンジン | サービス名の指定 | ヘルプ | DB 初期化完了待ち | 主なオプション |
|---|---|---|---|---|---|
| `Start-Services.bat` / `Stop-Services.bat` | Rancher Desktop | できない（常に全部） | — | しない | — |
| `Start-Services.ps1` / `Stop-Services.ps1` | Rancher Desktop | できる（省略時は全部） | `help` / `-Help` | する（`-NoWait` で省略可） | `-NoWait` `-NoPause` |
| `Start-Services_wsl2.ps1` / `Stop-Services_wsl2.ps1` | WSL2 内の dockerd | できる（省略時は全部） | `help` / `-Help` | する | `-Distro` `-NoWait` `-NoPause` |
| `Reboot-Services.ps1` | Rancher Desktop | できる（省略時はヘルプ） | 引数なし / `help` | する（指定サービスのみ） | `-Recreate` `-NoWait` `-NoPause` |
| `Reboot-Services_wsl2.ps1` | WSL2 内の dockerd | できる（省略時はヘルプ） | 引数なし / `help` | する（指定サービスのみ） | `-Distro` `-Recreate` `-NoWait` `-NoPause` |
| `Show-Services.ps1` / `Show-Services_wsl2.ps1` | 両対応（別ファイル） | できる（省略時は全部） | `help` / `-Help` | しない（1 回だけ判定） | `-Quick` `-Distro` `-NoPause` |
| `oretoku-set.bat` / `oretoku-set_wsl2.bat` | 上記 `Start-Services*.ps1` に委譲 | ファイル内の `SERVICES` で固定 | — | する | （ファイル内で編集） |

- 手早く起動したい・ダブルクリックで済ませたい → `Start-Services.bat`
- テスト前に DB が使える状態まで待ってから始めたい → `Start-Services.ps1`
- Rancher Desktop 未導入で WSL2 内の Docker を使う → `Start-Services_wsl2.ps1`
- 特定の DB だけ再起動したい・壊れた DB だけ入れ直したい → `Reboot-Services.ps1`（WSL2 なら `Reboot-Services_wsl2.ps1`）
- いつも同じサービスだけ使う・ダブルクリックで済ませたい → `oretoku-set.bat`

#### スクリプトの構成（共通部品）

PowerShell 版 6 本は、Docker エンジンに依存しない部分を `Services.Common.ps1` に集約している。
このファイルは**ドットソース専用**（定義のみ）で、直接実行しても何も起きない。

```
Services.Common.ps1                    ← 設定と共通関数（エンジン非依存）
  ├─ Start-Services.ps1                ← native docker 固有の処理
  │    ├─ Stop-Services.ps1            （down のショートカット）
  │    └─ Reboot-Services.ps1          （-AsLibrary でドットソース）
  └─ Start-Services_wsl2.ps1           ← WSL2 固有の処理
       ├─ Stop-Services_wsl2.ps1
       └─ Reboot-Services_wsl2.ps1
```

| 置き場所 | 内容 |
|---|---|
| `Services.Common.ps1` | `$NetworkName` `$ServicePorts` `$ReadyChecks` `$ReadyTimeouts` `$HelpTokens`／`Write-Line` `Wait-ForKey` `Wait-Service` `Ensure-Service` `Resolve-ComposeUpFailure` `Test-WindowsPort` `Show-ServiceList` `Test-HelpRequested` `Resolve-Targets` |
| `Start-Services.ps1` / `Start-Services_wsl2.ps1` | `$ErrorActionPreference`、`Invoke-ComposeQuiet`、`Invoke-ComposeCapture`、`Wait-DockerDaemon`、`Show-Usage`、WSL 実行ヘルパ、キープアライブ |

共通部品は compose コマンドの実行を次の 2 つに委ねている。これがエンジンの差し替え点で、
各 `Start-Services*.ps1` が自分のエンジン向けに定義する
（native は `docker compose ...`、WSL2 版は `wsl --cd <path> docker compose ...`）。

| フック | 用途 |
|---|---|
| `Invoke-ComposeQuiet` | 出力を捨てて終了コードだけ返す（`Wait-Service` / `Ensure-Service` の判定用） |
| `Invoke-ComposeCapture` | 標準出力を文字列で返す（`Resolve-ComposeUpFailure` の状態取得用） |

> 注: `Services.Common.ps1` は 6 本すべての前提なので、スクリプトだけを別フォルダへコピーしても動かない。
> 見つからない場合は「共通部品が見つかりません: ...」で停止する。

> 注: Rancher Desktop版の `.bat` と `.ps1` は、**同一の Rancher エンジン・同一コンテナ**を扱うため、一方で起動して
> 他方で停止しても問題ない。一方 WSL2 版の `_wsl2.ps1` は WSL2 内の別デーモン上で動く**別インスタンス**であり、
> 公開ポート（6379 / 27017 / 3306 / 5432 / 1433 / 1521）が同じなので、Rancher Desktop版と同時に起動するとポート競合する。
> 用途に応じてどちらか一方だけを使うこと。

同時に起動しようとした場合、PowerShell 版は `up` の失敗を検出して次のように案内し、
起動できずに `created` のまま残ったコンテナを自動で片付ける（もう一方の稼働中コンテナには手を触れない）。

```
ヒント: 次のポートは既に使用されています: redis(6379)
        Rancher Desktop 版と WSL2 版は同じ公開ポートを使うため、同時には起動できません。
        もう一方を停止してから再実行してください（Stop-Services.ps1 / Stop-Services_wsl2.ps1）。
起動できなかったコンテナを片付けます: redis
```

判定は Docker のエラー文言ではなく**公開ポートへの実接続**（`Test-WindowsPort`）で行うため、
Docker のバージョンやメッセージの変更に影響されない。

### 重複する仕様

#### SQL Server の Northwind DB 自動作成
（SQL Serverコンテナ自体に実装されているため、`docker compose up` 直接実行時も自動作成される）

SQL Server の公式イメージは、他の DB のように初期化スクリプトを自動実行しないため、
`sqlserver/init/start-up.sh` を entrypoint から起動して Northwind DB を自動作成する。

- DDL は Microsoft 公式のスクリプトを `sqlserver/init/instnwnd.sql` として配置。
  https://github.com/microsoft/sql-server-samples/blob/master/samples/databases/northwind-pubs/instnwnd.sql
- このスクリプトは DB を作成しない仕様のため、`start-up.sh` が先に
  `CREATE DATABASE Northwind` を行ってから `-d Northwind` で流し込む。
- SQL Server 起動後に自動実行され、既に Northwind があればスキップする（冪等）。
- PowerShell版は、この Northwind DB が利用可能になるまで待ってから起動完了とする。

#### Oracle の SCOTT スキーマと XE サービスの自動作成
（Oracleコンテナ自体に実装されているため、`docker compose up` 直接実行時も自動作成される）

Oracle Database 23ai Free（`gvenzl/oracle-free:23-slim`）は、DB 作成済みのイメージに
初期化スクリプトの仕組みが用意されている。本リポジトリでは次の 2 点を自動化している。

- **SCOTT/tiger ユーザ**: compose の `APP_USER` / `APP_USER_PASSWORD` により、
  既定の PDB（`FREEPDB1`）に作成される。
- **Shippers 表と別名サービス XE**: `oracle/init/01_setup.sql` が行う。
  このスクリプトは `/container-entrypoint-startdb.d` に配置しており、**起動の度に**
  `sqlplus / as sysdba` で実行されるため、すべて冪等（既にあれば何もしない）に書いている。
  - 23ai Free の既定のサービス名は `FREEPDB1` だが、接続文字列 `Data Source=localhost/XE`
    を使えるよう、`DBMS_SERVICE` で `FREEPDB1` に別名サービス `XE` を追加する。
  - Shippers 表（他 DB と同じ 3 行）を作成した **後** に `XE` を作るため、
    「`XE` 経由で SCOTT に接続できた＝データ準備完了」と判定できる。
    PowerShell版はこれを利用して準備完了を待つ（`oracle/ready/ready.sql`）。

#### DB 初期化完了待ち
（PowerShell版に追加されている実装）

`up` 時、各 DB が実際に接続可能になるまで待機してから起動完了とする。
判定はコンテナ内で `docker compose exec` 経由の疎通確認で行う。

- redis: `redis-cli ping` / mongo: `mongosh --eval 1` / mysql: `mysqladmin ping` /
  postgres: `pg_isready` / **sqlserver: Northwind ロード完了センチネル表 `__NorthwindReady` の存在** /
  **oracle: `sqlplus -L SCOTT/tiger@localhost/XE` で Shippers が 3 行あること**
- 一定時間（各サービス最大約 150 秒。初回起動の長い oracle のみ 300 秒）内に準備できないコンテナは、匿名ボリュームごと削除して
  1 度だけ作り直す（本 compose は永続ボリューム未使用のため作り直しは無害）。破損データによる
  クラッシュループを自動復旧する。
- `up` の最後に、Windows の `localhost:<port>` への到達確認結果を表示する。

初期化完了待ちが不要なら `-NoWait` を付与する（起動のみ）。

サービス名を指定した場合は、**指定したサービスについてのみ**この待機と到達確認を行う。

この判定テーブル（`$ReadyChecks`）と待機・自動復旧処理（`Wait-Service` / `Ensure-Service`）は
[`Services.Common.ps1`](#スクリプトの構成共通部品) にあり、6 本のスクリプトすべてが同じものを使う。
**接続情報・タイムアウト・サービス名の一覧を変更する場合は `Services.Common.ps1` だけを直せばよい。**

### テスト方法
テストを行う場合は、あらかじめサービスを起動しておく（DB の初期化完了まで待ちたい場合は `Start-Services.ps1` を推奨）。

起動スクリプト側（`*.ps1` / `*.bat`）を変更したときの回帰テストケースは
[TESTCASES.md](TESTCASES.md) にまとめてある。

#### dotnet
ConsoleApp1.sln プロジェクトを実行する。

#### nodejs
以下のtestフォルダに移動し、
```
>cd ...\LocalServicesOnDocker\test\nodejs
```

以下のbatファイルを実行する。
```
>install.bat
>start.bat
```

#### python
以下のtestフォルダに移動し、
```
>cd ...\LocalServicesOnDocker\test\python
```

以下のbatファイルを実行する。
```
>install.bat
>start.bat
```

### 接続文字列
#### .NETの接続文字列
.NETの接続文字列に関しては、以下の通り。

- RDB
  - "ConnectionString_SQL": "Data Source=localhost;Initial Catalog=Northwind;User ID=sa;Password=seigi@123;",
  - "ConnectionString_MCN": "Server=localhost;Database=test;User Id=root;Password=seigi@123",
  - "ConnectionString_NPS": "HOST=localhost;DATABASE=postgres;USER ID=postgres;PASSWORD=seigi@123;"
  - "ConnectionString_ODP": "User Id=SCOTT;Password=tiger;Data Source=localhost/XE;"
- NoSQL
  - redis : localhost
  - mongodb : mongodb://seigi:seigi%40123@localhost:27017

### コンテナからの接続
common_linkを設定することでサービス名で接続可能。

### 参考情報
- OSSコンソーシアム
  - [サービス類だけ、Docker Compose化するプロジェクトが出来上がった。](https://www.osscons.jp/jor9mt8li-537/)
  - [プログラム・サービス一式をDocker Compose化した。](https://www.osscons.jp/jo99tfumm-537/)
 
- Wiki
  - [部会メモ > 6/3 セルフZoom部会 - Open 棟梁 Wiki](https://opentouryo.osscons.jp/index.php?%E9%83%A8%E4%BC%9A%E3%83%A1%E3%83%A2#qc778622)
  - [Docker for Windowsのネットワーク設定 - マイクロソフト系技術情報 Wiki](https://techinfoofmicrosofttech.osscons.jp/index.php?Docker%20for%20Windows%E3%81%AE%E3%83%8D%E3%83%83%E3%83%88%E3%83%AF%E3%83%BC%E3%82%AF%E8%A8%AD%E5%AE%9A)
