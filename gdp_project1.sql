SET SQL_SAFE_UPDATES = 0;

/* -----------------------------------FIRST STEPS------------------------------------------- */

-- Create a database called "honei_1" if it doesn't already exist
-- The IF NOT EXISTS clause ensures that no error is thrown if the database already exists
CREATE DATABASE IF NOT EXISTS honei_1;

-- Select the created database to use
USE honei_1;

-- Create a table called "continent_map" with two columns:
-- "country_code" and "continent_code", both allowing up to 10 characters
-- The length of 10 is chosen to accommodate ISO country codes and potential variations
CREATE TABLE continent_map (
    country_code VARCHAR(10),
    continent_code VARCHAR(10)
);

-- Create a table called "continents" with two columns:
-- "continent_code" and "continent_name", allowing up to 50 characters for the name
-- 50 characters should be sufficient to store the full names of continents
CREATE TABLE continents (
    continent_code VARCHAR(10),
    continent_name VARCHAR(50)
);

-- Create a table called "countries" with two columns:
-- "country_code" and "country_name", allowing up to 100 characters for the name
-- 100 characters should be sufficient to store the full names of countries
CREATE TABLE countries (
    country_code VARCHAR(10),
    country_name VARCHAR(100)
);

-- Create a table called "per_capita" with three columns:
-- "country_code", "year", and "gdp_per_capita"
-- The FLOAT type is used for gdp_per_capita to handle decimal values
CREATE TABLE per_capita (
    country_code VARCHAR(10),
    year INT,
    gdp_per_capita FLOAT
);


/* -------------------------------------------CLEANING DATA----------------------------------------------*/


-- Step 1: Replace NULL values in "country_code" with 'N/A' for better data consistency
UPDATE continent_map
SET country_code = 'N/A'
WHERE country_code IS NULL;


-- Step 2: Ensure NULL values in continents and continent_map are treated as 'North America'
UPDATE continents
SET continent_code = 'NA'
WHERE continent_code IS NULL;

UPDATE continent_map
SET continent_code = 'NA'
WHERE continent_code IS NULL;

-- Step 3: Calculate the average GDP per capita excluding NULLs
-- Compute the average GDP per capita and store it in a variable
SELECT AVG(gdp_per_capita) 
INTO @average_gdp 
FROM per_capita 
WHERE gdp_per_capita IS NOT NULL;

-- Replace NULL values in "gdp_per_capita" with the calculated average
-- This ensures that all GDP per capita values are non-NULL, facilitating accurate analyses
UPDATE per_capita
SET gdp_per_capita = @average_gdp
WHERE gdp_per_capita IS NULL;


-- Step 4: Create a consolidated view
-- Create a view combining data from multiple tables for easier access
-- Views are useful for simplifying complex queries and ensuring consistent data representation
CREATE OR REPLACE VIEW consolidated_view AS
SELECT 
    pc.country_code, 
    c.country_name, 
    cm.continent_code, 
    con.continent_name, 
    pc.year, 
    pc.gdp_per_capita
FROM 
    per_capita pc
JOIN 
    countries c ON pc.country_code = c.country_code
JOIN 
    continent_map cm ON pc.country_code = cm.country_code
JOIN 
    continents con ON cm.continent_code = con.continent_code;



/* -------------------------------------------PROPOSED EXERCISES----------------------------------------------*/

-- QUESTION 1
-- List all country codes in the continent_map table that appear more than once, alphabetically
-- Display "N/A" for countries with no code first
--
-- Using a CTE (WITH clause) to create a temporary result set for easier and cleaner querying
WITH duplicate_country_codes AS (
    SELECT country_code, COUNT(*) as count
    FROM continent_map
    GROUP BY country_code
    HAVING COUNT(*) > 1
)
SELECT 
    CASE 
        WHEN dcc.country_code = 'N/A' THEN 'N/A' -- Ensure 'N/A' is displayed as is
        ELSE dcc.country_code 
    END as country_code,
    COALESCE(c.country_name, 'Unknown') AS country_name, -- Use 'Unknown' for missing country names
    dcc.count
FROM 
    duplicate_country_codes dcc
LEFT JOIN 
    countries c ON dcc.country_code = c.country_code -- LEFT JOIN to include all duplicate country codes even if no match in countries
ORDER BY 
    CASE 
        WHEN dcc.country_code = 'N/A' THEN 0 -- Order 'N/A' first
        ELSE 1 
    END, 
    dcc.country_code;

