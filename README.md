# ETL proces datasetu Northwind
<p>Tento repozitár obsahuje implementáciu ETL procesu v Snowflake pre analýzu dát z databázy <b>NorthWind</b>. Projekt sa zameriava na skúmanie obchodného správania zákazníkov a ich nákupných preferencií na základe údajov o objednávkach, produktoch a zákazníkoch. Výsledný dátový model umožňuje multidimenzionálnu analýzu a vizualizáciu kľúčových obchodných metrík.</p>
<hr>
<p>1. Úvod a popis zdrojových dát</p>
<p>
Cieľom semestrálneho projektu je analyzovať dáta týkajúce sa zákazníkov, produktov a objednávok. Táto analýza umožňuje identifikovať obchodné trendy, najpredávanejšie produkty a správanie zákazníkov.
</p>
<p>
Zdrojové dáta pochádzajú z Kaggle datasetu dostupného <a href="https://www.kaggle.com/datasets/cleveranjosqlik/csv-northwind-database">tu</a>. Dataset obsahuje sedem hlavných tabuliek:
</p>
<ul>
  <li><code>categories</code></li>
  <li><code>products</code></li>
  <li><code>suppliers</code></li>
  <li><code>orders</code></li>
  <li><code>shippers</code></li>
  <li><code>employees</code></li>
  <li><code>customers</code></li>
</ul>
<p>Účelom ETL procesu bolo tieto dáta pripraviť, transformovať a sprístupniť pre viacdimenzionálnu analýzu.</p>
<hr>
<h3>1.1 Dátová architektúra</h3>
<h3>ERD diagram</h3>
<p>Surové dáta sú usporiadané v relačnom modeli, ktorý je znázornený na <b>entitno-relačnom diagrame (ERD)</b>:</p>
<p align="center">
  <img src="erd_schema.png" alt="ERD Schema">
  <br>
  <em>Obrázok 1 Entitno-relačná schéma AmazonBooks</em>
</p>

---
## **2 Dimenzionálny model**

Navrhnutý bol **hviezdicový model (star schema)**, pre efektívnu analýzu kde centrálny bod predstavuje faktová tabuľka **`fact_orderdetails`**, ktorá  je prepojená s nasledujúcimi dimenziami:
- **`dim_products`**: Obsahuje podrobné informácie o produktoch (name, category, supplier, country, city).
- **`dim_shippers`**: Obsahuje údaje o zasielateľoch (shipper name).
- **`dim_employees`**: Obsahuje údaje o zamestnancoch (first name, last name, year of birth).
- **`dim_customers`**: Obsahuje demografické údaje o zákazníkoch (name, city, country).
- **`dim_date`**: Zahrňuje informácie o dátumoch objednavok (deň, mesiac, rok, štvrťrok).

Štruktúra hviezdicového modelu je znázornená na diagrame nižšie. Diagram ukazuje prepojenia medzi faktovou tabuľkou a dimenziami, čo zjednodušuje pochopenie a implementáciu modelu.

<p align="center">
  <img src="star_schema.png" alt="Star Schema">
  <br>
  <em>Obrázok 2 Schéma hviezdy pre AmazonBooks</em>
</p>

---
## **3. ETL proces v Snowflake**
ETL proces pozostával z troch hlavných fáz: `extrahovanie` (Extract), `transformácia` (Transform) a `načítanie` (Load). Tento proces bol implementovaný v Snowflake s cieľom pripraviť zdrojové dáta zo staging vrstvy do viacdimenzionálneho modelu vhodného na analýzu a vizualizáciu.

---
### **3.1 Extract (Extrahovanie dát)**

Dáta vo formáte .csv boli do Snowflake nahraté cez interné stage úložisko s názvom my_stage, ktoré bolo vytvorené pomocou:

```sql
CREATE OR REPLACE STAGE my_stage;
```

Odtiaľ boli importované do staging tabuliek pre jednotlivé entity, ako sú produkty, kategórie či dodávatelia, využitím príkazu COPY INTO. Príklad:

```sql
COPY INTO products_staging
FROM @my_stage/products.csv
FILE_FORMAT = (TYPE = 'CSV' FIELD_OPTIONALLY_ENCLOSED_BY = '"' SKIP_HEADER = 1);
```

---
### **3.2 Transform (Transformácia dát)**

V tejto fáze boli dáta zo staging tabuliek vyčistené, transformované a obohatené. Hlavným cieľom bolo pripraviť dimenzie a faktovú tabuľku, ktoré umožnia jednoduchú a efektívnu analýzu.

### Vytváranie dimenzií**

