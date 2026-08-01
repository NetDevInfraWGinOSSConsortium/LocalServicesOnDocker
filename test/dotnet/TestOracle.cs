using Oracle.ManagedDataAccess.Client;

namespace DbTests;

// Oracle Database 接続テスト（ODP.NET Core / Oracle.ManagedDataAccess.Core）。
// マネージド版のため Oracle Client（Instant Client）のインストールは不要。
public static class TestOracle
{
    public static async Task RunAsync()
    {
        Console.WriteLine("===== Test Oracle =====");
        await using var conn = new OracleConnection(Config.Oracle);
        await conn.OpenAsync();

        await using var cmd = new OracleCommand("SELECT * FROM Shippers", conn);
        await using var reader = await cmd.ExecuteReaderAsync();
        await Table.PrintReaderAsync(reader);
    }
}
