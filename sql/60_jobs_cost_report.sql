-- COST MONITORING: where is the money going?
-- Top queries of the last 7 days by bytes billed, with on-demand cost estimate
-- (US$ 6.25 per TiB, US multi-region list price; check your region and edition).
-- Same query works org-wide with region-us.INFORMATION_SCHEMA.JOBS_BY_PROJECT (needs permission).
SELECT
  user_email,
  job_id,
  creation_time,
  statement_type,
  ROUND(total_bytes_processed / POW(1024, 3), 2) AS gib_processed,
  ROUND(total_bytes_billed   / POW(1024, 3), 2) AS gib_billed,
  ROUND(total_bytes_billed / POW(1024, 4) * 6.25, 4) AS est_cost_usd,
  ROUND(total_slot_ms / 1000 / 60, 1) AS slot_minutes,
  ARRAY_TO_STRING(ARRAY(SELECT CONCAT(t.dataset_id, '.', t.table_id) FROM UNNEST(referenced_tables) AS t), ', ') AS tables_read,
  LEFT(REGEXP_REPLACE(query, r'\s+', ' '), 160) AS query_preview
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_USER
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
  AND state = 'DONE'
ORDER BY total_bytes_billed DESC
LIMIT 20;

-- Which tables are read most, and by how much? (candidates for partitioning/clustering or a gold model)
SELECT CONCAT(t.dataset_id, '.', t.table_id) AS table_name,
       COUNT(*) AS queries,
       ROUND(SUM(total_bytes_billed) / POW(1024, 3), 2) AS gib_billed
FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_USER, UNNEST(referenced_tables) AS t
WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
  AND job_type = 'QUERY'
GROUP BY 1
ORDER BY gib_billed DESC;
