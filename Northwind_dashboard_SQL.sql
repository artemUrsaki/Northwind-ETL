-- 1. Graf
SELECT p.ProductCategory, 
       SUM(od.ProductQuantity) AS quantity
FROM fact_orderdetails od
JOIN dim_products p ON od.ProductID = p.ProductID
GROUP BY p.ProductCategory
ORDER BY quantity DESC;

-- 2. Graf
SELECT d.month, AVG(od.ProductPrice) AS price
FROM fact_orderdetails od
JOIN dim_date d ON od.DateID = d.DateID
WHERE d.year = '1996'
GROUP BY d.month
ORDER BY d.month;

-- 3. Graf
SELECT p.SupplierName, 
       SUM(od.ProductQuantity * od.ProductPrice) AS sales
FROM fact_orderdetails od
JOIN dim_products p ON od.ProductID = p.ProductID
GROUP BY p.SupplierName
ORDER BY sales DESC;

-- 4. Graf
SELECT 
    c.CustomerName, 
    SUM(od.ProductQuantity * od.ProductPrice) AS sales
FROM fact_orderdetails od
JOIN dim_customers c ON od.CustomerID = c.CustomerID
GROUP BY c.CustomerID, c.CustomerName
ORDER BY sales DESC
LIMIT 10;

-- 5. Graf
SELECT 
    e.FullName AS EmployeeName,
    SUM(od.ProductQuantity * od.ProductPrice) AS sales
FROM fact_orderdetails od
JOIN dim_employees e ON od.EmployeeID = e.EmployeeID
GROUP BY e.EmployeeID, e.FullName
ORDER BY sales;