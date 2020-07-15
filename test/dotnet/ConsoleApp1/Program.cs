using System;
using System.Collections.Generic;

using Newtonsoft.Json;

// Touryoさん
using Touryo.Infrastructure.Public.Str;
using Touryo.Infrastructure.Public.Util;

// RDBMS
using System.Data.SqlClient;
using Oracle.ManagedDataAccess.Client;
using MySql.Data.MySqlClient;
using Npgsql;

// NoSQL
using StackExchange.Redis;
using MongoDB.Driver;
using MongoDB.Bson;
using MongoDB.Bson.Serialization.Attributes;

namespace ConsoleApp1
{
    [BsonIgnoreExtraElements]
    public class Person
    {
        [BsonId]
        public ObjectId Id { get; set; }

        [BsonElement("name")]
        public string Name { get; set; }

        [BsonElement("age")]
        public decimal Age { get; set; }
    }

    public class Program
    {
        static void Main(string[] args)
        {
            // configの初期化
            GetConfigParameter.InitConfiguration("appsettings.json");

            // コマンドラインをバラす関数がある。
            List<string> valsLst = null;
            Dictionary<string, string> argsDic = null;

            StringVariableOperator.GetCommandArgs('/', out argsDic, out valsLst);

            if (argsDic.ContainsKey("/SQL"))
            {
                SqlConnection cn = new SqlConnection(GetConfigParameter.GetConnectionString("ConnectionString_SQL"));
                cn.Open();
                SqlCommand cmd = new SqlCommand("SELECT COUNT(*) FROM SHIPPERS", cn);
                Console.WriteLine("SQL:" + cmd.ExecuteScalar().ToString() + "件");
            }

            if (argsDic.ContainsKey("/ODP"))
            {
                OracleConnection cn = new OracleConnection(GetConfigParameter.GetConnectionString("ConnectionString_ODP"));
                cn.Open();
                OracleCommand cmd = new OracleCommand("SELECT COUNT(*) FROM SHIPPERS", cn);
                Console.WriteLine("ODP:" + cmd.ExecuteScalar().ToString() + "件");
            }

            if (argsDic.ContainsKey("/MCN"))
            {
                MySqlConnection cn = new MySqlConnection(GetConfigParameter.GetConnectionString("ConnectionString_MCN"));
                cn.Open();
                MySqlCommand cmd = new MySqlCommand("SELECT COUNT(*) FROM Shippers", cn);
                Console.WriteLine("MCN:" + cmd.ExecuteScalar().ToString() + "件");
            }

            if (argsDic.ContainsKey("/NPS"))
            {
                NpgsqlConnection cn = new NpgsqlConnection(GetConfigParameter.GetConnectionString("ConnectionString_NPS"));
                cn.Open();
                NpgsqlCommand cmd = new NpgsqlCommand("SELECT COUNT(*) FROM SHIPPERS", cn);
                Console.WriteLine("NPS:" + cmd.ExecuteScalar().ToString() + "件");
            }

            if (argsDic.ContainsKey("/REDIS"))
            {
                ConnectionMultiplexer redis = ConnectionMultiplexer.Connect("localhost");
                IDatabase cache = redis.GetDatabase();
                cache.StringSet("key:jp:hello", "こんにちは");
                cache.StringSet("key:jp:goodbye", "さようなら");
                Console.WriteLine(cache.StringGet("key:jp:hello"));
                Console.WriteLine(cache.StringGet("key:jp:goodbye"));
            }

            if (argsDic.ContainsKey("/MONGO"))
            {
                string connectionString = "mongodb://seigi:seigi%40123@localhost:27017";
                MongoClient client = new MongoClient(connectionString);

                IMongoDatabase db = client.GetDatabase("testdb");
                IMongoCollection<Person> collection = db.GetCollection<Person>("testtbl");

                // 全ドキュメントの削除
                collection.DeleteMany(FilterDefinition<Person>.Empty);

                // ドキュメントの挿入
                Person person = null;
                person = new Person
                {
                    Name = "Dan",
                    Age = 18,
                };
                collection.InsertOne(person);
                person = new Person
                {
                    Name = "Bob",
                    Age = 22,
                };
                collection.InsertOne(person);
                person = new Person
                {
                    Name = "John",
                    Age = 30,
                };
                collection.InsertOne(person);

                // ドキュメントの参照
                var persons = collection.Find(FilterDefinition<Person>.Empty).ToList();

                foreach (Person _person in persons)
                {
                    Console.WriteLine(JsonConvert.SerializeObject(_person));
                }
            }
        }
    }
}
