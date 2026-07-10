"""結果表示用の簡易ユーティリティ。"""


def print_table(columns, rows):
    """列名リストと行（タプル/リスト）の並びを整形して表示する。"""
    columns = [str(c) for c in columns]
    str_rows = [[("NULL" if v is None else str(v)) for v in row] for row in rows]

    widths = [len(c) for c in columns]
    for row in str_rows:
        for i, v in enumerate(row):
            if i < len(widths):
                widths[i] = max(widths[i], len(v))

    def fmt(values):
        return " | ".join(v.ljust(widths[i]) for i, v in enumerate(values))

    print(fmt(columns))
    print("-+-".join("-" * w for w in widths))
    for row in str_rows:
        print(fmt(row))
    print(f"({len(str_rows)} row(s))")
