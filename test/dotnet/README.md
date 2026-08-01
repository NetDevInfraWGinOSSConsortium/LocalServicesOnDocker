# dotnet（.NET 版テスト）

`test/nodejs2` の疎通テストを C# / .NET コンソールアプリに移植したもの。各 DB へ接続して簡単な操作を行う。

## 対応ライブラリ（NuGet）
| 対象 | ライブラリ |
| --- | --- |
| Redis | StackExchange.Redis |
| MongoDB | MongoDB.Driver |
| MySQL | MySqlConnector |
| PostgreSQL | Npgsql |
| SQL Server | Microsoft.Data.SqlClient |
| Oracle | Oracle.ManagedDataAccess.Core（ODP.NET Core・Oracle Client 不要） |

- 接続設定は `Config.cs` に集約（環境変数で上書き可能）。
- `Program.cs` が全テストを順に実行し、結果サマリを表示。失敗時は終了コード 1 で終了する。

## 前提
- **.NET SDK 10 以上**（`dotnet --version` で確認）。
- リポジトリ直下の `docker compose`（または `Start-Services.ps1`）でサービス群が起動していること。

## 使い方（Windows）
このフォルダに移動し、
```
> cd ...\LocalServicesOnDocker\test\dotnet
```

依存パッケージを復元する。
```
> install.bat
```
または
```
> dotnet restore
```

全テストを一括実行する。
```
> start.bat
```
または
```
> dotnet run
```

個別に実行する場合は、サービス名（の一部）を引数で渡す。
```
> dotnet run -- redis
> dotnet run -- mongo
> dotnet run -- mysql
> dotnet run -- postgres
> dotnet run -- sqlserver
> dotnet run -- oracle
```

接続先を変更する場合は環境変数で上書きできる（例）。
```
> set DB_HOST=192.168.0.10
> dotnet run
```

## 補足
- `dotnet` は実行ファイルなので、バッチ内で `call` を付けなくても末尾の `pause` は正しく動作する。
- ビルド成果物（`bin/` `obj/`）はリポジトリの `.gitignore` で除外済み。
