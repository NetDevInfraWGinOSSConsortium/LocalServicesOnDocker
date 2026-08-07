"""SQL Server 接続テスト（pymssql）。

pymssql は FreeTDS を同梱しており、別途 ODBC ドライバのインストールは不要。
"""
import pymssql

from config import CONNECT_TIMEOUT_SEC, SQLSERVER
from util import print_table


def run():
    print("===== Test SQLServer =====")
    # pymssql の login_timeout が接続（ログイン）待ちの上限。timeout はクエリ側なので別物。
    conn = pymssql.connect(
        server=SQLSERVER["server"],
        port=str(SQLSERVER["port"]),
        user=SQLSERVER["user"],
        password=SQLSERVER["password"],
        database=SQLSERVER["database"],
        login_timeout=CONNECT_TIMEOUT_SEC,
    )
    try:
        cur = conn.cursor()
        cur.execute("SELECT * FROM Shippers")
        rows = cur.fetchall()
        columns = [d[0] for d in cur.description]
        print_table(columns, rows)
    finally:
        conn.close()


if __name__ == "__main__":
    run()
