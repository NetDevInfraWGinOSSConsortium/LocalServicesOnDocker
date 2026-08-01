# nodejs2（アップグレード版テスト）

`test/nodejs` の疎通テストを、最新のライブラリと async/await ベースに書き換えたもの。

## 旧版（nodejs）からの主な変更点
| 対象 | 旧版 | 新版（nodejs2） |
| --- | --- | --- |
| Redis | ioredis v4 | ioredis v5 / async-await |
| MongoDB | mongodb v3（コールバック・非推奨オプション） | mongodb v6 / async-await |
| MySQL | mysql v2（保守終了） | mysql2 v3 / Promise API |
| Postgres | pg v8（コールバック） | pg v8 / async-await |
| SQL Server | tedious v8（低レベル） | mssql v11 / async-await |
| Oracle | （なし） | node-oracledb v7 / Thin モード（Oracle Client 不要） |

- 接続設定を `config.js` に集約（環境変数で上書き可能）。
- 一括実行用の `test-all.js` を追加。結果サマリを表示し、失敗時は終了コード 1 で終了。

## 前提
- Node.js 18 以上。
- リポジトリ直下の `docker compose`（または `Start-Services.ps1`）でサービス群が起動していること。

## 使い方（Windows）
このフォルダに移動し、
```
> cd ...\LocalServicesOnDocker\test\nodejs2
```

依存関係をインストールする。
```
> install.bat
```
または
```
> npm install
```

全テストを一括実行する。
```
> start.bat
```
または
```
> npm test
```

個別に実行する場合。
```
> npm run test:redis
> npm run test:mongo
> npm run test:mysql
> npm run test:postgres
> npm run test:sqlserver
> npm run test:oracle
```

接続先を変更する場合は環境変数で上書きできる（例）。
```
> set DB_HOST=192.168.0.10
> npm test
```
