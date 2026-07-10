using MySqlConnector;

namespace DbTests;

// MySQL 接続テスト（MySqlConnector）。
public static class TestMySql
{
    public static async Task RunAsync()
    {
        Console.WriteLine("===== Test MySQL =====");
        await using var conn = new MySqlConnection(Config.MySql);
        await conn.OpenAsync();

        await using var cmd = new MySqlCommand("SELECT * FROM Shippers", conn);
        await using var reader = await cmd.ExecuteReaderAsync();
        await Table.PrintReaderAsync(reader);
    }
}
