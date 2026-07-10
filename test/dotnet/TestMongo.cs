using MongoDB.Bson;
using MongoDB.Driver;

namespace DbTests;

// MongoDB 接続テスト（MongoDB.Driver）。
public static class TestMongo
{
    public static async Task RunAsync()
    {
        Console.WriteLine("===== Test MongoDB =====");
        var client = new MongoClient(Config.MongoUri);
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
