-- test data part1
CREATE DATABASE Northwind
SELECT Name from sys.Databases
go

-- test data part2
USE Northwind

CREATE TABLE [dbo].[Shippers](
 [ShipperID] [int] IDENTITY(1,1) NOT NULL,
 [CompanyName] [nvarchar](40) NOT NULL,
 [Phone] [nvarchar](24) NULL,
 CONSTRAINT [PK_Shippers] PRIMARY KEY CLUSTERED 
(
  [ShipperID] ASC
))

INSERT INTO Shippers (CompanyName, Phone) VALUES('Speedy Express', '(503) 555-9831');
INSERT INTO Shippers (CompanyName, Phone) VALUES('United Package', '(503) 555-3199');
INSERT INTO Shippers (CompanyName, Phone) VALUES('Federal Shipping', '(503) 555-9930');
go


