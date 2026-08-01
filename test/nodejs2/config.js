'use strict';

// 各サービスへの接続設定。
// 環境変数で上書き可能（例: DB_HOST=192.168.0.10 node TestMySQL.js）。
const host = process.env.DB_HOST || 'localhost';

module.exports = {
  redis: {
    host,
    port: Number(process.env.REDIS_PORT || 6379),
  },

  // @ は URL エンコードして %40。認証情報は admin データベースで作成されるため authSource=admin。
  mongo: {
    url:
      process.env.MONGO_URL ||
      `mongodb://seigi:seigi%40123@${host}:27017/?authSource=admin`,
    dbName: process.env.MONGO_DB || 'testdb',
    collection: 'testtbl',
  },

  mysql: {
    host,
    port: Number(process.env.MYSQL_PORT || 3306),
    user: process.env.MYSQL_USER || 'root',
    password: process.env.MYSQL_PASSWORD || 'seigi@123',
    database: process.env.MYSQL_DB || 'test',
  },

  postgres: {
    host,
    port: Number(process.env.PG_PORT || 5432),
    user: process.env.PG_USER || 'postgres',
    password: process.env.PG_PASSWORD || 'seigi@123',
    database: process.env.PG_DB || 'postgres',
  },

  sqlserver: {
    server: host,
    port: Number(process.env.MSSQL_PORT || 1433),
    user: process.env.MSSQL_USER || 'SA',
    password: process.env.MSSQL_PASSWORD || 'seigi@123',
    database: process.env.MSSQL_DB || 'Northwind',
    options: {
      encrypt: false,
      trustServerCertificate: true,
    },
  },

  // 接続識別子は「ホスト[:ポート]/サービス名」形式（簡易接続）。
  // XE は oracle/init/01_setup.sql が既定 PDB(FREEPDB1) に追加する別名サービス。
  // 既定ポート(1521)以外を使う場合は ORACLE_DSN で丸ごと上書きする
  // （例: ORACLE_DSN=localhost:1522/XE）。
  oracle: {
    user: process.env.ORACLE_USER || 'SCOTT',
    password: process.env.ORACLE_PASSWORD || 'tiger',
    connectString:
      process.env.ORACLE_DSN ||
      `${host}/${process.env.ORACLE_SERVICE || 'XE'}`,
  },
};
