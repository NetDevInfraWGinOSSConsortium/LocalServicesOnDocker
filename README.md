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
基本的な使い方は `Start-Services.ps1` と同じ（`up` / `down` / `ps` / `logs`、`-NoWait` / `-NoPause`）で、
加えて WSL ディストリビューションを `-Distro` で指定できる。
```
> .\Start-Services_wsl2.ps1
> .\Start-Services_wsl2.ps1 up -Distro Ubuntu-22.04
> .\Stop-Services_wsl2.ps1
```

WSL2 版は、WSL2 特有の次の問題への対策をスクリプト側で行っている。

- **VM のアイドル停止によるデータ破損の防止**  
  WSL2 の VM はアイドルで自動停止し、その際に DB(MySQL / SQL Server) の書き込みが中断されて
  データが破損する（＝クラッシュループ）。`up` 時に Windows 側で常駐する `wsl.exe` プロセス
  （キープアライブ）を起動して VM を起動したままに保ち、これを防ぐ。`down` で自動解除される。
- **localhost 到達の維持**  
  Windows↔WSL の localhost 転送は「Windows 側に生きた `wsl` セッションがある間」だけ維持される。
  上記キープアライブがこのセッションを保持するため、Windows から `localhost:<port>` で接続できる。

#### スクリプトの使い分け
| スクリプト | Docker エンジン | DB 初期化完了待ち | 主なオプション |
|---|---|---|---|
| `Start-Services.bat` / `Stop-Services.bat` | Rancher Desktop | しない | — |
| `Start-Services.ps1` / `Stop-Services.ps1` | Rancher Desktop | する（`-NoWait` で省略可） | `-NoWait` `-NoPause` |
| `Start-Services_wsl2.ps1` / `Stop-Services_wsl2.ps1` | WSL2 内の dockerd | する | `-Distro` `-NoWait` `-NoPause` |

- 手早く起動したい・ダブルクリックで済ませたい → `Start-Services.bat`
- テスト前に DB が使える状態まで待ってから始めたい → `Start-Services.ps1`
- Rancher Desktop 未導入で WSL2 内の Docker を使う → `Start-Services_wsl2.ps1`

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
