"""MongoDB 接続テスト（PyMongo）。"""
from pymongo import MongoClient

from config import MONGO
from util import print_table


def run():
    print("===== Test MongoDB =====")
    client = MongoClient(MONGO["uri"])
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
