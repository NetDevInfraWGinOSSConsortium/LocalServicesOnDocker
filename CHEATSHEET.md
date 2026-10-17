# CHEATSHEET（メモリを節約する運用）

DB コンテナを全部まとめて起動すると、Docker の VM がメモリを使い切って Windows ごと固まることがある。
**使うサービスだけを起動し、使い終わったら止める**のが基本。以下は Rancher Desktop 版
（`*.ps1`）のコマンドで、WSL2 内の Docker を使う場合はスクリプト名の末尾が `_wsl2` になる
（例: `Start-Services_wsl2.ps1`）。

[README に戻る](README.md)

## 基本方針

1. **必要なサービスだけを起動する**（`Start-Services.ps1 <サービス名>`）。引数なしは全サービスを起動するので避ける。
2. **使い終わったら `down` で止める**（`Stop-Services.ps1 <サービス名>`）。
   全サービスを `restart: "no"` にしているので、Docker エンジン（Rancher Desktop）を起動しても
   コンテナは自動では起動しない。起動は常に `Start-Services.ps1` で明示的に行う。
3. **状態は `Show-Services.ps1` で確認する**（読み取り専用なので、起動も停止もしない）。
4. **調子が悪いサービスだけを作り直す**（`Reboot-Services.ps1 <サービス名> -Recreate`）。
5. **重いサービスは常用しない。** 特に `oracle` と `sqlserver` は大きい。
   いつも使う組み合わせは `oretoku-set.bat` の `SERVICES` に書いておく（既定は `sqlserver` のみ）。
