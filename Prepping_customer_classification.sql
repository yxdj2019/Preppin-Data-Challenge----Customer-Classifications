create database customer_classification;
use customer_classification;

-- add year column
Alter TABLE Orders add order_Year int;
Update Orders set order_Year=YEAR(`Order Date`) ;

-- add order_flag column
Alter TABLE Orders add order_flag int;
Update Orders set order_flag=1 ;


-- create table with unique customer name and first purchase year
CREATE TABLE IF NOT EXISTS unique_table AS SELECT `Customer Name`, MIN(order_Year)  as first_purchase_year
FROM
    orders
GROUP BY `Customer Name`;

-- add u_key to join with temp below
Alter table unique_table add u_key int;
UPDATE unique_table 
SET 
    u_key = 0;
    

-- Create temp table include all years from 2018-2021
CREATE TABLE IF NOT EXISTS Temp_year (
    t_key INT,
    t_year INT
);

Insert into Temp_year
values (0,2018),
(0,2019),
(0,2020),
(0,2021);

-- join Temp_year with unique_table on key
CREATE TABLE IF NOT EXISTS unique_customer_year AS SELECT u.`Customer Name`, u.first_purchase_year, t.t_year AS year FROM
    unique_table AS u
        JOIN
    Temp_year AS t ON u.u_key = t.t_key;

DROP TABLE IF EXISTS unique_table;
DROP TABLE IF EXISTS Temp_year;

-- join unique_customer_year with orders on customer name and year
-- create Output_unique table where each customer has the order information in each year after first purchase year 
DROP TABLE IF EXISTS Output_unique;
CREATE TABLE IF NOT EXISTS Output_unique
AS
SELECT DISTINCT
    u.*, o.order_flag
FROM
    unique_customer_year AS u
        LEFT JOIN
    orders AS o ON u.`customer Name` = o.`customer Name`
        AND u.year = o.order_year
ORDER BY u.`customer Name`, u.year;

DROP TABLE IF EXISTS unique_customer_year;

-- remove rows where year <first purchase year
DELETE FROM Output_unique 
WHERE
    year < first_purchase_year;

-- set order_flag that is null to 0
UPDATE Output_unique 
SET 
    order_flag = 0
WHERE
    order_flag IS NULL;
    
-- calculate last_year_order_flag
-- The LAG() function is a window function that allows you to look back a number of rows and access data of that row from the current row.
DROP TABLE IF EXISTS Output_unique_customer_year;
CREATE TABLE Output_unique_customer_year as
SELECT *,
    LAG(order_flag, 1) OVER (
        PARTITION BY `customer Name`
        ORDER BY year
    ) as last_year_order_flag
    from Output_unique;
    
    
-- ADD customer_year_classifcation
ALTER TABLE Output_unique_customer_year ADD customer_year_classifcation text;
UPDATE Output_unique_customer_year
SET customer_year_classifcation=
(CASE
	when first_purchase_year=year Then 'New'
	when order_flag=0 Then 'Sleeping'
	when order_flag=1 and last_year_order_flag=1 Then 'Consistent'
	else 'Returning'
END);


-- ------------ ADD YOY_difference -----------------
-- ------------------------------------------------

-- create YOY_difference_TABLE includes YOY_difference information
CREATE TABLE YOY_difference_TABLE AS
SELECT 
    *,
    LAG(number_of_customers, 1) OVER (
        PARTITION BY first_purchase_year
        ORDER BY year
    ) as number_of_customers_shift
FROM
(SELECT first_purchase_year, year, SUM(order_flag) AS number_of_customers
FROM Output_unique_customer_year
GROUP BY first_purchase_year, year
) AS temp;

--  CALCULATE YOY_difference FOR EACH COHORT IN EACH YEAR
ALTER TABLE YOY_difference_TABLE ADD YOY_difference INT;
UPDATE YOY_difference_TABLE
SET
YOY_difference=number_of_customers-number_of_customers_shift;


-- JOIN Output_unique_customer_year WITH YOY_difference_TABLE
CREATE TABLE Output_forTableau_sql AS
SELECT O.*, Y.YOY_difference
FROM Output_unique_customer_year AS O
JOIN YOY_difference_TABLE AS Y
ON O.first_purchase_year=Y.first_purchase_year AND O.year=Y.year
