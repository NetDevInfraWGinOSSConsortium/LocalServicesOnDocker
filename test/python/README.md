# python（Python 版テスト）

`test/nodejs2` の疎通テストを Python に移植したもの。各 DB へ接続して簡単な操作を行う。
パッケージ管理と仮想環境には **[uv](https://docs.astral.sh/uv/)** を使用する。

## 対応ライブラリ
| 対象 | ライブラリ |
| --- | --- |
| Redis | redis-py |
| MongoDB | PyMongo |
| MySQL | PyMySQL |
| PostgreSQL | psycopg2 |
| SQL Server | pymssql（FreeTDS 同梱・ODBC ドライバ不要） |
| Oracle | python-oracledb（Thin モード・Oracle Client 不要） |

- 依存関係は `pyproject.toml` に定義（uv が `.venv` を作成してインストールする）。
- 接続設定は `config.py` に集約（環境変数で上書き可能）。
- 一括実行用の `test_all.py` を用意。結果サマリを表示し、失敗時は終了コード 1 で終了する。

## 前提
- **uv** がインストールされていること（`uv --version` で確認）。
  未導入の場合は PowerShell で以下を実行する。
  ```
  > powershell -ExecutionPolicy Bypass -c "irm https://astral.sh/uv/install.ps1 | iex"
  ```
  uv は Python 本体の検出・取得も行うため、対応する Python が無くても uv が自動で用意する
  （システムの `python` が Microsoft Store のスタブでも問題ない）。
- リポジトリ直下の `docker compose`（または `Start-Services.ps1`）でサービス群が起動していること。

## 使い方（Windows）
このフォルダに移動し、
```
> cd ...\LocalServicesOnDocker\test\python
```

仮想環境の作成と依存インストール（`.venv` が作られる）。
```
> install.bat
```
または
```
> uv sync
```

全テストを一括実行する。
```
> start.bat
```
または
```
> uv run python test_all.py
```

個別に実行する場合。
```
> uv run python test_redis.py
> uv run python test_mongo.py
> uv run python test_mysql.py
> uv run python test_postgres.py
> uv run python test_sqlserver.py
> uv run python test_oracle.py
```

接続先を変更する場合は環境変数で上書きできる（例）。
```
> set DB_HOST=192.168.0.10
> uv run python test_all.py
```

接続タイムアウトは既定 3 秒。サービスが起動していないときに長く待たされないようにしている。
変更する場合は `DB_CONNECT_TIMEOUT`（秒）で上書きする。
```
> set DB_CONNECT_TIMEOUT=10
> uv run python test_all.py
```

## 補足
- `uv run` は `.venv` 内の Python を使うため、PATH 上の `python`（Store スタブ等）に
  依存しない。`uv` は実行ファイルなので、バッチ内で `call` を付けなくても末尾の
  `pause` は正しく動作する。
- `uv.lock` は依存を固定するファイルなので、リポジトリにコミットするとよい。
  `.venv/` と `__pycache__/` は追跡不要（リポジトリの `.gitignore` で除外済み）。
