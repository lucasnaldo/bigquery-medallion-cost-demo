-- BRONZE: land the source as-is, plus ingestion metadata.
-- In a real project this is what the ingestion tool (Fivetran, Dataflow, Pub/Sub, scheduled loads) writes.
-- Deliberately NOT partitioned: it reproduces the "inherited stack" the cost demo starts from.
CREATE OR REPLACE TABLE bronze.orders AS
SELECT *, CURRENT_TIMESTAMP() AS _ingested_at, 'thelook.orders' AS _source
FROM `bigquery-public-data.thelook_ecommerce.orders`;

CREATE OR REPLACE TABLE bronze.order_items AS
SELECT *, CURRENT_TIMESTAMP() AS _ingested_at, 'thelook.order_items' AS _source
FROM `bigquery-public-data.thelook_ecommerce.order_items`;

CREATE OR REPLACE TABLE bronze.users AS
SELECT *, CURRENT_TIMESTAMP() AS _ingested_at, 'thelook.users' AS _source
FROM `bigquery-public-data.thelook_ecommerce.users`;

CREATE OR REPLACE TABLE bronze.products AS
SELECT *, CURRENT_TIMESTAMP() AS _ingested_at, 'thelook.products' AS _source
FROM `bigquery-public-data.thelook_ecommerce.products`;
