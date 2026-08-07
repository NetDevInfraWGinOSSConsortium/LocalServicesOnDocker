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
- 一覧はスクリプト側の定義（`Start-Services*.ps1` の `$ServicePorts`）から生成しているため、
  ヘルプには常に最新の一覧が表示される。

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
```
> .\Reboot-Services.ps1
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

#### スクリプトの使い分け
| スクリプト | Docker エンジン | サービス名の指定 | DB 初期化完了待ち | 主なオプション |
|---|---|---|---|---|
| `Start-Services.bat` / `Stop-Services.bat` | Rancher Desktop | できない（常に全部） | しない | — |
| `Start-Services.ps1` / `Stop-Services.ps1` | Rancher Desktop | できる（省略時は全部） | する（`-NoWait` で省略可） | `-NoWait` `-NoPause` |
| `Start-Services_wsl2.ps1` / `Stop-Services_wsl2.ps1` | WSL2 内の dockerd | できる（省略時は全部） | する | `-Distro` `-NoWait` `-NoPause` |
| `Reboot-Services.ps1` | Rancher Desktop | できる（省略時はヘルプ） | する（指定サービスのみ） | `-Recreate` `-NoWait` `-NoPause` |
| `Reboot-Services_wsl2.ps1` | WSL2 内の dockerd | できる（省略時はヘルプ） | する（指定サービスのみ） | `-Distro` `-Recreate` `-NoWait` `-NoPause` |

- 手早く起動したい・ダブルクリックで済ませたい → `Start-Services.bat`
- テスト前に DB が使える状態まで待ってから始めたい → `Start-Services.ps1`
- Rancher Desktop 未導入で WSL2 内の Docker を使う → `Start-Services_wsl2.ps1`
- 特定の DB だけ再起動したい・壊れた DB だけ入れ直したい → `Reboot-Services.ps1`（WSL2 なら `Reboot-Services_wsl2.ps1`）

> 注: Rancher Desktop版の `.bat` と `.ps1` は、**同一の Rancher エンジン・同一コンテナ**を扱うため、一方で起動して
> 他方で停止しても問題ない。一方 WSL2 版の `_wsl2.ps1` は WSL2 内の別デーモン上で動く**別インスタンス**であり、
> 公開ポート（6379 / 27017 / 3306 / 5432 / 1433 / 1521）が同じなので、Rancher Desktop版と同時に起動するとポート競合する。
> 用途に応じてどちらか一方だけを使うこと。

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

`Reboot-Services.ps1` / `Reboot-Services_wsl2.ps1` は、この判定テーブルと待機・自動復旧処理、
およびサービス名の解決処理を `Start-Services.ps1` / `Start-Services_wsl2.ps1` からドットソース
（内部用スイッチ `-AsLibrary`）で再利用しており、指定されたサービスに対して同じ判定を行う。
判定内容が二重管理にならないようにするため、接続情報・タイムアウト・サービス名の一覧を変更する場合は
`Start-Services*.ps1` 側だけを直せばよい。

### テスト方法
テストを行う場合は、あらかじめサービスを起動しておく（DB の初期化完了まで待ちたい場合は `Start-Services.ps1` を推奨）。

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
