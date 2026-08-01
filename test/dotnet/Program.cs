using DbTests;

// 全サービスのテストを順に実行し、結果サマリを表示する。
// 引数でサービス名の一部を渡すと、その 1 つだけ実行する（例: dotnet run -- redis）。
var tests = new (string Name, Func<Task> Run)[]
{
    ("Redis", TestRedis.RunAsync),
    ("MongoDB", TestMongo.RunAsync),
    ("MySQL", TestMySql.RunAsync),
    ("Postgres", TestPostgres.RunAsync),
    ("SQLServer", TestSqlServer.RunAsync),
    ("Oracle", TestOracle.RunAsync),
};

var filter = args.Length > 0 ? args[0].Trim().ToLowerInvariant() : null;
var results = new List<(string Name, bool Ok, string Err)>();

foreach (var (name, run) in tests)
{
    if (filter is not null && !name.ToLowerInvariant().Contains(filter))
        continue;

    try
    {
        await run();
        results.Add((name, true, ""));
    }
    catch (Exception ex)
    {
        Console.WriteLine($"[{name}] FAILED: {ex.Message}");
        results.Add((name, false, ex.Message));
    }

    Console.WriteLine();
}

Console.WriteLine("===== Summary =====");
foreach (var (name, ok, err) in results)
    Console.WriteLine($"  {name,-10} {(ok ? "OK" : "NG")}{(err.Length > 0 ? "  " + err : "")}");

Environment.Exit(results.Any(r => !r.Ok) ? 1 : 0);
