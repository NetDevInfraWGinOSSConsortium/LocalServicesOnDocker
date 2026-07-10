#!/bin/bash
# SQL Server の起動後に Northwind データベースを自動作成する。
# 公式の instnwnd.sql は「DB を作成しない（対象 DB 内で実行する）」スクリプトのため、
# ここで CREATE DATABASE Northwind を行ってから -d Northwind で流し込む。
# コンテナ再起動時に既に Northwind があればスキップする（冪等）。
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

run() { "$SQLCMD" -S localhost -U SA -P "$PASS" $CFLAG "$@"; }

echo "[init] waiting for SQL Server to accept logins..."
for i in $(seq 1 90); do
  run -Q "SELECT 1" >/dev/null 2>&1 && break
  sleep 2
done

if run -h -1 -W -Q "SET NOCOUNT ON; SELECT CASE WHEN DB_ID('Northwind') IS NULL THEN 'MISSING' ELSE 'EXISTS' END" 2>/dev/null | grep -q EXISTS; then
  echo "[init] Northwind already exists; skip."
  exit 0
fi

echo "[init] creating database Northwind..."
run -Q "IF DB_ID('Northwind') IS NULL CREATE DATABASE Northwind"

echo "[init] loading instnwnd.sql into Northwind..."
run -d Northwind -i /init/instnwnd.sql

echo "[init] Northwind initialization done."
