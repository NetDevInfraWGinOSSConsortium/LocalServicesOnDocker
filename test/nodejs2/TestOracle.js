'use strict';

// Oracle Database 接続テスト（node-oracledb v7 / Thin モード）。
// Thin モードが既定のため、Oracle Client（Instant Client）のインストールは不要。
const oracledb = require('oracledb');
const config = require('./config');

async function run() {
  console.log('===== Test Oracle =====');

  let conn;
  try {
    conn = await oracledb.getConnection({
      user: config.oracle.user,
      password: config.oracle.password,
      connectString: config.oracle.connectString,
      // node-oracledb の connectTimeout は「秒」指定。
      connectTimeout: config.connectTimeoutSec,
    });

    // 既定では行が配列で返るため、console.table 用にオブジェクト形式を指定する。
    const result = await conn.execute('SELECT * FROM Shippers', [], {
      outFormat: oracledb.OUT_FORMAT_OBJECT,
    });
    console.table(result.rows);
  } finally {
    if (conn) {
      await conn.close();
    }
  }
}

module.exports = { run };

if (require.main === module) {
  run().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
