'use strict';

// MySQL 接続テスト（mysql2 v3 / Promise API）。
// 旧 mysql パッケージは保守終了のため mysql2 に置き換え。
const mysql = require('mysql2/promise');
const config = require('./config');

async function run() {
  console.log('===== Test MySQL =====');

  const pool = mysql.createPool({
    host: config.mysql.host,
    port: config.mysql.port,
    user: config.mysql.user,
    password: config.mysql.password,
    database: config.mysql.database,
    waitForConnections: true,
    connectionLimit: 4,
  });

  try {
    const [rows] = await pool.query('SELECT * FROM Shippers');
    console.table(rows);
  } finally {
    await pool.end();
  }
}

module.exports = { run };

if (require.main === module) {
  run().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
