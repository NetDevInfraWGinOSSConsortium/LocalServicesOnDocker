'use strict';

// PostgreSQL 接続テスト（pg v8 / async-await）。
const { Pool } = require('pg');
const config = require('./config');

async function run() {
  console.log('===== Test Postgres =====');

  const pool = new Pool({
    host: config.postgres.host,
    port: config.postgres.port,
    user: config.postgres.user,
    password: config.postgres.password,
    database: config.postgres.database,
  });

  try {
    const result = await pool.query('SELECT * FROM Shippers');
    console.table(result.rows);
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
