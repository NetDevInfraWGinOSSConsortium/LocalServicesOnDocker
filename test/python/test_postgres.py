"""PostgreSQL 接続テスト（psycopg2）。"""
import psycopg2

from config import POSTGRES
from util import print_table


def run():
    print("===== Test Postgres =====")
    conn = psycopg2.connect(
        host=POSTGRES["host"],
        port=POSTGRES["port"],
        user=POSTGRES["user"],
        password=POSTGRES["password"],
        dbname=POSTGRES["dbname"],
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
