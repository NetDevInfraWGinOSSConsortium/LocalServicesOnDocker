'use strict';

// MongoDB 接続テスト（mongodb v6 / async-await）。
// v4 以降は useNewUrlParser / useUnifiedTopology は不要（削除）。
const { MongoClient } = require('mongodb');
const config = require('./config');

async function run() {
  console.log('===== Test MongoDB =====');

  const client = new MongoClient(config.mongo.url);
  try {
    await client.connect();
    console.log('Connected successfully to server.');

    const db = client.db(config.mongo.dbName);
    const tbl = db.collection(config.mongo.collection);

    // Delete
    const del = await tbl.deleteMany({});
    console.log(`${del.deletedCount} document(s) deleted`);

    // Insert
    await tbl.insertMany([
      { name: 'Dan', age: 18 },
      { name: 'Bob', age: 22 },
      { name: 'John', age: 30 },
    ]);

    // Select
    const docs = await tbl.find({}).toArray();
    console.table(docs.map(({ _id, ...rest }) => rest));
  } finally {
    await client.close();
  }
}

module.exports = { run };

if (require.main === module) {
  run().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
