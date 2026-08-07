using MongoDB.Bson;
using MongoDB.Driver;

namespace DbTests;

// MongoDB 接続テスト（MongoDB.Driver）。
public static class TestMongo
{
    public static async Task RunAsync()
    {
        Console.WriteLine("===== Test MongoDB =====");
        // ドライバは接続を遅延させるため、実際の待ち時間はサーバ選択タイムアウトで決まる。
        // 接続タイムアウトだけでは既定の 30 秒待ってしまうので、両方を指定する。
        var settings = MongoClientSettings.FromConnectionString(Config.MongoUri);
        settings.ConnectTimeout = TimeSpan.FromSeconds(Config.ConnectTimeoutSec);
        settings.ServerSelectionTimeout = TimeSpan.FromSeconds(Config.ConnectTimeoutSec);
        var client = new MongoClient(settings);
        await client.GetDatabase("admin").RunCommandAsync<BsonDocument>(new BsonDocument("ping", 1));
        Console.WriteLine("Connected successfully to server.");

        var coll = client.GetDatabase(Config.MongoDb).GetCollection<BsonDocument>(Config.MongoCollection);

        // Delete
        var deleted = (await coll.DeleteManyAsync(Builders<BsonDocument>.Filter.Empty)).DeletedCount;
        Console.WriteLine($"{deleted} document(s) deleted");

        // Insert
        await coll.InsertManyAsync(new[]
        {
            new BsonDocument { { "name", "Dan" }, { "age", 18 } },
            new BsonDocument { { "name", "Bob" }, { "age", 22 } },
            new BsonDocument { { "name", "John" }, { "age", 30 } },
        });

        // Select
        var docs = await coll.Find(Builders<BsonDocument>.Filter.Empty).ToListAsync();
        Table.Print(
            new[] { "name", "age" },
            docs.Select(d => new object?[] { d["name"].AsString, d["age"].AsInt32 }).ToList());
    }
}
