'use strict';

// 全サービスのテストを順に実行し、結果サマリを表示する。
// いずれか失敗すれば終了コード 1 で終了する。
const tests = [
  ['Redis', './TestRedis'],
  ['MongoDB', './TestMongo'],
  ['MySQL', './TestMySQL'],
  ['Postgres', './TestPostgres'],
  ['SQLServer', './TestSQLServer'],
];

async function main() {
  const results = [];

  for (const [name, modPath] of tests) {
    try {
      await require(modPath).run();
      results.push({ name, status: 'OK' });
    } catch (err) {
      console.error(`[${name}] FAILED:`, err.message);
      results.push({ name, status: 'NG', error: err.message });
    }
    console.log('');
  }

  console.log('===== Summary =====');
  console.table(results);

  const failed = results.filter((r) => r.status === 'NG');
  process.exit(failed.length > 0 ? 1 : 0);
}

main();
