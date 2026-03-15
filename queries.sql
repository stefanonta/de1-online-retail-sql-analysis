-- verify number of null values in the dataset fields
SELECT 
    SUM(CASE WHEN invoice_no IS NULL THEN 1 ELSE 0 END) AS null_invoice_no,
    SUM(CASE WHEN stock_code IS NULL THEN 1 ELSE 0 END) AS null_stock_code,
    SUM(CASE WHEN description IS NULL THEN 1 ELSE 0 END) AS null_description,
    SUM(CASE WHEN quantity IS NULL THEN 1 ELSE 0 END) AS null_quantity,
    SUM(CASE WHEN invoice_date IS NULL THEN 1 ELSE 0 END) AS null_invoice_date,
    SUM(CASE WHEN unit_price IS NULL THEN 1 ELSE 0 END) AS null_unit_price,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END) AS null_country
FROM retail;

-- Query #1
/*
For each country, rank customers by their total spending. 
Show the country, customer_id, total spent, and their rank within that country.
*/

/* 
Note:
On a preemptive check, I notices customer_id has 135080 null values
hence those will be excluded as they provide no valuable info for the rank
*/
WITH spending AS (
	-- total spending by country and customer_id
	SELECT 
		country,
		customer_id,
		SUM((quantity * unit_price)) AS total_spend
	FROM retail
	-- exclude null customer_id values as it is noise
	WHERE customer_id IS NOT NULL
	GROUP BY country, customer_id
	)
SELECT
	*,
	-- DENSE_RANK() does not leave any gap in the ranking if ties are present
	DENSE_RANK() OVER(PARTITION BY country ORDER BY total_spend DESC) AS customer_rank
FROM spending;

-- Query #2
/*
For the top 5 customers globally (by total spending), show their rank, 
invoice date, product description, quantity ordered, and unit price. 
Rank the invoices for each customer by date in descending order (most recent first).
*/

WITH top5_customers AS(
	SELECT
		customer_id,
		SUM(quantity * unit_price) AS total_spend,
		-- If two customers rank equally they would both be included as top 5 potentially returning more than 5 top5 customer_id
		DENSE_RANK() OVER(ORDER BY SUM(quantity * unit_price) DESC) AS customer_global_rank
	FROM retail
	WHERE customer_id IS NOT NULL
	GROUP BY customer_id
)
SELECT 
	t5.customer_id,
	t5.customer_global_rank,
	r.invoice_date,
	-- Invoice rank (1 = most recent, 2 = next oldest, etc)
	DENSE_RANK() OVER(PARTITION BY t5.customer_id ORDER BY r.invoice_date DESC, r.invoice_no) AS invoice_rank,
	r.description,
	r.quantity,
	r.unit_price
FROM top5_customers AS t5
JOIN retail AS r 
ON (t5.customer_id = r.customer_id) AND (r.customer_id IS NOT NULL)
WHERE customer_global_rank IN (1,2,3,4,5)
ORDER BY t5.customer_id, invoice_rank;

-- Query #3
/*
Find each customer's very first purchase. Show the customer_id, the invoice date of their first purchase,
the product they bought, and the quantity.
If a customer made multiple purchases on the same day, show all line items from that first day."
*/

WITH purchases AS (
	SELECT
		customer_id,
		invoice_date,
		description,
		quantity,
		-- RANK() or DENSE_RANK() will yeld same result as only care about the first purchase (#1)
		RANK() OVER(PARTITION BY customer_id ORDER BY DATE_TRUNC('day',invoice_date)) AS purchase_rank
	FROM retail
	WHERE customer_id IS NOT NULL
)
SELECT
	customer_id,
	invoice_date,
	description,
	quantity
FROM purchases
WHERE purchase_rank = 1
ORDER BY invoice_date;

-- Query #4
/*
For each country, find the top 3 best-selling products by total quantity sold. 
Show the country, product description, total quantity sold, and their rank within that country. 
Exclude any rows where the description is NULL.
*/
WITH top_products AS (
	SELECT 
		country,
		description,
		SUM(quantity) AS total_qty,
		DENSE_RANK() OVER(PARTITION BY country ORDER BY SUM(quantity) DESC) AS product_rank
	FROM retail
	WHERE description IS NOT NULL
	GROUP BY country, description
)
SELECT *
FROM top_products
WHERE product_rank IN (1,2,3)
ORDER BY country, product_rank

-- Query #5