`dim_products` bola vytvorená spojením tabuliek `products_staging`, `categories_s-+taging` a `suppliers_staging`, čo umožnilo denormalizáciu dát. Tabuľka obsahuje názvy produktov, kategórie, mená dodávateľov a ich lokality (krajina, mesto). Typ dimenzie: **SCD1**. Tento typ bol zvolený, pretože sa môžu meniť informácie o dodávateľoch (napr. názov firmy), pričom nie je potrebné uchovávať historické záznamy.
 ```sql
 CREATE TABLE dim_products AS
SELECT DISTINCT
    p.ProductID,
    p.ProductName,
    c.CategoryName AS ProductCategory,
    s.SupplierName,
    s.Country,
    s.City
FROM products_staging p
JOIN categories_staging c ON p.CategoryID = c.CategoryID
JOIN suppliers_staging s ON p.SupplierID = s.SupplierID;
```

`dim_shippers` obsahuje jedinečné informácie o zasielateľoch, vrátane ich identifikátorov a názvov. Pri transformacii tabulky `shippers_staging` bol vynechany stĺpec `phone`. Typ dimenzie: **SCD0**. Tento typ bol zvolený, pretože údaje o zasielateľoch, ako sú ich názvy, sa považujú za nemenné a nie je potrebné sledovať historické zmeny.
```sql
CREATE TABLE dim_shippers AS
SELECT DISTINCT
    s.ShipperID,
    s.ShipperName
FROM shippers_staging s;
```

`dim_employees` obsahuje údaje o zamestnancoch, ako sú ich mená, priezviská a rok narodenia. Pri transformacii tabulky `employees_staging` boli vynechané stĺpce `photo` a `note`. Typ dimenzie: **SCD1**. Tento typ bol zvolený, pretože údaje o zamestnancoch, ako sú mená, sa môžu meniť (napr. v prípade zmeny mena), ale historické záznamy nie sú potrebné.
```sql
CREATE TABLE dim_employees AS
SELECT DISTINCT
    e.EmployeeID,
    e.FirstName,
    e.LastName,
    YEAR(e.BirthDate) AS BirthYear
FROM employees_staging e;
```

`dim_customers` obsahuje informácie o zákazníkoch vrátane mena, mesta a krajiny. Typ dimenzie: **SCD1**. Tento typ bol zvolený, pretože údaje o zákazníkoch, ako sú názvy alebo miesta pobytu, sa môžu meniť, ale nie je potrebné uchovávať historické záznamy.
```sql
CREATE TABLE dim_customers AS 
SELECT DISTINCT
    c.CustomerID,
    c.CustomerName,
    c.City,
    c.Country
FROM customers_staging c;
```

`dim_date` obsahuje informácie o dátumoch, vrátane odvodených údajov, ako je deň, mesiac, rok a štvrťrok. Každý dátum má jedinečný DateID. Typ dimenzie: **SCD0**.
```sql
CREATE TABLE dim_date AS
SELECT DISTINCT
    ROW_NUMBER() OVER (ORDER BY CAST(OrderDate AS DATE)) AS DateID,
    CAST(OrderDate AS DATE) AS date,
    DATE_PART(year, OrderDate) AS year,
    DATE_PART(month, OrderDate) AS month,
    DATE_PART(day, OrderDate) AS day,
    DATE_PART(quarter, OrderDate) AS quarter   
FROM orders_staging
GROUP BY CAST(OrderDate AS DATE), 
    DATE_PART(day, OrderDate),  
    DATE_PART(month, OrderDate), 
    DATE_PART(year, OrderDate), 
    DATE_PART(quarter, OrderDate);
```

`fact_orderdetails` je faktová tabuľka, ktorá obsahuje informácie o objednávkach, ako sú ceny produktov, množstvo, a prepojenia na dimenzie: produkty, zamestnanci, zákazníci, zasielatelia a dátumy.
```sql
CREATE TABLE fact_orderdetails AS
SELECT
    od.OrderDetailID,
    ps.Price AS ProductPrice,
    od.Quantity AS ProductQuantity,
    od.OrderID,
    p.ProductID, 
    e.EmployeeID, 
    c.CustomerID, 
    s.ShipperID, 
    d.DateID
FROM orderdetails_staging od JOIN orders_staging o ON od.OrderID = o.OrderID
JOIN products_staging ps ON od.ProductID = ps.ProductID
JOIN dim_products p ON od.ProductID = p.ProductID
JOIN dim_employees e ON o.EmployeeID = e.EmployeeID
JOIN dim_customers c ON o.CustomerID = c.CustomerID
JOIN dim_shippers s ON o.ShipperID = s.ShipperID
JOIN dim_date d ON CAST(o.OrderDate as DATE) = d.date;
```