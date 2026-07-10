"""Redis 接続テスト（redis-py）。"""
import redis

from config import REDIS


def run():
    print("===== Test Redis =====")
    client = redis.Redis(host=REDIS["host"], port=REDIS["port"], decode_responses=True)
    try:
        client.set("key", "value")
        result = client.get("key")
        print("GET key =>", result)  # value
        assert result == "value", f"unexpected value: {result}"
    finally:
        client.close()


if __name__ == "__main__":
    run()
