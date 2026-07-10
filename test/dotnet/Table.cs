using System.Data.Common;

namespace DbTests;

// 結果表示用の簡易ユーティリティ。
public static class Table
{
    // ADO.NET の DbDataReader（MySqlConnector / Npgsql / SqlClient 共通の基底型）を表示する。
    public static async Task PrintReaderAsync(DbDataReader reader)
    {
        var columns = new string[reader.FieldCount];
        for (var i = 0; i < reader.FieldCount; i++)
            columns[i] = reader.GetName(i);

        var rows = new List<object?[]>();
        while (await reader.ReadAsync())
        {
            var row = new object?[reader.FieldCount];
            for (var i = 0; i < reader.FieldCount; i++)
                row[i] = await reader.IsDBNullAsync(i) ? null : reader.GetValue(i);
            rows.Add(row);
        }

        Print(columns, rows);
    }

    public static void Print(IReadOnlyList<string> columns, IReadOnlyList<object?[]> rows)
    {
        static string Cell(object? v) => v is null ? "NULL" : v.ToString() ?? "";

        var widths = new int[columns.Count];
        for (var i = 0; i < columns.Count; i++)
            widths[i] = columns[i].Length;
        foreach (var row in rows)
            for (var i = 0; i < columns.Count; i++)
                widths[i] = Math.Max(widths[i], Cell(row[i]).Length);

        Console.WriteLine(string.Join(" | ",
            Enumerable.Range(0, columns.Count).Select(i => columns[i].PadRight(widths[i]))));
        Console.WriteLine(string.Join("-+-", widths.Select(w => new string('-', w))));
        foreach (var row in rows)
            Console.WriteLine(string.Join(" | ",
                Enumerable.Range(0, columns.Count).Select(i => Cell(row[i]).PadRight(widths[i]))));
        Console.WriteLine($"({rows.Count} row(s))");
    }
}
