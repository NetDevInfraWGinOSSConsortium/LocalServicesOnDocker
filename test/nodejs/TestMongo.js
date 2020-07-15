console.log("To exit, hold down [Ctrl] and press [C] twice.");

//////////
console.log("Test MongoDB");

const MongoClient = require('mongodb').MongoClient;
const assert = require('assert');

/* 接続先URL */
// @ = %40
const cnnStr = "mongodb://seigi:seigi%40123@localhost:27017"

/**
 * 追加オプション
 * MongoClient用オプション設定
 */
const cnnOpt = {
    useNewUrlParser: true,
    useUnifiedTopology: true,
}

/* 接続をOpen */
MongoClient.connect(cnnStr, cnnOpt, (err, client) => {
  if (err) throw err;
  
  /* 接続に成功すればコンソールに表示 */
  console.log('Connected successfully to server.');
  
  /* データベースを取得 */
  const db = client.db('testdb');
  /* テーブルを取得 */
  const tbl = db.collection('testtbl');
  
  /* Delete */
  tbl.deleteMany({}, function(err, obj) {
    if (err) throw err;
    console.log(obj.result.n + " document(s) deleted");
  });
  
  /* Insert */
  tbl.insertMany([{ name: 'Dan', age: 18 }, { name: 'Bob', age: 22 }, { name: 'John', age: 30 }]);
  
  /* Select */
  tbl.find({}).toArray(function(err, obj) {
    if (err) throw err;
    
    /* 結果の表示 */
    console.log(obj);
    
    /* 接続をClose */
    client.close();
  });
});