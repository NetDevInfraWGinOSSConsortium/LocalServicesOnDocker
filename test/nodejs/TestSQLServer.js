console.log("To exit, hold down [Ctrl] and press [C] twice.");

//////////
console.log("Test SQLServer");

var Connection = require('tedious').Connection;
var Request = require('tedious').Request;

var content = [];
var connection = new Connection({
  server: 'localhost',
  authentication: {
      type: 'default',
      options: {
          userName: 'SA',
          password: 'seigi@123'
      }
  },
  options: {
      encrypt: false,
      database: 'Northwind'
  }
});

connection.on('connect', function(err) {
  if (err) {
    console.log(err);
  } else {
    executeStatement();
  }
});

function executeStatement() {
  var request = new Request('SELECT * FROM Shippers', function (err) {
    if (err) {
      console.log(err);
    } else {
      //...
    }
  });
  
  // ハンドラ設定
  
  // ハンドラ(row)
  request.on('row', function (row) {
    var result = {};
    row.forEach(function (column) {
      if (column.value === null) {
        result[column.metadata.colName] = 'NULL';
      } else {
        result[column.metadata.colName] = column.value;
      }
    });
    content.push(result);
  });
      
  // ハンドラ(requestCompleted)
  request.on('requestCompleted', function () {
    console.log(content);
    connection.close();
  });
  
  // ステートメントを実行
  connection.execSql(request);
}
