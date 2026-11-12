-- GOLD: one model per business question. Small, documented, cheap to query.
-- Dashboards and AI agents read only from here.

CREATE OR REPLACE TABLE gold.daily_sales
PARTITION BY order_date
CLUSTER BY category
OPTIONS (description = 'Revenue, margin and volume per day and product category. Use for any sales trend question.')
AS
SELECT
  oi.order_date,
  p.category,
  COUNT(DISTINCT oi.order_id)                       AS orders,
  COUNTIF(oi.is_revenue)                            AS items_sold,
  SUM(IF(oi.is_revenue, oi.sale_price, 0))          AS revenue_usd,
  SUM(IF(oi.is_revenue, oi.gross_margin, 0))        AS gross_margin_usd,
  SAFE_DIVIDE(SUM(IF(oi.is_revenue, oi.gross_margin, 0)),
              SUM(IF(oi.is_revenue, oi.sale_price, 0))) AS gross_margin_pct,
  COUNTIF(oi.status = 'Returned')                   AS items_returned
FROM silver.order_items AS oi
JOIN silver.products AS p USING (product_id)
WHERE oi.order_date >= DATE '2000-01-01'   -- explicit partition filter (required by silver)
GROUP BY 1, 2;

CREATE OR REPLACE TABLE gold.customer_360
CLUSTER BY country, value_segment
OPTIONS (description = 'One row per customer with lifetime value and recency. Use for segmentation, churn and CRM questions.')
AS
WITH s AS (
  SELECT customer_id,
         COUNT(DISTINCT order_id)                  AS orders,
         SUM(IF(is_revenue, sale_price, 0))        AS lifetime_revenue_usd,
         SUM(IF(is_revenue, gross_margin, 0))      AS lifetime_margin_usd,
         MIN(order_date)                           AS first_order_date,
         MAX(order_date)                           AS last_order_date
  FROM silver.order_items
  WHERE order_date >= DATE '2000-01-01'
  GROUP BY 1
)
SELECT c.customer_id, c.country, c.traffic_source, c.age, c.gender,
       COALESCE(s.orders, 0) AS orders,
       COALESCE(s.lifetime_revenue_usd, 0) AS lifetime_revenue_usd,
       COALESCE(s.lifetime_margin_usd, 0)  AS lifetime_margin_usd,
       s.first_order_date, s.last_order_date,
       DATE_DIFF(CURRENT_DATE(), s.last_order_date, DAY) AS days_since_last_order,
       CASE WHEN s.orders IS NULL THEN 'no_purchase'
            WHEN s.lifetime_revenue_usd >= 300 THEN 'high'
            WHEN s.lifetime_revenue_usd >= 100 THEN 'medium'
            ELSE 'low' END AS value_segment
FROM silver.customers AS c
LEFT JOIN s USING (customer_id);

CREATE OR REPLACE TABLE gold.product_performance
CLUSTER BY category
OPTIONS (description = 'Sales, margin and return rate per product over the full history. Use for assortment and pricing questions.')
AS
SELECT product_id, p.name, p.brand, p.category, p.department,
       COUNTIF(oi.is_revenue)                    AS items_sold,
       SUM(IF(oi.is_revenue, oi.sale_price, 0))  AS revenue_usd,
       SUM(IF(oi.is_revenue, oi.gross_margin, 0)) AS gross_margin_usd,
       SAFE_DIVIDE(COUNTIF(oi.status = 'Returned'), COUNT(*)) AS return_rate
FROM silver.products AS p
LEFT JOIN (
  SELECT product_id, status, is_revenue, sale_price, gross_margin
  FROM silver.order_items
  WHERE order_date >= DATE '2000-01-01'
) AS oi USING (product_id)
GROUP BY 1, 2, 3, 4, 5;
