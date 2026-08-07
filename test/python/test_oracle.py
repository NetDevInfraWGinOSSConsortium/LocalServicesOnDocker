"""Oracle Database 接続テスト（python-oracledb / Thin モード）。

Thin モードが既定のため、Oracle Client（Instant Client）のインストールは不要。
"""
import oracledb

from config import CONNECT_TIMEOUT_SEC, ORACLE
from util import print_table


def run():
    print("===== Test Oracle =====")
    conn = oracledb.connect(
        user=ORACLE["user"],
        password=ORACLE["password"],
        dsn=ORACLE["dsn"],
        tcp_connect_timeout=CONNECT_TIMEOUT_SEC,
    )
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT * FROM Shippers")
            rows = cur.fetchall()
            columns = [d[0] for d in cur.description]
            print_table(columns, rows)
    finally:
        conn.close()


if __name__ == "__main__":
    run()
