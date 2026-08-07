"""Redis 接続テスト（redis-py）。"""
import redis
from redis.backoff import NoBackoff
from redis.retry import Retry

from config import CONNECT_TIMEOUT_SEC, REDIS


def run():
    print("===== Test Redis =====")
    # redis-py 8 は既定で 10 回リトライする（指数バックオフ付き）ため、接続タイムアウト
    # だけを指定しても実際には数十秒待つことになる。疎通テストでは 1 回で失敗させたいので
    # リトライを無効化する。
    client = redis.Redis(
        host=REDIS["host"],
        port=REDIS["port"],
        decode_responses=True,
        socket_connect_timeout=CONNECT_TIMEOUT_SEC,
        retry=Retry(NoBackoff(), 0),
    )
    try:
        client.set("key", "value")
        result = client.get("key")
        print("GET key =>", result)  # value
        assert result == "value", f"unexpected value: {result}"
    finally:
        client.close()


if __name__ == "__main__":
    run()
