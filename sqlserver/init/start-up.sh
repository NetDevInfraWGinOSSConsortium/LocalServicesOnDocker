#!/bin/bash
# SQL Server の起動後に Northwind データベースを自動作成する。
# 公式の instnwnd.sql は「DB を作成しない（対象 DB 内で実行する）」スクリプトのため、
# ここで CREATE DATABASE Northwind を行ってから -d Northwind で流し込む。
#
# 起動直後のロードは一部のバッチが失敗して不完全になることがある（テーブルだけ出来て
# データが入らない等）。そこで「Shippers が 3 行あるか」で完全ロードを検証し、
# 不完全なら DB を作り直して再試行する。完了後にセンチネル表を作り、
# Start-Services.ps1 側がそれを見て「データ準備完了」を判定できるようにする。
set -u

PASS="${MSSQL_SA_PASSWORD:-${SA_PASSWORD:-}}"

# sqlcmd の場所はイメージのバージョンで異なる（2022 は tools18）。
SQLCMD=""
for p in /opt/mssql-tools18/bin/sqlcmd /opt/mssql-tools/bin/sqlcmd; do
  [ -x "$p" ] && { SQLCMD="$p"; break; }
done
if [ -z "$SQLCMD" ]; then
  echo "[init] sqlcmd not found; skip Northwind init."
  exit 0
fi
# tools18 は TLS 検証回避の -C が必要（旧 tools は -C 非対応）。
CFLAG=""
case "$SQLCMD" in *tools18*) CFLAG="-C" ;; esac

q() { "$SQLCMD" -S localhost -U SA -P "$PASS" $CFLAG "$@"; }

echo "[init] waiting for SQL Server to accept logins..."
for i in $(seq 1 90); do
  q -Q "SELECT 1" >/dev/null 2>&1 && break
  sleep 2
done

# Shippers が 3 行あれば完全ロード済みとみなす。
loaded() {
  local n
  n=$(q -d Northwind -h -1 -W -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM dbo.Shippers" 2>/dev/null | tr -d '[:space:]')
  [ "$n" = "3" ]
}

if loaded; then
  echo "[init] Northwind already fully loaded; skip."
  q -d Northwind -Q "IF OBJECT_ID('dbo.__NorthwindReady') IS NULL CREATE TABLE dbo.__NorthwindReady(ok bit)" >/dev/null 2>&1
  exit 0
fi

for attempt in 1 2 3 4 5; do
  echo "[init] loading Northwind (attempt ${attempt})..."
  # 不完全な既存 DB を確実に破棄してから作り直す。
  q -Q "IF DB_ID('Northwind') IS NOT NULL BEGIN ALTER DATABASE Northwind SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE Northwind; END; CREATE DATABASE Northwind;" >/dev/null 2>&1
  q -d Northwind -i /init/instnwnd.sql >/dev/null 2>&1
  if loaded; then
    q -d Northwind -Q "IF OBJECT_ID('dbo.__NorthwindReady') IS NULL CREATE TABLE dbo.__NorthwindReady(ok bit)" >/dev/null 2>&1
    echo "[init] Northwind loaded successfully (attempt ${attempt})."
    exit 0
  fi
  echo "[init] load incomplete; retrying..."
  sleep 3
done

echo "[init] WARNING: Northwind load did not complete after retries."
exit 0
