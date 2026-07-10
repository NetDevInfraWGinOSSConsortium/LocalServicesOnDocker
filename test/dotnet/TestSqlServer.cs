using Microsoft.Data.SqlClient;

namespace DbTests;

// SQL Server 接続テスト（Microsoft.Data.SqlClient）。
public static class TestSqlServer
{
    public static async Task RunAsync()
    {
        Console.WriteLine("===== Test SQLServer =====");
        await using var conn = new SqlConnection(Config.SqlServer);
        await conn.OpenAsync();

        await using var cmd = new SqlCommand("SELECT * FROM Shippers", conn);
        await using var reader = await cmd.ExecuteReaderAsync();
        await Table.PrintReaderAsync(reader);
    }
}
