-- COST DEMO: the same business question asked four ways.
-- Question: revenue per category in the last 30 days.
-- run.sh dry-runs each block (nothing is billed) and prints the bytes each one would scan.

-- A
-- Report extract: SELECT * on raw tables, aggregation done later in the BI tool
SELECT oi.*, p.* EXCEPT (id, _ingested_at, _source)
FROM bronze.order_items AS oi
JOIN bronze.products AS p ON p.id = oi.product_id
WHERE oi.created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND oi.status NOT IN ('Cancelled', 'Returned');
-- END A

-- B
-- Raw tables, only the needed columns (columnar storage)
-- Note: a SELECT * inside a subquery is pruned by the optimizer; it costs when it reaches the output.
SELECT p.category, SUM(oi.sale_price) AS revenue
FROM bronze.order_items AS oi
JOIN bronze.products AS p ON p.id = oi.product_id
WHERE oi.created_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
  AND oi.status NOT IN ('Cancelled', 'Returned')
GROUP BY p.category;
-- END B

-- C
-- Silver: partition pruning on order_date + clustering
SELECT p.category, SUM(oi.sale_price) AS revenue
FROM silver.order_items AS oi
JOIN silver.products AS p USING (product_id)
WHERE oi.order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
  AND oi.is_revenue
GROUP BY p.category;
-- END C

-- D
-- Gold: pre-aggregated table, question already answered
SELECT category, SUM(revenue_usd) AS revenue
FROM gold.daily_sales
WHERE order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)
GROUP BY category;
-- END D
