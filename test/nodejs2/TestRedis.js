'use strict';

// Redis 接続テスト（ioredis v5 / async-await）。
const Redis = require('ioredis');
const config = require('./config');

async function run() {
  console.log('===== Test Redis =====');

  const redis = new Redis({ ...config.redis, lazyConnect: true });
  try {
    await redis.connect();

    await redis.set('key', 'value');
    const result = await redis.get('key');
    console.log('GET key =>', result); // value

    if (result !== 'value') {
      throw new Error(`unexpected value: ${result}`);
    }
  } finally {
    redis.disconnect();
  }
}

module.exports = { run };

// 単体実行された場合はそのまま走らせる。
if (require.main === module) {
  run().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
