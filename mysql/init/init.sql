-- Change authentication plugins for root.
ALTER USER 'root' IDENTIFIED WITH mysql_native_password BY 'seigi@123';
FLUSH PRIVILEGES;

-- Create table and insert data.
USE test;

DROP TABLE IF EXISTS Shippers;

CREATE TABLE Shippers (
  ShipperID INTEGER UNSIGNED NOT NULL AUTO_INCREMENT,
  CompanyName VARCHAR(40) NOT NULL,
  Phone VARCHAR(24) NOT NULL,
  PRIMARY KEY (ShipperID)
);

INSERT INTO Shippers (CompanyName, Phone) VALUES('Speedy Express', '(503) 555-9831');
INSERT INTO Shippers (CompanyName, Phone) VALUES('United Package', '(503) 555-3199');
INSERT INTO Shippers (CompanyName, Phone) VALUES('Federal Shipping', '(503) 555-9930');