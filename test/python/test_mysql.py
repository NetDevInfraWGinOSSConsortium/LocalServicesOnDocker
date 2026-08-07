"""MySQL 接続テスト（PyMySQL）。"""
import pymysql

from config import CONNECT_TIMEOUT_SEC, MYSQL
from util import print_table


def run():
    print("===== Test MySQL =====")
    conn = pymysql.connect(
        host=MYSQL["host"],
        port=MYSQL["port"],
        user=MYSQL["user"],
        password=MYSQL["password"],
        database=MYSQL["database"],
        connect_timeout=CONNECT_TIMEOUT_SEC,
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
