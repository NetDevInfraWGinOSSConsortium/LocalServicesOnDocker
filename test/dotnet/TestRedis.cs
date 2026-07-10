using StackExchange.Redis;

namespace DbTests;

// Redis 接続テスト（StackExchange.Redis）。
public static class TestRedis
{
    public static async Task RunAsync()
    {
        Console.WriteLine("===== Test Redis =====");
        using var redis = await ConnectionMultiplexer.ConnectAsync(Config.Redis);
        var db = redis.GetDatabase();

        await db.StringSetAsync("key", "value");
        var value = await db.StringGetAsync("key");
        Console.WriteLine($"GET key => {value}");

        if (value != "value")
            throw new Exception($"unexpected value: {value}");
    }
}
