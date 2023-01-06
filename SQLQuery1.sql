--1. Display the number of records in the [SalesPerson] table. (Schema(s) involved: Sales)
select * from Sales.SalesPerson

--2. Select both the FirstName and LastName of records from the Person table where the FirstName begins with the letter ‘B’. (Schema(s) involved: Person)

select FirstName,LastName
from Person.Person
where FirstName like 'b%'
order by FirstName asc;

--3. Select a list of FirstName and LastName for employees where Title is one of Design Engineer, Tool Designer or Marketing Assistant.(Schema(s) involved: HumanResources, Person)
SELECT Person.Person.FirstName, Person.Person.LastName, HumanResources.Employee.JobTitle
FROM Person.Person INNER JOIN
HumanResources.Employee ON Person.Person.BusinessEntityID = HumanResources.Employee.BusinessEntityID

--4. Display the Name and Color of the Product with the maximum weight. (Schema(s) involved: Production)
SELECT Name, Color, Weight 
FROM Production.Product 
where Weight is not null and Color is not null;

--5. Display Description and MaxQty fields from the Special Offer table. Some of the MaxQty values are NULL, in this case display the value 0.00 instead. (Schema(s) involved: Sales)
SELECT ISNULL(MaxQty,0.00),Description
FROM Sales.SpecialOffer

--6.Display the overall Average of the [CurrencyRate].[AverageRate] values for the exchange rate ‘USD’ to ‘GBP’ for the year 2005 i.e. FromCurrencyCode = ‘USD’ and ToCurrencyCode = ‘GBP’. Note: The field [CurrencyRate].[AverageRate] is defined as 'Average exchange rate for the day.' (Schema(s) involved: Sales)
select CurrencyRateDate,FromCurrencyCode,ToCurrencyCode,AverageRate
from Sales.CurrencyRate
where datepart(year,CurrencyRateDate)=2005 and ToCurrencyCode='GBP';

--7. Display the FirstName and LastName of records from the Person table where FirstName contains the letters ‘ss’. Display an additional column with sequential numbers for each row returned beginning at integer 1. (Schema(s) involved: Person)
SELECT ROW_NUMBER() over (order by FirstName asc) As RowNumber,FirstName,LastName
FROM Person.Person
where FirstName like '%ss%';

--8. Sales people receive various commission rates that belong to 1 of 4 bands. (Schema(s) involved: Sales)
select BusinessEntityID as SalesPersonID,CommissionPct, 'Commission Band'= Case when CommissionPct = 0 
then 'band 0'
when CommissionPct > 0 and CommissionPct <= 0.01 then 'band 1'
when CommissionPct > 0.01 and CommissionPct <= 0.015 then 'band 2'
when CommissionPct > 0.015 then 'band 3'
end from Sales.SalesPerson
order by CommissionPct

--9. Display the managerial hierarchy from Ruth Ellerbrock (person type – EM) up to CEO Ken Sanchez. Hint: use [uspGetEmployeeManagers] (Schema(s) involved: [Person], [HumanResources]) 
SELECT Person.Person.BusinessEntityID, Person.Person.FirstName, Person.Person.MiddleName, Person.Person.LastName, HumanResources.EmployeePayHistory.Rate, HumanResources.Employee.OrganizationLevel, HumanResources.Employee.JobTitle 
FROM HumanResources.Employee INNER JOIN
HumanResources.EmployeePayHistory ON HumanResources.Employee.BusinessEntityID = HumanResources.EmployeePayHistory.BusinessEntityID
INNER JOIN Person.Person ON HumanResources.Employee.BusinessEntityID = Person.Person.BusinessEntityID where Person.person.BusinessEntityID<49                      
order by Person.person.BusinessEntityID asc;

--10.  Display the ProductId of the product with the largest stock level. Hint: Use the Scalar-valued function [dbo]. [UfnGetStock]. (Schema(s) involved: Production)
SELECT ProductID,Quantity
FROM Production.ProductInventory
order by Quantity desc;

--Exercise 2:- Write separate queries using a join, a subquery, a CTE, and then an EXISTS to list all AdventureWorks customers who have not placed an order.
SELECT * FROM Sales.Customer c
LEFT OUTER JOIN Sales.SalesOrderHeader s ON c.CustomerID = s.CustomerID
WHERE s.SalesOrderID IS NULL;

