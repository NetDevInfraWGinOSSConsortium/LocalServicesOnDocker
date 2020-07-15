console.log("To exit, hold down [Ctrl] and press [C] twice.");

//////////
console.log("Test MySQL");

var mysql = require("mysql");
var pool = mysql.createPool({
  database: 'test',
  user: 'root',
  password: 'seigi@123',
  host: 'localhost',
  port: 3306,
});

pool.getConnection(function(err, client) {
  if (err) {
    console.log(err);
  } else {
    client.query('SELECT * FROM Shippers', function (error, obj, fields) {
      console.log(obj);
    });
  }
});