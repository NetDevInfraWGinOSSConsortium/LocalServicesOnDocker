console.log("To exit, hold down [Ctrl] and press [C] twice.");

//////////
console.log("Test Postgres");

var pg = require('pg');

var pool = new pg.Pool({
  database: 'postgres',
  user: 'postgres',
  password: 'seigi@123',
  host: 'localhost',
  port: 5432,
});

pool.connect(function(err, client) {
  if (err) {
    console.log(err);
  } else {
    client.query('SELECT * FROM Shippers', function (err, obj) {
      console.log(obj.rows);
    });
  }
});