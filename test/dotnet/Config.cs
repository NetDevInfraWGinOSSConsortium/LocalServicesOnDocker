namespace DbTests;

// 各サービスへの接続設定。環境変数で上書き可能（例: set DB_HOST=192.168.0.10）。
public static class Config
{
    static string Env(string name, string def) =>
        Environment.GetEnvironmentVariable(name) is { Length: > 0 } v ? v : def;

    static int EnvInt(string name, int def) =>
        int.TryParse(Environment.GetEnvironmentVariable(name), out var p) ? p : def;

    public static string Host => Env("DB_HOST", "localhost");

    public static string Redis => $"{Host}:{EnvInt("REDIS_PORT", 6379)}";

    // @ は URL エンコードして %40。認証情報は admin データベースで作成されるため authSource=admin。
    public static string MongoUri =>
        Env("MONGO_URL", $"mongodb://seigi:seigi%40123@{Host}:27017/?authSource=admin");
    public const string MongoDb = "testdb";
    public const string MongoCollection = "testtbl";

    public static string MySql =>
        $"Server={Host};Port={EnvInt("MYSQL_PORT", 3306)};Database={Env("MYSQL_DB", "test")};" +
        $"User ID={Env("MYSQL_USER", "root")};Password={Env("MYSQL_PASSWORD", "seigi@123")}";

    public static string Postgres =>
        $"Host={Host};Port={EnvInt("PG_PORT", 5432)};Database={Env("PG_DB", "postgres")};" +
        $"Username={Env("PG_USER", "postgres")};Password={Env("PG_PASSWORD", "seigi@123")}";

    // SqlClient は既定で暗号化を要求するため、自己署名証明書を信頼する設定を付与する。
    // また localhost は IPv6(::1) に解決されて接続がタイムアウトすることがあるため、
    // ループバックは IPv4 の 127.0.0.1 を明示的に使う。
    public static string SqlServer =>
        $"Server={(Host == "localhost" ? "127.0.0.1" : Host)},{EnvInt("MSSQL_PORT", 1433)};" +
        $"Database={Env("MSSQL_DB", "Northwind")};" +
        $"User ID={Env("MSSQL_USER", "SA")};Password={Env("MSSQL_PASSWORD", "seigi@123")};" +
        "Encrypt=False;TrustServerCertificate=True";
}