WITH s AS
(   SELECT SalesOrderID
    FROM Sales.SalesOrderHeader
)
SELECT * FROM Sales.Customer c
LEFT OUTER JOIN s ON c.customerID = s.SalesOrderID
WHERE s.SalesOrderID IS NULL

SELECT * FROM Sales.Customer c
WHERE c.CustomerID in(
SELECT s.CustomerID
FROM Sales.SalesOrderHeader s
WHERE s.SalesOrderID IS NULL)

SELECT * FROM Sales.Customer c
where EXISTS(
SELECT * FROM Sales.SalesOrderHeader s
WHERE s.SalesOrderID IS NULL
AND c.customerID = s.customerID)

--Exercise3:- Show the most recent five orders that were purchased from account numbers that have spent more than $70,000 with AdventureWorks.
SELECT s.AccountNumber, s.OrderDate
FROM (
SELECT so.*,
TotalPerAccount = SUM(ss.LineTotal) OVER (PARTITION BY so.AccountNumber),
rn = ROW_NUMBER() OVER (PARTITION BY so.AccountNumber ORDER BY so.OrderDate DESC)
FROM Sales.SalesOrderHeader so
JOIN Sales.SalesOrderDetail ss ON so.SalesOrderID = ss.SalesOrderID
) s
WHERE s.TotalPerAccount > 70000
AND s.rn <= 5;

--Exercise 4:- Create a function that takes as inputs a SalesOrderID, a Currency Code, and a date, and returns a table of all the SalesOrderDetail rows for that Sales Order including Quantity, ProductID, UnitPrice, and the unit price converted to the target currency based on the end of day rate for the date provided. Exchange rates can be found in the Sales.CurrencyRate table. ( Use AdventureWorks)

GO
CREATE FUNCTION NewUnitPrices ( @salesOrderId int, @currencyCode nvarchar(20), @date date )
RETURNS
TABLE AS RETURN 
( SELECT OrderQty , ProductID, Unitprice * ( SELECT EndOfdayRate FROM Sales.CurrencyRate 
WHERE ModifiedDate = @date AND ToCurrencyCode = @currencyCode ) 
AS UnitPrice FROM Sales.SalesOrderDetail WHERE SalesOrderID = @salesOrderId )
GO 
SELECT * FROM NewUnitPrices (43659,'AUD','2005-07-01')
GO

--Exercise 5:- Write a Procedure supplying name information from the Person.Person table and accepting a filter for the first name. Alter the above Store Procedure to supply Default Values if user does not enter any value.( Use AdventureWorks)

CREATE PROCEDURE GetFirstName

@FirstName varchar(50)
AS
IF @FirstName is null BEGIN;
SET @FirstName='ken'
END
SELECT * FROM Person.Person
WHERE FirstName =@FirstName
GO

--Alternative
CREATE PROCEDURE AlternateGetFname
@FirstName varchar(50)
AS
SELECT * FROM Person.Person
WHERE FirstName=ISNULL(@FirstName,'ken')
GO

exec AlternateGetFname @FirstName = null

--Exercise 6:- Write a trigger for the Product table to ensure the list price can never be raised more than 15 Percent in a single change. Modify the above trigger to execute its check code only if the ListPrice column is updated (Use AdventureWorks Database)

CREATE TRIGGER [Production].[trgLimitPriceChanges]
ON [Production].[Product]
FOR UPDATE
AS
IF EXISTS (
SELECT * FROM inserted i
JOIN deleted d
ON i.ProductID = d.ProductID
WHERE i.ListPrice > (d.ListPrice * 1.15)
)
BEGIN
RAISERROR('Price increase may not be greater than 15 percent.
Transaction Failed.',16,1)
ROLLBACK TRAN
END
GO



ALTER TRIGGER [Production].[trgLimitPriceChanges]
ON [Production].[Product]
FOR UPDATE
AS
IF UPDATE(ListPrice)
BEGIN
IF EXISTS
(
SELECT *
FROM inserted i
JOIN deleted d
ON i.ProductID = d.ProductID
WHERE i.ListPrice > (d.ListPrice * 1.15)
)

BEGIN RAISERROR('Price increase may not be greater than 15 percent.
Transaction Failed.',16,1)
ROLLBACK TRAN
END
END
GO

UPDATE Production.Product 
SET ListPrice = 1
WHERE Name = 'Bearing ball'