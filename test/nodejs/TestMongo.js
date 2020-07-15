console.log("To exit, hold down [Ctrl] and press [C] twice.");

//////////
console.log("Test MongoDB");

const MongoClient = require('mongodb').MongoClient;
const assert = require('assert');

/* �ڑ���URL */
// @ = %40
const cnnStr = "mongodb://seigi:seigi%40123@localhost:27017"

/**
 * �ǉ��I�v�V����
 * MongoClient�p�I�v�V�����ݒ�
 */
const cnnOpt = {
    useNewUrlParser: true,
    useUnifiedTopology: true,
}

/* �ڑ���Open */
MongoClient.connect(cnnStr, cnnOpt, (err, client) => {
  if (err) throw err;
  
  /* �ڑ��ɐ�������΃R���\�[���ɕ\�� */
  console.log('Connected successfully to server.');
  
  /* �f�[�^�x�[�X���擾 */
  const db = client.db('testdb');
  /* �e�[�u�����擾 */
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
    
    /* ���ʂ̕\�� */
    console.log(obj);
    
    /* �ڑ���Close */
    client.close();
  });
});