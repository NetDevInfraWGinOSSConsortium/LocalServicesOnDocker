"""全サービスのテストを順に実行し、結果サマリを表示する。

いずれか失敗すれば終了コード 1 で終了する。
"""
import importlib
import sys

TESTS = [
    ("Redis", "test_redis"),
    ("MongoDB", "test_mongo"),
    ("MySQL", "test_mysql"),
    ("Postgres", "test_postgres"),
    ("SQLServer", "test_sqlserver"),
    ("Oracle", "test_oracle"),
]


def main():
    results = []
    for name, module_name in TESTS:
        try:
            importlib.import_module(module_name).run()
            results.append((name, "OK", ""))
        except Exception as exc:  # noqa: BLE001
            print(f"[{name}] FAILED: {exc}")
            results.append((name, "NG", str(exc)))
        print()

    print("===== Summary =====")
    for name, status, err in results:
        suffix = f"  {err}" if err else ""
        print(f"  {name:<10} {status}{suffix}")

    failed = [r for r in results if r[1] == "NG"]
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
