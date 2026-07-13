# LocalServicesOnDocker

### 実行方法
このフォルダのコンテンツを実行するには、

当該リポジトリをクローンした後（Windows）、
```
>git clone https://github.com/NetDevInfraWGinOSSConsortium/LocalServicesOnDocker.git
```

このフォルダに移動し（WSL2）、
```
$ cd /mnt/.../LocalServicesOnDocker/
```

#### WSLから実行する
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

#### Start-Services.bat から実行する（Rancher Desktop 導入時）
Rancher Desktop を導入すると `docker` コマンドが Windows ネイティブで使えるため、
WSLからの実行（common_link 作成 → `docker compose up -d` / `down`）だけを実行する。

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

#### Start-Services.ps1から実行する
Windows の PowerShell から `Start-Services.ps1` を実行することで、WSL2 上の Docker を経由して起動・停止できる。  
（common_link ネットワークの作成、compose ファイルのあるフォルダへの移動は自動で行われる。）

リポジトリのフォルダに移動し（Windows / PowerShell）、
```
> cd ...\LocalServicesOnDocker\
```

以下のコマンドでコンテナを起動する。初回実行時の common_link ネットワーク作成も自動で行われる。
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

使用する WSL ディストリビューションを指定する場合は `-Distro` を付与する（省略時は既定のディストリビューション）。
`Stop-Services.ps1` も `-Distro` を受け取り、`Start-Services.ps1` に転送する。
```
> .\Start-Services.ps1 up -Distro Ubuntu-22.04
> .\Stop-Services.ps1 -Distro Ubuntu-22.04
```

ダブルクリック起動時にウィンドウが即閉じせず出力・エラーを読めるよう、処理の最後にキー入力待ち（`Start-Services.bat` の `pause` 相当）を行う。成功・失敗どちらでも待つ。キー入力待ちを行いたくない場合は `-NoPause` を付与する（`Stop-Services.ps1` からの呼び出しやパイプなど、入力がリダイレクトされている非対話実行では、指定しなくても自動的に待たない）。
```
> .\Start-Services.ps1 up -NoPause
```

PowerShell の実行ポリシーでブロックされる場合は、以下のように実行する。
```
> powershell -ExecutionPolicy Bypass -File .\Start-Services.ps1
```

##### Start-Services.ps1 の堅牢化について
WSL2 内の Docker を Windows から使う際に起きがちな次の 2 点を、スクリプト側で自動的に対処している。

- **① VM のアイドル停止によるデータ破損の防止**  
  WSL2 の VM はアイドルになると自動停止し、その際に DB(MySQL / SQL Server) の書き込みが
  中断されてデータが破損する（＝クラッシュループ）。`up` 時に Windows 側で常駐する
  `wsl.exe` プロセス（キープアライブ）を 1 つ起動して VM を起動したままに保ち、これを防ぐ。
  さらに各 DB が接続可能になるまで待機し、破損等で準備できないコンテナは自動で作り直す
  （本 compose は永続ボリューム未使用のため作り直しは無害）。
- **② Windows の localhost からコンテナへ到達できない問題の解消**  
  Windows↔WSL の localhost 転送は「Windows 側に生きた `wsl` セッションがある間」だけ
  維持される。上記キープアライブ（Windows 側常駐 `wsl.exe`）がこのセッションを保持し続けるため、
  Windows 上のアプリから `localhost:<port>` でコンテナに接続できるようになる。
  `up` の最後に各ポートへの到達確認結果が表示される。

キープアライブは `down` を実行すると自動的に解除される。  
（グローバル設定 `.wslconfig` は変更しない。すべて本スクリプト内で完結する。）

##### SQL Server の Northwind DB 自動作成
SQL Server の公式イメージは、他の DB のように初期化スクリプトを自動実行しないため、
`sqlserver/init/start-up.sh` を entrypoint から起動して Northwind DB を自動作成する。

- DDL は Microsoft 公式の
  [instnwnd.sql](https://github.com/microsoft/sql-server-samples/blob/master/samples/databases/northwind-pubs/instnwnd.sql)
  を `sqlserver/init/instnwnd.sql` として配置している。
- このスクリプトは DB を作成しない仕様のため、`start-up.sh` が先に `CREATE DATABASE Northwind`
  を行ってから `-d Northwind` で流し込む。
- SQL Server 起動後に自動実行され、既に Northwind があればスキップする（冪等）。
- `Start-Services.ps1` は、この Northwind DB が利用可能になるまで待ってから起動完了とする。

`docker compose up`（WSL から直接実行）でも同様に自動作成される。

#### bat と ps1 は、それぞれ別インスタンスを起動
`Start-Services.bat` と `Start-Services.ps1` は、それぞれ **別の Docker デーモン** 上でコンテナを起動する。

| | Start-Services.bat | Start-Services.ps1 |
|---|---|---|
| Docker エンジン | Rancher Desktop | WSL2 の既定ディストロ内の dockerd |
| 接続先 | `npipe:////./pipe/docker_engine` | `unix:///var/run/docker.sock`（ディストロ内） |

compose ファイルもプロジェクト名（`localservicesondocker`）もコンテナ名も同じだが、
デーモンが異なるため **中身は別々のコンテナ・別々のデータ** になる。運用上の注意は次のとおり。

- **データは共有されない。** 一方で書き込んだデータは他方からは見えない。
- **同時には起動できない。** 両者とも同じ Windows の localhost ポート
  （6379 / 27017 / 3306 / 5432 / 1433）を公開するため、後から起動した方がポート競合で失敗する。
  どちらか一方だけを使うこと。
- **停止は対応するツールで行う。** Rancher 側（bat 起動）は `Stop-Services.bat` /
  `Start-Services.bat down`、WSL 側（ps1 起動）は `Start-Services.ps1 down` で停止する。
  相互のコンテナは見えないため、`Stop-Services.bat` では ps1 のコンテナは停止しない（逆も同様）。

### テスト方法
テストを行う場合は、あらかじめ `Start-Services.bat`（Rancher Desktop）または
`Start-Services.ps1`（WSL2）でサービスを起動しておく（両者は排他。同時起動不可）。Windows上から、

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
