using Npgsql;

namespace DbTests;

// PostgreSQL 接続テスト（Npgsql）。
public static class TestPostgres
{
    public static async Task RunAsync()
    {
        Console.WriteLine("===== Test Postgres =====");
        await using var conn = new NpgsqlConnection(Config.Postgres);
        await conn.OpenAsync();

        await using var cmd = new NpgsqlCommand("SELECT * FROM Shippers", conn);
        await using var reader = await cmd.ExecuteReaderAsync();
        await Table.PrintReaderAsync(reader);
    }
}
