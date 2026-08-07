namespace DbTests;

// 各サービスへの接続設定。環境変数で上書き可能（例: set DB_HOST=192.168.0.10）。
public static class Config
{
    static string Env(string name, string def) =>
        Environment.GetEnvironmentVariable(name) is { Length: > 0 } v ? v : def;

    static int EnvInt(string name, int def) =>
        int.TryParse(Environment.GetEnvironmentVariable(name), out var p) ? p : def;

    public static string Host => Env("DB_HOST", "localhost");

    // 接続タイムアウト。サービスが起動していないときに長時間ぶら下がらないよう 3 秒に統一する。
    // 接続文字列のキーワードはドライバごとに異なる（下記参照）。
    // 環境変数 DB_CONNECT_TIMEOUT（秒）で上書き可能。
    public static int ConnectTimeoutSec => EnvInt("DB_CONNECT_TIMEOUT", 3);

    // StackExchange.Redis の connectTimeout はミリ秒指定。
    // 既定では接続を複数回試すため、connectTimeout だけだと実際には倍近く待つ。
    // 疎通テストでは 1 回で失敗させたいので connectRetry=1 も付ける。
    public static string Redis =>
        $"{Host}:{EnvInt("REDIS_PORT", 6379)}," +
        $"connectTimeout={ConnectTimeoutSec * 1000},connectRetry=1";

    // @ は URL エンコードして %40。認証情報は admin データベースで作成されるため authSource=admin。
    // タイムアウトは接続文字列に足すと MONGO_URL で上書きされたときに失われるため、
    // TestMongo.cs 側で MongoClientSettings に設定する。
    public static string MongoUri =>
        Env("MONGO_URL", $"mongodb://seigi:seigi%40123@{Host}:27017/?authSource=admin");
    public const string MongoDb = "testdb";
    public const string MongoCollection = "testtbl";

    // MySqlConnector の Connection Timeout は秒指定。
    public static string MySql =>
        $"Server={Host};Port={EnvInt("MYSQL_PORT", 3306)};Database={Env("MYSQL_DB", "test")};" +
        $"User ID={Env("MYSQL_USER", "root")};Password={Env("MYSQL_PASSWORD", "seigi@123")};" +
        $"Connection Timeout={ConnectTimeoutSec}";

    // Npgsql の Timeout は接続確立の上限（秒）。Command Timeout はクエリ側なので別物。
    public static string Postgres =>
        $"Host={Host};Port={EnvInt("PG_PORT", 5432)};Database={Env("PG_DB", "postgres")};" +
        $"Username={Env("PG_USER", "postgres")};Password={Env("PG_PASSWORD", "seigi@123")};" +
        $"Timeout={ConnectTimeoutSec}";

    // SqlClient は既定で暗号化を要求するため、自己署名証明書を信頼する設定を付与する。
    // また localhost は IPv6(::1) に解決されて接続がタイムアウトすることがあるため、
    // ループバックは IPv4 の 127.0.0.1 を明示的に使う。
    public static string SqlServer =>
        $"Server={(Host == "localhost" ? "127.0.0.1" : Host)},{EnvInt("MSSQL_PORT", 1433)};" +
        $"Database={Env("MSSQL_DB", "Northwind")};" +
        $"User ID={Env("MSSQL_USER", "SA")};Password={Env("MSSQL_PASSWORD", "seigi@123")};" +
        $"Encrypt=False;TrustServerCertificate=True;Connect Timeout={ConnectTimeoutSec}";

    // Oracle のデータソースは「ホスト[:ポート]/サービス名」形式（簡易接続）。
    // XE は oracle/init/01_setup.sql が既定 PDB(FREEPDB1) に追加する別名サービス。
    // 既定ポート(1521)以外を使う場合は ORACLE_DSN でデータソースごと上書きする
    // （例: set ORACLE_DSN=localhost:1522/XE）。
    // ODP.NET の Connection Timeout は接続確立の上限（秒）。
    public static string Oracle =>
        $"User Id={Env("ORACLE_USER", "SCOTT")};Password={Env("ORACLE_PASSWORD", "tiger")};" +
        $"Data Source={Env("ORACLE_DSN", $"{Host}/{Env("ORACLE_SERVICE", "XE")}")};" +
        $"Connection Timeout={ConnectTimeoutSec};";
}
