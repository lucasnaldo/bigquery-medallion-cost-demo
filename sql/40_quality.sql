-- DATA QUALITY: reconciliation between layers, key integrity and freshness.
-- Written as CREATE OR REPLACE (no DML) so it also runs in the BigQuery sandbox.
-- Compares the last 50 days so it also holds in the sandbox (partitions there expire after 60 days).
-- In production: schedule it and alert when any row has passed = FALSE.
CREATE OR REPLACE TABLE ops.dq_results AS
WITH checks AS (
  SELECT 'bronze_vs_silver_order_items_rowcount' AS check_name,
         (SELECT COUNT(DISTINCT id) FROM bronze.order_items WHERE DATE(created_at) >= DATE_SUB(CURRENT_DATE(), INTERVAL 50 DAY)) AS expected,
         (SELECT COUNT(*) FROM silver.order_items WHERE order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 50 DAY)) AS actual
  UNION ALL
  SELECT 'silver_vs_gold_revenue_cents',
         (SELECT CAST(ROUND(SUM(IF(is_revenue, sale_price, 0)) * 100) AS INT64) FROM silver.order_items WHERE order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 50 DAY)),
         (SELECT CAST(ROUND(SUM(revenue_usd) * 100) AS INT64) FROM gold.daily_sales WHERE order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 50 DAY))
  UNION ALL
  SELECT 'order_items_without_product', 0,
         (SELECT COUNT(*) FROM silver.order_items WHERE order_date >= DATE '2000-01-01' AND unit_cost IS NULL)
  UNION ALL
  SELECT 'order_items_without_customer', 0,
         (SELECT COUNT(*) FROM silver.order_items AS oi
          LEFT JOIN silver.customers AS c USING (customer_id)
          WHERE oi.order_date >= DATE '2000-01-01' AND c.customer_id IS NULL)
  UNION ALL
  SELECT 'freshness_hours_since_last_order_item', 0,   -- expected 0 = "fresh"; threshold below
         (SELECT TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), MAX(created_at), HOUR)
          FROM silver.order_items
          WHERE order_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 7 DAY)
            AND created_at <= CURRENT_TIMESTAMP())  -- thelook generates some future-dated rows
)
SELECT check_name, expected, actual,
       CASE WHEN check_name LIKE 'freshness%' THEN actual BETWEEN 0 AND 48
            ELSE expected = actual END AS passed,
       CURRENT_TIMESTAMP() AS checked_at
FROM checks;

SELECT * FROM ops.dq_results ORDER BY passed, check_name;