6. DB のキャッシュには上限を付けてある（sqlserver 300MB・mongo 0.3GB など。[後述](#db-のキャッシュバッファプール)）。

## サービス毎のコマンド

いずれもリポジトリのフォルダで PowerShell から実行する。`up` は DB が接続可能になるまで待つ。

| サービス | 起動 | 停止 | 状態確認 | 再構築（作り直し） |
|---|---|---|---|---|
| redis | `.\Start-Services.ps1 redis` | `.\Stop-Services.ps1 redis` | `.\Show-Services.ps1 redis` | `.\Reboot-Services.ps1 redis -Recreate` |
| mongo | `.\Start-Services.ps1 mongo` | `.\Stop-Services.ps1 mongo` | `.\Show-Services.ps1 mongo` | `.\Reboot-Services.ps1 mongo -Recreate` |
| mysql | `.\Start-Services.ps1 mysql` | `.\Stop-Services.ps1 mysql` | `.\Show-Services.ps1 mysql` | `.\Reboot-Services.ps1 mysql -Recreate` |
| postgres | `.\Start-Services.ps1 postgres` | `.\Stop-Services.ps1 postgres` | `.\Show-Services.ps1 postgres` | `.\Reboot-Services.ps1 postgres -Recreate` |
| sqlserver | `.\Start-Services.ps1 sqlserver` | `.\Stop-Services.ps1 sqlserver` | `.\Show-Services.ps1 sqlserver` | `.\Reboot-Services.ps1 sqlserver -Recreate` |
| oracle | `.\Start-Services.ps1 oracle` | `.\Stop-Services.ps1 oracle` | `.\Show-Services.ps1 oracle` | `.\Reboot-Services.ps1 oracle -Recreate` |

- サービス名はスペース区切りで複数指定できる（例: `.\Start-Services.ps1 mysql redis`）。
- `-Recreate` を付けない `Reboot-Services.ps1 <サービス名>` は `docker compose restart`（データは保持）。
  本 compose は永続ボリュームを使っていないため、作り直してもテストデータは初期化スクリプトで再作成される。
- メモリの実使用量は `docker stats --no-stream` で確認できる。

### docker compose を直接使う場合

スクリプトを使わない場合（`Start-Services.bat` の利用者や WSL2 のシェル内）は次のとおり。
`up` 直後は DB がまだ初期化中のことがある（準備完了は待たない）。

| 操作 | コマンド |
|---|---|
| 起動 | `docker compose up -d <サービス名>` |
| 停止 | `docker compose down <サービス名>`（サービス名を省くと全サービス） |
| 状態確認 | `docker compose ps <サービス名>` / `docker compose logs -f <サービス名>` |
| 再構築 | `docker compose rm -sfv <サービス名>` → `docker compose up -d <サービス名>` |

初回だけ `docker network create --driver bridge common_link` が必要（`*.ps1` / `*.bat` は自動で作成する）。

## DB のキャッシュ（バッファプール）

メモリ削減のため、DB のキャッシュに上限を付けている（`docker-compose.yml`）。

| サービス | 設定するパラメーター | 本リポジトリの既定 | イメージ本来の既定 | 個別に変える変数 |
|---|---|---|---|---|
| mysql | `innodb_buffer_pool_size`（起動オプション） | 128MB | 128MB | `MYSQL_BUFFER_POOL_MB` |
| postgres | `shared_buffers`（起動オプション `-c`） | 128MB | 128MB | `POSTGRES_BUFFER_POOL_MB` |
| sqlserver | `max server memory (MB)`（`sqlserver/init/start-up.sh` が起動の度に設定） | 300MB | 上限なし | `SQLSERVER_BUFFER_POOL_MB` |
| mongo | `--wiredTigerCacheSizeGB`（起動オプション） | 0.3GB | （VM のメモリ − 1GB）の半分 | `MONGO_CACHE_SIZE_GB` |
| oracle | 対象外（下記） | — | — | — |

補足:
- mysql・postgres はイメージ本来の既定（128MB）のまま。`-BufferPoolMB` などで変えられるよう、明示的に指定している。
- **メモリ削減の効果が大きいのは sqlserver と mongo**（どちらも本来は VM のメモリに比例して大きく使う）。
- sqlserver の `max server memory` はバッファプール等の上限で、プロセス全体はこれより大きくなる。128 未満は設定できない。
- mongo の値は GB 単位の小数で、0.25 以上。RDBMS 用の `-BufferPoolMB` / `DB_BUFFER_POOL_MB` は効かない
  （`MONGO_CACHE_SIZE_GB` で変える）。
- oracle は SGA を小さくしすぎると DB が起動しなくなる危険があるため、自動では変更しない。
  なお 23ai Free は製品の制限で SGA と PGA の合計が 2GB までなので、それ以上は使わない。
  メモリを空けたいときは、使わない間は `.\Stop-Services.ps1 oracle` で止めておく。

### 値の変え方

RDBMS の優先順位は **サービス個別の変数 > `DB_BUFFER_POOL_MB`（mysql / postgres / sqlserver 共通）> 上表の既定**。
値が変わると、`up` 時に compose が対象コンテナを自動で作り直す。

**① スクリプトの `-BufferPoolMB`（その回だけ。mysql / postgres / sqlserver 共通）**
```
> .\Start-Services.ps1 mysql postgres -BufferPoolMB 512
> .\Reboot-Services.ps1 sqlserver -BufferPoolMB 1024
```
- 128 以上を指定する。`Reboot-Services.ps1` は `restart` では反映されないため、指定すると自動で `-Recreate` 相当になる。
- 次回 `-BufferPoolMB` なしで `up` すると既定値（または下記の設定）に戻り、コンテナが作り直される。

**② 環境変数（そのシェルの間だけ）**
```
> $env:DB_BUFFER_POOL_MB = 512          # PowerShell
> set DB_BUFFER_POOL_MB=512             # cmd（Start-Services.bat の前に）
$ DB_BUFFER_POOL_MB=512 docker compose up -d mysql   # WSL2 のシェル
```

**③ `.env` ファイル（常にその値を使う）**  
リポジトリのフォルダに `.env` を作ると、compose が自動で読む（`.gitignore` 済み）。
個別の値を指定したいとき・WSL2 版を使うときはこれが確実。
```
SQLSERVER_BUFFER_POOL_MB=512
MYSQL_BUFFER_POOL_MB=256
MONGO_CACHE_SIZE_GB=0.5
```
> WSL2 版の `*_wsl2.ps1` は `-BufferPoolMB` を VM 内へ引き継ぐが、PowerShell で設定した
> 個別の変数（`MYSQL_BUFFER_POOL_MB` / `MONGO_CACHE_SIZE_GB` など）は引き継がない。個別に変えるなら `.env` を使う。

### 現在の値を確認する

```
> docker compose exec mysql mysql -uroot -pseigi@123 -e "SELECT @@innodb_buffer_pool_size/1024/1024 AS MB"
> docker compose exec postgres psql -U postgres -c "SHOW shared_buffers"
> docker compose exec sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U SA -P seigi@123 -C -Q "SELECT value_in_use FROM sys.configurations WHERE name = 'max server memory (MB)'"
> docker compose exec mongo mongosh -u seigi -p seigi@123 --authenticationDatabase admin --quiet --eval "db.serverStatus().wiredTiger.cache['maximum bytes configured']/1024/1024"
> docker compose exec oracle bash -c "echo 'show parameter sga_target' | sqlplus -s / as sysdba"
```
`docker compose config` で、compose が解決した値（`--innodb-buffer-pool-size=128M` など）も確認できる。

## VM 全体のメモリに上限を付ける

Windows では Rancher Desktop・WSL2 版とも WSL2 の VM 上で動くため、VM のメモリ上限は
`%UserProfile%\.wslconfig` で決まる。上限を付けておくと、DB がメモリを使い切っても Windows 側は固まりにくい。
```ini
[wsl2]
memory=6GB
```
変更後は Rancher Desktop を終了してから `wsl --shutdown` し、起動し直すと反映される。

## 固まった・強制シャットダウンした後の復帰

現在は `restart: "no"` なので、エンジンを起動してもコンテナは自動では復帰しない。
ただし**以前の `restart: always` の頃に作られたコンテナは古い設定のまま**で、エンジンの起動時に
一斉に復帰して、また固まることがある。そのコンテナを一度 `down` で削除すれば、以降は新しい設定になる。
次の順で戻すのが安全。

1. まだなら[VM のメモリ上限](#vm-全体のメモリに上限を付ける)を設定しておく（復帰した瞬間に再び固まるのを防ぐ）。
   そのうえで Rancher Desktop を起動する（WSL2 版ならそのまま 2. へ）。
2. 起動したらすぐに全サービスを止めて、コンテナを削除する: `.\Stop-Services.ps1`（WSL2 版は `.\Stop-Services_wsl2.ps1`）
3. 状態を確認する: `.\Show-Services.ps1`（すべて `-` になっていればよい）
4. 必要なサービスだけを起動する: `.\Start-Services.ps1 mysql`
5. 起動しない・データがおかしいサービスは作り直す: `.\Reboot-Services.ps1 mysql -Recreate`
