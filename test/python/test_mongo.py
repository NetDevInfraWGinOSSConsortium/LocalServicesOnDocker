"""MongoDB 接続テスト（PyMongo）。"""
from pymongo import MongoClient

from config import CONNECT_TIMEOUT_MS, MONGO
from util import print_table


def run():
    print("===== Test MongoDB =====")
    # PyMongo は接続を遅延させるため、実際の待ち時間はサーバ選択タイムアウトで決まる。
    # 接続タイムアウトだけでは既定の 30 秒待ってしまうので、両方を指定する。
    client = MongoClient(
        MONGO["uri"],
        connectTimeoutMS=CONNECT_TIMEOUT_MS,
        serverSelectionTimeoutMS=CONNECT_TIMEOUT_MS,
    )
    try:
        client.admin.command("ping")
        print("Connected successfully to server.")

        tbl = client[MONGO["db"]][MONGO["collection"]]

        # Delete
        deleted = tbl.delete_many({}).deleted_count
        print(f"{deleted} document(s) deleted")

        # Insert
        tbl.insert_many(
            [
                {"name": "Dan", "age": 18},
                {"name": "Bob", "age": 22},
                {"name": "John", "age": 30},
            ]
        )

        # Select
        docs = list(tbl.find({}, {"_id": 0}))
        print_table(["name", "age"], [(d["name"], d["age"]) for d in docs])
    finally:
        client.close()


if __name__ == "__main__":
    run()
