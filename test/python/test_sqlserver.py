"""SQL Server 接続テスト（pymssql）。

pymssql は FreeTDS を同梱しており、別途 ODBC ドライバのインストールは不要。
"""
import pymssql

from config import SQLSERVER
from util import print_table


def run():
    print("===== Test SQLServer =====")
    conn = pymssql.connect(
        server=SQLSERVER["server"],
        port=str(SQLSERVER["port"]),
        user=SQLSERVER["user"],
        password=SQLSERVER["password"],
        database=SQLSERVER["database"],
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