-- QUESTION 2
-- Calculate the year-over-year % GDP per capita growth from 2011 to 2012 and list the top 10 countries
--
-- Using a CTE (WITH clause) to create a temporary result set for easier and cleaner querying
WITH gdp_growth AS (
    SELECT 
        a.country_code,
        b.year AS year,
        (b.gdp_per_capita - a.gdp_per_capita) / a.gdp_per_capita * 100 AS growth -- Calculate growth percentage
    FROM 
        per_capita a
        JOIN per_capita b ON a.country_code = b.country_code
    WHERE 
        a.year = 2011 AND b.year = 2012
)
SELECT 
    c.country_name, 
    g.year,
    g.growth
FROM 
    gdp_growth g
JOIN 
    countries c ON g.country_code = c.country_code -- Join to get country names
ORDER BY 
    g.growth DESC -- Order by growth percentage in descending order
LIMIT 10; -- Limit to top 10 countries

-- QUESTION 3
-- Calculate percentage share of GDP per capita for North America, Europe, and Rest of the World
--
-- Step 1: Using CTEs (WITH clauses) to create temporary result sets for easier and cleaner querying
SELECT 
    continent_name, 
    SUM(gdp_per_capita) AS total_gdp_per_capita 
FROM 
    consolidated_view
WHERE 
    year = 2012
GROUP BY 
    continent_name;

-- Step 2: Calculate percentage share of GDP per capita for North America, Europe, and Rest of the World
WITH total_gdp AS (
    SELECT 
        continent_name, 
        SUM(gdp_per_capita) AS total_gdp_per_capita
    FROM 
        consolidated_view
    WHERE 
        year = 2012
    GROUP BY 
        continent_name
), gdp_summary AS (
    SELECT 
        continent_name, 
        total_gdp_per_capita,
        SUM(total_gdp_per_capita) OVER () AS global_gdp_per_capita
    FROM 
        total_gdp
)
SELECT 
    continent_name,
    total_gdp_per_capita,
    (total_gdp_per_capita / global_gdp_per_capita) * 100 AS percentage_share
FROM 
    gdp_summary
WHERE 
    continent_name IN ('North America', 'Europe')
UNION
SELECT 
    'Rest of the World' AS continent_name,
    SUM(total_gdp_per_capita) AS total_gdp_per_capita,
    (SUM(total_gdp_per_capita) / (SELECT global_gdp_per_capita FROM gdp_summary LIMIT 1)) * 100 AS percentage_share
FROM 
    gdp_summary
WHERE 
    continent_name NOT IN ('North America', 'Europe');

-- QUESTION 4
-- Calculate the average GDP per capita for each continent from 2004 to 2012
--
-- Using JOINs to combine necessary tables and GROUP BY to calculate averages per continent and year
SELECT 
    c.continent_name,
    p.year,
    AVG(p.gdp_per_capita) AS average_gdp_per_capita
FROM 
    per_capita p
    JOIN continent_map cm ON p.country_code = cm.country_code
    JOIN continents c ON cm.continent_code = c.continent_code
WHERE 
    p.year BETWEEN 2004 AND 2012
GROUP BY 
    c.continent_name,
    p.year
ORDER BY 
    c.continent_name,
    p.year;
    
-- QUESTION 5    
-- Calculate the median GDP per capita for each continent from 2004 to 2012
--
-- Using ROW_NUMBER and COUNT for median calculation to handle large dataset
WITH ranked_gdp AS (
    SELECT
        c.continent_name,
        p.year,
        p.gdp_per_capita,
        ROW_NUMBER() OVER (PARTITION BY c.continent_name, p.year ORDER BY p.gdp_per_capita) AS row_num, -- Assign row numbers
        COUNT(*) OVER (PARTITION BY c.continent_name, p.year) AS total_count -- Count total rows
    FROM 
        per_capita p
    JOIN 
        continent_map cm ON p.country_code = cm.country_code
    JOIN 
        continents c ON cm.continent_code = c.continent_code
    WHERE 
        p.year BETWEEN 2004 AND 2012
)
-- Calculate median by averaging middle values for odd/even counts
SELECT
    continent_name,
    year,
    AVG(gdp_per_capita) AS median_gdp_per_capita
FROM (
    SELECT
        continent_name,
        year,
        gdp_per_capita,
        total_count,
        row_num
    FROM
        ranked_gdp
    WHERE
        row_num IN (FLOOR((total_count + 1) / 2), CEIL((total_count + 1) / 2))
) AS median_values
GROUP BY
    continent_name,
    year
ORDER BY
    continent_name,
    year;

    
    
    





