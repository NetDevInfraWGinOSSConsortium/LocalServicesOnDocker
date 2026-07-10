"""各サービスへの接続設定。

環境変数で上書き可能（例: DB_HOST=192.168.0.10 python test_all.py）。
"""
import os

HOST = os.environ.get("DB_HOST", "localhost")

REDIS = {
    "host": HOST,
    "port": int(os.environ.get("REDIS_PORT", 6379)),
}

# @ は URL エンコードして %40。認証情報は admin データベースで作成されるため authSource=admin。
MONGO = {
    "uri": os.environ.get(
        "MONGO_URL", f"mongodb://seigi:seigi%40123@{HOST}:27017/?authSource=admin"
    ),
    "db": os.environ.get("MONGO_DB", "testdb"),
    "collection": "testtbl",
}

MYSQL = {
    "host": HOST,
    "port": int(os.environ.get("MYSQL_PORT", 3306)),
    "user": os.environ.get("MYSQL_USER", "root"),
    "password": os.environ.get("MYSQL_PASSWORD", "seigi@123"),
    "database": os.environ.get("MYSQL_DB", "test"),
}

POSTGRES = {
    "host": HOST,
    "port": int(os.environ.get("PG_PORT", 5432)),
    "user": os.environ.get("PG_USER", "postgres"),
    "password": os.environ.get("PG_PASSWORD", "seigi@123"),
    "dbname": os.environ.get("PG_DB", "postgres"),
}

SQLSERVER = {
    "server": HOST,
    "port": int(os.environ.get("MSSQL_PORT", 1433)),
    "user": os.environ.get("MSSQL_USER", "SA"),
    "password": os.environ.get("MSSQL_PASSWORD", "seigi@123"),
    "database": os.environ.get("MSSQL_DB", "Northwind"),
}
