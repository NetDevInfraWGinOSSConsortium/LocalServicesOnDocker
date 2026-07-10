'use strict';

// SQL Server 接続テスト（mssql v11 / async-await）。
// 低レベルな tedious を直接使う代わりに、高レベルな mssql に置き換え。
const sql = require('mssql');
const config = require('./config');

async function run() {
  console.log('===== Test SQLServer =====');

  let pool;
  try {
    pool = await sql.connect({
      server: config.sqlserver.server,
      port: config.sqlserver.port,
      user: config.sqlserver.user,
      password: config.sqlserver.password,
      database: config.sqlserver.database,
      options: config.sqlserver.options,
    });

    const result = await pool.request().query('SELECT * FROM Shippers');
    console.table(result.recordset);
  } finally {
    if (pool) {
      await pool.close();
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
