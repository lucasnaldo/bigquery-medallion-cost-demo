-- SILVER: one trusted version of each entity.
-- Rules: explicit column list (no SELECT *), typed and renamed columns, deduplicated,
-- partitioned by event date, clustered by the most common filter/join keys,
-- every column documented so people and LLM agents know what it means.

CREATE OR REPLACE TABLE silver.order_items (
  order_item_id     INT64     OPTIONS (description = 'Primary key of the order line.'),
  order_id          INT64     OPTIONS (description = 'Order this line belongs to. Join to silver.orders.order_id.'),
  customer_id       INT64     OPTIONS (description = 'Customer who bought. Join to silver.customers.customer_id.'),
  product_id        INT64     OPTIONS (description = 'Product sold. Join to silver.products.product_id.'),
  status            STRING    OPTIONS (description = 'Line status: Processing, Shipped, Complete, Cancelled, Returned.'),
  created_at        TIMESTAMP OPTIONS (description = 'When the line was created (UTC).'),
  order_date        DATE      OPTIONS (description = 'Partition column. DATE(created_at) in UTC.'),
  sale_price        NUMERIC   OPTIONS (description = 'Price paid for the line, USD.'),
  unit_cost         NUMERIC   OPTIONS (description = 'Product cost, USD, from silver.products.'),
  gross_margin      NUMERIC   OPTIONS (description = 'sale_price - unit_cost. Defined ONLY here; never recompute downstream.'),
  is_revenue        BOOL      OPTIONS (description = 'TRUE when the line counts as revenue (not Cancelled and not Returned).')
)
PARTITION BY order_date
CLUSTER BY customer_id, product_id, status
OPTIONS (
  description = 'One row per order line. Trusted source for revenue and margin.',
  require_partition_filter = TRUE
)
AS
SELECT
  oi.id, oi.order_id, oi.user_id, oi.product_id, oi.status, oi.created_at,
  DATE(oi.created_at),
  CAST(oi.sale_price AS NUMERIC),
  CAST(p.cost AS NUMERIC),
  CAST(oi.sale_price AS NUMERIC) - CAST(p.cost AS NUMERIC),
  oi.status NOT IN ('Cancelled', 'Returned')
FROM bronze.order_items AS oi
LEFT JOIN bronze.products AS p ON p.id = oi.product_id
WHERE oi.created_at IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY oi.id ORDER BY oi._ingested_at DESC) = 1;

CREATE OR REPLACE TABLE silver.orders (
  order_id      INT64     OPTIONS (description = 'Primary key of the order.'),
  customer_id   INT64     OPTIONS (description = 'Join to silver.customers.customer_id.'),
  status        STRING    OPTIONS (description = 'Order status.'),
  created_at    TIMESTAMP OPTIONS (description = 'Order creation time (UTC).'),
  order_date    DATE      OPTIONS (description = 'Partition column. DATE(created_at).'),
  shipped_at    TIMESTAMP OPTIONS (description = 'Shipping time, NULL if not shipped.'),
  delivered_at  TIMESTAMP OPTIONS (description = 'Delivery time, NULL if not delivered.'),
  returned_at   TIMESTAMP OPTIONS (description = 'Return time, NULL if not returned.'),
  item_count    INT64     OPTIONS (description = 'Number of items in the order.'),
  hours_to_ship FLOAT64   OPTIONS (description = 'Hours between creation and shipping.')
)
PARTITION BY order_date
CLUSTER BY customer_id, status
OPTIONS (description = 'One row per order.', require_partition_filter = TRUE)
AS
SELECT order_id, user_id, status, created_at, DATE(created_at), shipped_at, delivered_at, returned_at,
       num_of_item, TIMESTAMP_DIFF(shipped_at, created_at, MINUTE) / 60
FROM bronze.orders
WHERE created_at IS NOT NULL
QUALIFY ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY _ingested_at DESC) = 1;

CREATE OR REPLACE TABLE silver.customers (
  customer_id    INT64     OPTIONS (description = 'Primary key of the customer.'),
  age            INT64     OPTIONS (description = 'Age at signup.'),
  gender         STRING    OPTIONS (description = 'M or F.'),
  country        STRING    OPTIONS (description = 'Country.'),
  state          STRING    OPTIONS (description = 'State or region.'),
  city           STRING    OPTIONS (description = 'City.'),
  traffic_source STRING    OPTIONS (description = 'Acquisition channel at signup.'),
  signup_at      TIMESTAMP OPTIONS (description = 'Signup time (UTC).')
)
CLUSTER BY country, traffic_source
OPTIONS (description = 'One row per customer. Personal data (name, e-mail, address) intentionally NOT carried to silver.')
AS
SELECT id, age, gender, country, state, city, traffic_source, created_at
FROM bronze.users
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _ingested_at DESC) = 1;

CREATE OR REPLACE TABLE silver.products (
  product_id   INT64   OPTIONS (description = 'Primary key of the product.'),
  name         STRING  OPTIONS (description = 'Product name.'),
  brand        STRING  OPTIONS (description = 'Brand.'),
  category     STRING  OPTIONS (description = 'Category.'),
  department   STRING  OPTIONS (description = 'Men or Women.'),
  unit_cost    NUMERIC OPTIONS (description = 'Cost, USD.'),
  retail_price NUMERIC OPTIONS (description = 'List price, USD.')
)
CLUSTER BY category, brand
OPTIONS (description = 'One row per product.')
AS
SELECT id, name, brand, category, department, CAST(cost AS NUMERIC), CAST(retail_price AS NUMERIC)
FROM bronze.products
QUALIFY ROW_NUMBER() OVER (PARTITION BY id ORDER BY _ingested_at DESC) = 1;
